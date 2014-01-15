--[[PublicProperties
isPlayable boolean False
/PublicProperties]]
-- note : strangely, having the character stretched does not cause issue with the physics

CharacterPrefab = CS.FindAsset( "Entities/Character" )
CharacterScript = nil -- used in HUD

function Behavior:Awake()
    self.gameObject.s = self
    self.gameObject:AddTag( "character" )
    
    self.mapGO = GameObject.Get( "Map" )
    self.modelGO = self.gameObject:GetChild( "Model" )
    self.modelGO:AddTag( "characterModel" )
    --self.trailGO = self.gameObject:GetChild( "Trail" )
    self.cameraGO = self.gameObject:GetChild( "Camera" )
    
    
    -- movements
    self.rotationSpeed = 0.1
    self.walkSpeed = 35.0
    self.jumpSpeed = 3500
    
    self.lookAngles = Vector3(0)

    self.isOnGround = true
    self.isFalling = false
     
    
    -- shooting
    self.maxHealth = 2
    self.health = self.maxHealth
    
    self.damage = 1
    self.shootInterval = 20 -- 20 frame = 3 shoot per second
    self.lastShootFrame = 0
    --self.maxDamage = 10 -- not necessarilly equal to self.maxHealth
    --self.chargeFrame = 0
    --self.maxChargeFrame = 120 -- time in frames to reach max charge
    --self.lastDamage = 0 -- ?
    -- players can hold the left mouse button to "charge" the laser and do more than 1 damage
    
    self.shootRay = Ray()
    
    
    --
    self.frameCount = 0
    self.isLocked = true
    
    if self.isPlayable then
        self:SetupPlayableCharacter()
    end
    
    if self.playerId == nil then -- set in Client:PlayerSpawned()
        self.playerId = -1
    end
    
    if self.team == nil then -- set in Client:PlayerSpawned()
        self.team = 1
    end
    
end


-- Called from Client:PlayerSpawned() this character is the one the player should control
-- Never called on the server
function Behavior:SetupPlayableCharacter() 
    CharacterScript = self -- used in HUD
    self.isPlayable = true
    
    -- remove level spawn camera
    Level.levelSpawns[ self.team ].camera:Destroy()
    
    -- set player camera
    self.cameraGO:Set( { camera = { fOV = 60 } } )
    
    -- hud
    Level.hudCamera.Recreate() -- recreate so that it is renderer after the player camera and the hud/menu appear over the world
    
    local hudGO = Level.hud
    
    self.hud = {}
    self.hud.isOnGroundGO = hudGO:GetChild( "IsOnGround", true )
    --self.hud.isFallingGO = hudGO:GetChild( "IsFalling", true )
    --self.hud.isFallingGO.textRenderer.text = ""
    self.hud.groundDistance = hudGO:GetChild( "GroundDistance", true )      
    --self.hud.damages = hudGO:GetChild( "Damages.Text", true )   
    
    Level.hud.Show()
    
    --    
    --self.isLocked = true
    --Tween.Timer( 0.5, function() self.isLocked = false end )
    self.isLocked = false
end




