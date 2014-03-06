--[[PublicProperties
isPlayable boolean False
/PublicProperties]]
-- note : strangely, having the character stretched does not cause issue with the physics

CharacterPrefab = CS.FindAsset( "Entities/Character" )
CharacterScript = nil -- used in HUD, only set for the character that the client controls

function Behavior:Awake()
    self.gameObject.s = self
    self.gameObject:AddTag( "character" )
    
    self.modelGO = self.gameObject:GetChild( "Model" )
    self.modelGO:AddTag( "characterModel" )
    self.cameraGO = self.gameObject:GetChild( "Camera", true )
    self.crosshairGO = self.cameraGO:GetChild( "Crosshair" )
    
    --[[local healthbarGO = self.gameObject:GetChild( "Healthbar" )
    self.healthbarGO = healthbarGO:GetChild( "Bar" )
    self.healthbarBackgroundGO = healthbarGO:GetChild( "Background" )]]
       
    -- movements
    local server = GetServer()
    self.rotationSpeed = server.game.character.rotationSpeed
    self.walkSpeed = server.game.character.walkSpeed
    self.jumpSpeed = server.game.character.jumpSpeed
    
    self.lookAngles = Vector3(0)

    self.isOnGround = true
    self.isFalling = false
     
    
    -- shooting
    self.maxHealth = server.game.character.health
    self.health = self.maxHealth
    
    self.damage = server.game.character.weaponDamage
    self.shootRate = server.game.character.shootRate
    self.lastShootFrame = 0
    
    self.shootRay = Ray()
    
    --
    self:SetupGametype( server.game.gametype )
        
    self.frameCount = 0
    self.isLocked = true
    
    if self.playerId == nil then -- set in Client:SpawnPlayer()
        self.playerId = -1
    end
        
    self:SetTeam()
        
    if self.isPlayable then
        self:SetupPlayableCharacter()
    end
    
    if Client.isConnected then
        self.gameObject.physics:SetFreezePosition( true, true, true )
        self.gameObject.physics:SetFreezeRotation( true, true, true )
    end
end


function Behavior:Start()
    -- in Start() to wait for the self.playerId to be set between the calls to Awake() and Start() in Client:SpawnPlayer()
    if self.playerId > 0 then
        local player = GetPlayer( self.playerId )
        self.gameObject.name = "Character: "..player.name
        self.modelGO.name = "Character model: "..player.name
    end
end


-- Called from Client:PlayerSpawned() this character is the one the player should control
-- Never called on the server
function Behavior:SetupPlayableCharacter() 
    CharacterScript = self -- used in HUD
    self.isPlayable = true
    
    -- remove level spawn camera
    local camera = Level.levelSpawns[ self.team ].camera
    if camera then
        camera:Destroy()
    end
    
    -- set player camera
    self.cameraGO:Set( { camera = { fOV = 60 } } )
    
    -- hud
    Level.hudCamera.Recreate() -- recreate so that it is renderer after the player camera and the hud/menu appear over the world
    
    local hudGO = Level.hud
    
    self.hud = {}
    self.hud.isOnGroundGO = hudGO:GetChild( "IsOnGround", true )
    self.hud.groundDistance = hudGO:GetChild( "GroundDistance", true )
    local playerHealthGO = hudGO:GetChild( "Player Health", true )
    -- self.hud.healthbar is the ProgressBar component
    self.hud.healthbar = playerHealthGO:GetChild( "Healthbar" ):AddComponent( "ProgressBar", {
        maxValue = self.maxHealth,
        maxLength = 6,
        value = self.maxHealth,
    } )
    -- background
    playerHealthGO:GetChild( "Background" ):AddComponent( "ProgressBar", {
        maxValue = self.maxHealth,
        maxLength = 6.2,
        value = self.maxHealth,
        height = 1.2,
    } )
    self.hud.background = playerHealthGO:GetChild( "Background" )

    
    Level.hud.Show()
    
    --    
    --self.isLocked = true
    --Tween.Timer( 0.5, function() self.isLocked = false end )
    self.isLocked = false
end


-- Set the self.team property and update the character's look
function Behavior:SetTeam( team )
    SetEntityTeam( self, team )
       
    self.modelGO:RemoveTag( self.otherTeamTag )
    self.modelGO:AddTag( self.teamTag ) -- used in Shoot() below and by triggers (see "CTF Flag" script)
    
    if self.team > 0 then
        self.modelGO.modelRenderer.model = Team[ self.team ].models.character.body
        self.crosshairGO.modelRenderer.model = Team[ self.team ].models.crosshair
    end
end