function Behavior:Update()
    if not self.isPlayable and not LocalServer then 
        -- stopping the funciton here actually makes the character roll on itself because the colider is a sphere
        -- > not anymore since the physics rotation have been locked
        return
    end
    
    self.frameCount = self.frameCount + 1
    
    local server = LocalServer or Client.server
    local playerId = self.playerId -- -1 when offline
    
    local player = nil
    if server ~= nil then
        player = server.playersById[ playerId ]
    end
    -- when offline, server and player are nil
    
    if player ~= nil and player.hasLeft then
        player.characterGO = nil
        self.gameObject:Destroy()
        cprint("destroying character from update")
        return
    end
    
    if LocalServer and player == nil then
        print("Character:Update() : player is nil on LocalServer", self.playerId )
        table.print( LocalServer.playersById )
        self.gameObject:Destroy()
        return
    end
    
    -------------------
    
    local input = {
        spaceWasJustPressed = false,
        leftMouseWasJustPressed = false,            
        verticalAxis = 0,
        horizontalAxis = 0,
        mouseDelta = {x=0,y=0},
    }
    
    if Client.isConnected then -- client online
        input = {
            -- sends the raw input, let the server check for other conditions
            spaceWasJustPressed = CS.Input.WasButtonJustPressed( "Space" ),
            leftMouseWasJustPressed = CS.Input.WasButtonJustPressed( "LeftMouse" ),            
            verticalAxis = CS.Input.GetAxisValue( "Vertical" ),
            horizontalAxis = CS.Input.GetAxisValue( "Horizontal" ),
            mouseDelta = CS.Input.GetMouseDelta(),
        }
        if 
            input.spaceWasJustPressed == true or
            input.leftMouseWasJustPressed == true or
            input.verticalAxis ~= 0 or
            input.horizontalAxis ~= 0 or
            input.mouseDelta.x ~= 0 or
            input.mouseDelta.y ~= 0
        then
            ServerGO.networkSync:SendMessageToServer( "SetCharacterInput", { input = input } )
        end
        
        return
    
    elseif LocalServer then -- server
        -- player.input has been set in Server:SetCharacterInput()
        
        if player.input ~= nil then
            input = player.input 
            player.input = nil -- player.input will stays nil as long as Server:SetCharacterInput() isn't called (as long as the player don't do any input)    
        end
            
    elseif not self.isLocked then -- client offline
        input = {
            spaceWasJustPressed = CS.Input.WasButtonJustPressed( "Space", {"tchatfocused", "menudisplayed"}, false ),
            leftMouseWasJustPressed = CS.Input.WasButtonJustPressed( "LeftMouse", {"tchatfocused", "menudisplayed"}, false ),            
            verticalAxis = CS.Input.GetAxisValue( "Vertical", {"tchatfocused", "menudisplayed"}, false ),
            horizontalAxis = CS.Input.GetAxisValue( "Horizontal", {"tchatfocused", "menudisplayed"}, false ),
            mouseDelta = CS.Input.GetMouseDelta(),
        }
    end
    -- else : process default input, make the character stand still
    
    -------------------
    
    -- Movement code mostly ripped from the Character Control script of the Sky Arena project (7DFPS 2013)  
    
    -- Jumping
    local bottomRay = Ray:New( self.gameObject.transform:GetPosition(), -Vector3:Up() )
    
    local groundDistance = bottomRay:IntersectsMapRenderer( self.mapGO.mapRenderer ) 
    
    local lastIsOnGround = self.isOnGround
    self.isOnGround = false
    if groundDistance ~= nil and groundDistance < 6 then
        self.isOnGround = true
    end
    
    if self.isOnGround and input.spaceWasJustPressed then
        --print("jump", self.gameObject.transform.position)
        self.gameObject.physics:ApplyImpulse( Vector3:New( 0, self.jumpSpeed, 0 ) )
        
        self.isOnGround = false
    end
       
    
    local velocity = self.gameObject.physics:GetLinearVelocity()
    
    -- Rotate the character when the mouse moves around
    local mouseDelta = input.mouseDelta
    
    self.lookAngles.x = self.lookAngles.x - self.rotationSpeed * mouseDelta.y
    self.lookAngles.x = math.clamp( self.lookAngles.x, -60, 60 )
    self.lookAngles.y = self.lookAngles.y - self.rotationSpeed * mouseDelta.x
    -- self.lookAngles.z always == 0
    
    self.gameObject.transform:SetEulerAngles( Vector3:New( self.lookAngles ) ) -- I think this shouldn't work, but it does
    --self.gameObject.physics:WarpEulerAngles( Vector3:New( self.lookAngles ) ) 
    -- 05/01/2014 for some reason having WarpEulerAngles uncommented makes that the
    -- the character is moved at 0,0,0 between Start() and the first call to Update()
    
    --print("WarpEulerAngles", Vector3:New( self.lookAngles ) )


    -- Moving around
    local vertical = input.verticalAxis
    local horizontal = input.horizontalAxis

    -- Walking forward / backward
    local newVelocity = Vector3:Forward() * vertical * self.walkSpeed
    -- Strafing (left/right)
    newVelocity = newVelocity - Vector3:Left() * horizontal * self.walkSpeed

    local characterOrientation = Quaternion:FromAxisAngle( Vector3:Up(), self.lookAngles.y )
    newVelocity = Vector3.Transform( newVelocity, characterOrientation )
    newVelocity.y = velocity.y
    
    self.gameObject.physics:SetLinearVelocity( newVelocity )  
    
    -- shooting
    if input.leftMouseWasJustPressed and self.lastShootFrame + self.shootInterval < self.frameCount then
        self.lastShootFrame = self.frameCount
        --self.damage = 1
        self:Shoot()
    end

    
    -- update hud
    if LocalServer then
        return 
    end
    
    if lastIsOnGround ~= self.isOnGround then
        self.hud.isOnGroundGO.textRenderer.text = "IsOnGround: "..tostring( self.isOnGround )
    end
    
    if groundDistance == nil then
        groundDistance = 9999
    end
    self.hud.groundDistance.textRenderer.text = "groundDistance: "..tostring( math.round( groundDistance, 2 ) )
end


function Behavior:Shoot()
    self.shootRay.position = self.cameraGO.transform.position
    self.shootRay.direction = self.shootRay.position - self.gameObject.transform.position 
    -- /!\ can't do that if the camera is not aligned with the character's main position
    -- just take the position and direction of the "gun" if any
    
    local characters = {}
    if Game.friendlyFire then
        characters = GameObject.GetWithTag( "characterModel" )
    else
        -- firedly fire is OFF, only get the characters of the other team
        local team = "team1"
        if self.team == 1 then
            team = "team2"
        end
        characters = GameObject.GetWithTag( { "characterModel", team } )
    end
    
    local mapHit = self.shootRay:IntersectsMapRenderer( self.mapGO.mapRenderer, true )
    
    -- characters is the list of the character's "Model" game object (with the model renderer), child of the character's root game object
    local characterHit = self.shootRay:Cast( characters, true )[1] -- true > sort by distance asc , first = closest
    
    
    -- get the closest hit
    local hit = {}
    if
        characterHit ~= nil and
        (mapHit == nil or characterHit.distance < mapHit.distance)
    then
        hit = characterHit
    elseif mapHit ~= nil then
        hit = mapHit
    end
    
    -- Was someone hit ?
    if hit.gameObject ~= nil then
        local target = hit.gameObject.parent -- the character root, hit.gameObject is the character's "Model" game object
        
        -- target is nil if hit == mapHit
        if target ~= nil and target:HasTag( "character" ) then
            cprint( self.gameObject, "has hit", target , "with damage", self.damage)
            target.s:TakeDamage( self.damage, self.playerId ) -- self.playerId is -1 when offline
        end
    end
    
        --cprint("ray2", self.shootRay)
        --cprint("hit", hit)
    self:CreateShootLine( hit.hitLocation )
end


function Behavior:CreateShootLine( endPosition, shootRay )
    if shootRay == nil then
        shootRay = self.shootRay
    end
    
    if endPosition == nil then
        endPosition = shootRay.position + shootRay.direction * 9999
    end
    
    if LocalServer then
        local player = LocalServer.playersById[ self.playerId ]
        player.messagesToSend.CreateShootLine = { 
            endPosition,
            shootRay,
        }
    end
    
    local lineGO = GameObject.New( "Line", {
        transform = { position = shootRay.position },
        modelRenderer = { model = "Lines/Red" },
        lineRenderer = { endPosition = endPosition, width = 0.3 }
    } )
    
    Tween.Tweener( {
        target = lineGO.modelRenderer,
        property = "opacity",
        endValue = 0,
        duration = 1,
        OnComplete = function() lineGO:Destroy() end        
    } )
end


-- amount (number) Amount of damage
-- killerPlayerId (number) The playerId of the shooter
function Behavior:TakeDamage( amount, killerPlayerId )
    if LocalServer then
        local player = LocalServer.playersById[ self.playerId ]
        player.messagesToSend.TakeDamage = { 
            amount,
            killerPlayerId,
        }
    end
    
    self.health = self.health - amount
    
    if not Client.isConnected and self.health <= 0 then -- offline or server
        self:Die( killerPlayerId )
        -- when connected, Die() is called directly by the server
    end
end


function Behavior:Die( killerPlayerId )
    if self.isPlayable then
        Client.player.isSpawned = false
        Level.levelSpawns[ Client.player.team ]:AddComponent( "Camera" )
        Level.hudCamera.Recreate()
    
        Level.menu.Show()
    end
       
    --
    local server = GetServer()
    local player = GetPlayer( self.playerId )
    
    if LocalServer then
        player.messagesToSend.Die = {
            killerPlayerId
        }
    end
    
    local killerName = Player.name
    if killerPlayerId > -1 and server then
        killerName = server.playersById[ killerPlayerId ].name
    end
    
    local deadName = "DeadName"
    if player then
        deadName = player.name
    end
    
    Tchat.AddLine( killerName.." has killed "..deadName )
    
    --
    self.gameObject:Destroy()
    if player then
        player.isSpawned = false
        player.characterGO = nil
    end
end