function Behavior:SetupGametype( gt )
    if gt == "ctf" then
        
        self.flagGO = nil -- is set with the flag game object when the player has picked it up
        -- the flag game object also become the character model's child
        
        self.modelGO.OnTriggerEnter = function( triggerGO )
            if triggerGO.parent:HasTag( {"ctf", "flag"} )
                local triggerScript = triggerGO.parent.s
                
                if self.team == triggerScript.team and not triggerScript.isPickedUp and not triggerScript.isAtBase then
                    triggerScript:MoveTobase()
    
                else if self.team ~= triggerScript.team and not triggerScript.isPickedUp then
                    self:PickUpCTFFlag()
                
                end
            end
        end
    end
end


local first = false

function Behavior:Update()
    if IsClient and not self.isPlayable then 
        return
    end
    -- runs when server or when client and is playable
    
    self.frameCount = self.frameCount + 1
    
    local server = GetServer()
    local playerId = self.playerId -- -1 when offline
    local player = GetPlayer( playerId )
    
    if player ~= nil and player.hasLeft then
        player.characterGO = nil
        self.gameObject:Destroy()
        cprint("destroying character from update")
        return
    end
    
    if IsServer and player == nil then
        -- happens sometimes ?
        print("Character:Update() : player is nil on LocalServer", self.playerId )
        table.print( LocalServer.playersById )
        self.gameObject:Destroy()
        return
    end
    
    -------------------
    
    local input = {
        spaceWasJustPressed = false,
        leftMouseWasJustPressed = false,
        leftMouseIsDown = false,
        verticalAxis = 0,
        horizontalAxis = 0,
        mouseDelta = {x=0,y=0},
    }
    
    if Client.isConnected then -- client online
        if not Level.menu.isDisplayed then
            input = {
                -- sends the raw input, let the server check for other conditions
                spaceWasJustPressed = CS.Input.WasButtonJustPressed( "Space" ),
                leftMouseWasJustPressed = CS.Input.WasButtonJustPressed( "LeftMouse" ),
                leftMouseIsDown = CS.Input.IsButtonDown( "LeftMouse" ),
                verticalAxis = CS.Input.GetAxisValue( "Vertical" ),
                horizontalAxis = CS.Input.GetAxisValue( "Horizontal" ),
                mouseDelta = CS.Input.GetMouseDelta(),
            }
            if 
                input.spaceWasJustPressed == true or
                input.leftMouseWasJustPressed == true or
                input.leftMouseIsDown == true or
                input.verticalAxis ~= 0 or
                input.horizontalAxis ~= 0 or
                input.mouseDelta.x ~= 0 or
                input.mouseDelta.y ~= 0
            then
                ServerGO.networkSync:SendMessageToServer( "SetCharacterInput", { input = input }, CS.Network.DeliveryMethod.ReliableOrdered, 1 )
                -- 23/01/2014  some input are missed, they are sent but does seems to arrive on the server
                -- noticeable
            end
        end
        
        return
    
    elseif IsServer then -- server
        -- player.input has been set in Server:SetCharacterInput()
        if player.input ~= nil then
            input = player.input 
            player.input = nil -- player.input will stays nil as long as Server:SetCharacterInput() isn't called (as long as the player don't do any input)    
        end
            
    elseif not self.isLocked then -- client offline
        local tags = {"tchatfocused", "menudisplayed"}
        input = {
            spaceWasJustPressed = CS.Input.WasButtonJustPressed( "Space", tags, false ),
            leftMouseWasJustPressed = CS.Input.WasButtonJustPressed( "LeftMouse", tags, false ),            
            leftMouseIsDown = CS.Input.IsButtonDown( "LeftMouse", tags, false ),
            verticalAxis = CS.Input.GetAxisValue( "Vertical", tags, false ),
            horizontalAxis = CS.Input.GetAxisValue( "Horizontal", tags, false ),
            mouseDelta = CS.Input.GetMouseDelta(),
        }
    end
    -- else : process default input, make the character stand still
    
    -------------------
    
    
    -- Movement code mostly ripped from the Character Control script of the Sky Arena project (7DFPS 2013)  
    
    -- Jumping
    local bottomRay = Ray:New( self.gameObject.transform:GetPosition(), -Vector3:Up() )
    
    local groundDistance = bottomRay:IntersectsMapRenderer( Level.mapGO.mapRenderer ) 
    
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
    
    self.modelGO.transform:SetEulerAngles( Vector3:New( self.lookAngles ) ) -- I think this shouldn't work, but it does
    
    -- self.gameObject.physics:WarpEulerAngles( Vector3:New( self.lookAngles ) ) 
    -- /!\ 05/01/2014 for some reason having WarpEulerAngles uncommented makes that the
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
    if input.leftMouseIsDown and self.lastShootFrame + (60/self.shootRate) < self.frameCount then    
        self.lastShootFrame = self.frameCount
        self:Shoot()
    end

    
    -- update hud
    if IsServer then
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

    local mapHit = self.shootRay:IntersectsMapRenderer( Level.mapGO.mapRenderer, true )
    
    local tags = { "characterModel" }
    local server = GetServer()
    if not server.game.friendlyFire then
        -- firedly fire is OFF, only get the characters of the other team
        local otherTeam = 2
        if self.team == 2 then otherTeam = 1 end
       table.insert( tags, "team"..otherTeam )
    end
    

    local characters = GameObject.GetWithTag( tags )
    -- characters is the list of the character's "Model" game object (with the model renderer), child of the character's root game object
    
    local characterHit = self.shootRay:Cast( characters, true )[1] -- true > sort by distance asc , first = closest
    -- characterHit is a RaycastHit (or nil) with data on the closest player hit
    --print("shoot", tags[1], tags[2], "#chars", #characters) 
    
    -- get the closest hit (map or player)
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
            --cprint( self.gameObject, "has hit", target , "with damage", self.damage)
            target.s:TakeDamage( self.damage, self.playerId ) -- self.playerId is -1 when offline
        end
    end
    
    self:CreateShootLine( hit.hitLocation )
end


function Behavior:CreateShootLine( endPosition, shootRay )
    if shootRay == nil then
        shootRay = self.shootRay
    end
    
    if endPosition == nil then
        endPosition = shootRay.position + shootRay.direction * 9999
    end
    
    if IsServer then
        local player = LocalServer.playersById[ self.playerId ]
        player.messagesToSend.CreateShootLine = { 
            endPosition,
            shootRay,
        }
    end
      
    local lineGO = GameObject.New( "Line", {
        transform = { position = shootRay.position },
        modelRenderer = { model = Team[ self.team ].models.bulletTrail },
        lineRenderer = { endPosition = setmetatable( endPosition, Vector3 ), width = 0.3 }
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
    local player = GetPlayer( self.playerId )
    if IsServer then
        player.messagesToSend.TakeDamage = { 
            amount,
            killerPlayerId,
        }
    end
    
    self.health = self.health - amount
    if 
        ( Client.isConnected and Client.player.id == player.id ) or
        GetServer().isOffline
    then
        self.hud.healthbar.value = self.health
    end
     
    if not Client.isConnected and self.health <= 0 then -- offline or server
        self:Die( killerPlayerId )
        -- when connected, Die() is called directly by the server
    end
end


-- killerPlayerId (number) is of the player who fired the fatal shot
-- may be nil 
-- may by the same as the player id > this is a suicide
-- may be negative > player die without notification and losing score (happens at the end of the round)
function Behavior:Die( killerPlayerId )
    local server = GetServer()
    local player = GetPlayer( self.playerId )
    
    if killerPlayerId >= 0 then
        local killerName = Player.name
        if killerPlayerId and killerPlayerId ~= self.playerId then -- not a suicide
            local killer = server.playersById[ killerPlayerId ]
            killerName = killer.name
            killer.kills = killer.kills + 1        
        end
        
        local deadName = "DeadName"
        deadName = player.name
        player.deaths = player.deaths + 1
        
        local text = killerName.." has killed "..deadName
        if not killerPlayerId then
            text = deadName.." has died."
        elseif killerPlayerId == self.playerId then
            text = deadName.." committed suicide."
        end
        
        Tchat.AddLine( text )
        Level.scoreboard.Update()
    end
    
    
    -- CTF
    local flag = self.gameObject:GetChild("CTF Flag")
    if flag ~= nil then
        flag.s:IsPickedUp( false )
    end
    
    
    --
    self.gameObject:Destroy()
    
    if player then -- 13/02/14 - why would it be nil ?
        player.isSpawned = false
        player.characterGO = nil
    end
    
    if IsServer then
        player.messagesToSend.Die = {
            killerPlayerId
        }
    end
    
    if self.isPlayable then
        Client.player.isSpawned = false
        Gametype.ResetLevelSpawn( player.team )
        
        Level.menu.Show()
    end
end



function Behavior:PickUpCTFFlag( flagGO )
    
    if flagGO == nil then -- happens online
        flagGO = GameObject.GetWithTag( {"ctf", "flag", } )
    end
    
    if flagGO ~= nil then
        flagGO.s:PickUp( self.gameObject )
    else
        local flag = self.gameObject:GetChild("CTF Flag")
        if flag ~= nil then
            
        end
    end
    flagGO.parent = self.modelGO
    
    flagGO
end


    if pickupGO ~= nil then
        self.isPickedUp = true
        self.isAtBase = false
    else
        self.isPickedUp = false
    end
    
    self.gameObject.parent = pickupGO