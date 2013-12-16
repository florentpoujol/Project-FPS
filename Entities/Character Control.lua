--[[PublicProperties
isPlayable boolean False
/PublicProperties]]

CharacterPrefab = CS.FindAsset( "Entities/Character" )
CharacterScript = nil -- used in HUD

function Behavior:Awake()
    self.gameObject.s = self
    
    self.gameObject:AddTag( "character" )
    
    --CS.Input.LockMouse()
    
    self.mapGO = GameObject.Get( "Map" )
    self.modelGO = self.gameObject:GetChild( "Model" )
    self.modelGO:AddTag( "characterModel" )
    --self.trailGO = self.gameObject:GetChild( "Trail" )
    self.cameraGO = self.gameObject:GetChild( "Camera" )
    
    -- movements
    self.rotationSpeed = 0.1
    self.walkSpeed = 35.0
    self.jumpSpeed = 3500
    
    self.angleX = 0
    self.angleY = 0

    self.isOnGround = true
    self.isFalling = false
     
    
    -- shooting
    self.maxHealth = 10
    self.health = self.maxHealth
    
    self.damage = 1
    self.maxDamage = 10 -- not necessarilly equal to self.maxHealth
    self.chargeFrame = 0
    self.maxChargeFrame = 120 -- time in frames to reach max charge
    self.lastDamage = 0 -- ?
    -- players can hold the left mouse button to "charge" the laser and do more than 1 damage
    
    self.shootRay = Ray()
    
    --
    self.frameCount = 0
    self.isLocked = true
    
    if not self.isPlayable then
        self:SetupPlayableCharacter()
    end
    
    if self.playerId == nil then
        self.playerId = -1
    end
end


function Behavior:SetupPlayableCharacter()
    CharacterScript = self -- used in HUD
    
    -- hud
    Level.hudCamera.Recreate() -- recreate so that it is renderer after the player camera and the hud/menu appear over the world
    
    local hudGO = Level.hud
    
    self.hud = {}
    self.hud.isOnGroundGO = hudGO:GetChild( "IsOnGround", true )
    self.hud.isFallingGO = hudGO:GetChild( "IsFalling", true )
    self.hud.isFallingGO.textRenderer.text = ""
    self.hud.groundDistance = hudGO:GetChild( "GroundDistance", true )      
    self.hud.damages = hudGO:GetChild( "Damages.Text", true )   
    
    Level.hud.Show()
    
    self.isLocked = true
    Tween.Timer( 1, function() self.isLocked = false end )
end


function Behavior:Start()
    --self.lastTrailPosition = self.gameObject.transform.position
    --[[if LocalServer then 
        LocalServer.playersById[ self.playerId ].characterGO = self.gameObject -- useless, this is done in Client:PlayerSpawned
    end]]
end


function Behavior:Update()
    if not self.isplayable then 
        -- stopping the funciton here actually makes the character roll widly on itself
        -- because the colider is a sphere
        return
    end
    
    self.frameCount = self.frameCount + 1
    
    local server = Client.server or LocalServer
    
    local playerId = Client.player.id
    if LocalServer then
        playerId = self.playerId
    end
    
    local player = nil
    if server ~= nil then
        player = server.playersById[ playerId ]
    end
    -- when offline, server and player are nil
    
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
        input = player.input 
        -- player.input has been set in Server:SetCharacterInput()
        if input ~= nil then
            player.input = nil -- player.input will stays nil as long as Server:SetCharacterInput() isn't called (as long as the player don't do any input)    
        else
            return -- if it makes the character rolls over on itself, just keep going with befault input instead of return (same for Clients)
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
        --print("jump", self.jumpSpeed )
        self.gameObject.physics:ApplyImpulse( Vector3:New( 0, self.jumpSpeed, 0 ) )
        
        self.isOnGround = false
    end
        
    
    local velocity = self.gameObject.physics:GetLinearVelocity()
    
    -- Rotate the camera when the mouse moves around
    local mouseDelta = CS.Input.GetMouseDelta()

    self.angleY = self.angleY - self.rotationSpeed * mouseDelta.x
    self.angleX = self.angleX - self.rotationSpeed * mouseDelta.y
    self.angleX = math.clamp( self.angleX, -60, 60 )

    self.gameObject.transform:SetLocalEulerAngles( Vector3:New( self.angleX, self.angleY, 0 ) )

    -- Moving around
    local vertical = input.verticalAxis
    local horizontal = input.horizontalAxis

    -- Walking forward / backward
    local newVelocity = Vector3:Forward() * vertical * self.walkSpeed
    -- Strafing
    newVelocity = newVelocity - Vector3:Left() * horizontal * self.walkSpeed

    local characterOrientation = Quaternion:FromAxisAngle( Vector3:Up(), self.angleY )
    newVelocity = Vector3.Transform( newVelocity, characterOrientation )
    newVelocity.y = velocity.y
    
    self.gameObject.physics:SetLinearVelocity( newVelocity )
    
    
    -- shooting
    --[[local lastDamage = self.damage
    if CS.Input.IsButtonDown( "LeftMouse", {"tchatfocused", "menudisplayed"}, false ) then
        self.chargeFrame = self.chargeFrame + 1
        --if self.chargeFrame > self.maxChargeFrame + 30 then -- player holds the charge button 1/2 second more than necessary
          --  self.chargeFrame = 0
--        end
        
        self.damage = math.lerp( 1, self.maxDamage, self.chargeFrame / self.maxChargeFrame )
        self.damage = math.round( math.clamp( self.damage, 1, self.maxDamage ), 1 )
    end
    
    if CS.Input.WasButtonJustReleased( "LeftMouse", {"tchatfocused", "menudisplayed"}, false ) then
        self:Shoot()
        self.damage = 1
        self.chargeFrame = 0
    end]]
    if CS.Input.WasButtonJustPressed( "LeftMouse", {"tchatfocused", "menudisplayed"}, false ) then
        self.damage = 1
        self:Shoot()
    end
    
    
    -- trail renderer
    --[[
    if self.frameCount % 5 == 0 then
        local position = self.trailGO.transform.position
        local trailGO = GameObject.New("Trail", {
            transform = { 
                position = position,
                --localScale = self.modelGO.transform.scale/2
            },
            modelRenderer = { model = "Lines/Blue", opacity = 0.8 },
        } )
        
        local line = Draw.LineRenderer.New( trailGO, {
            endPosition = self.lastTrailPosition,
            width = self.modelGO.transform.scale.x/2
        } )
        line.length = line.Length + 0.5
        self.lastTrailPosition = position
        
        
        Tween.Tweener( {
            target = trailGO.transform,
            property = "localScale",
            endValue = Vector3(0,0,trailGO.transform.localScale.z),
            duration = 1,
            OnComplete = function() trailGO:Destroy() end        
        } ) 
    end
    ]]
    
    -- update hud
    if lastIsOnGround ~= self.isOnGround then
        self.hud.isOnGroundGO.textRenderer.text = "IsOnGround: "..tostring( self.isOnGround )
    end
    --[[if lastIsFalling ~= self.isFalling then
        self.hud.isFallingGO.textRenderer.text = "WasFalling: "..tostring( self.isFalling )
    end]]
    
    --[[if lastDamage ~= self.damage then
        self.hud.damages.textRenderer.text = "Damages: "..tostring( math.round( self.damage, 1 ) )
    end]]
    
    if groundDistance == nil then
        groundDistance = 9999
    end
    self.hud.groundDistance.textRenderer.text = "groundDistance: "..tostring( math.round( groundDistance, 2 ) )
end


function Behavior:UpdateFromServer()
    
end


function Behavior:Shoot()
    self.shootRay.position = self.cameraGO.transform.position
    self.shootRay.direction = self.shootRay.position - self.gameObject.transform.position -- can't do that if the camera is not aligned with the character's main position
    
    local hit = self.shootRay:IntersectsMapRenderer( self.mapGO.mapRenderer, true ) -- tue > return raycast hit  
    
    local characterHit = self.shootRay:Cast( GameObject.GetWithTag( "characterModel" ), true ) -- tue > sort by distance asc , first = closest 
    characterHit = characterHit[1]
    
    if 
        characterHit ~= nil and
        (hit == nil or characterHit.distance < hit.distance) 
    then
        hit = characterHit
    end
    
    if hit == nil then hit = {} end
    
    --
    local endPosition = hit.hitLocation
    if endPosition == nil then
        endPosition = self.shootRay.position + self.shootRay.direction * 9999
    end
    
    local lineGO = GameObject.New("Line", {
        transform = { position = self.shootRay.position },
        modelRenderer = { model = "Lines/Red" }
    } )
    
    local damage = self.damage - 1 -- -1 to have damage between 0 and 2
    Draw.LineRenderer.New( lineGO, { endPosition = endPosition, width = 1 } ) -- width = math.lerp( 0.1, 2, self.damage / self.maxDamage )
    
    Tween.Tweener( {
        target = lineGO.modelRenderer,
        property = "opacity",
        endValue = 0,
        duration = 2,
        OnComplete = function() lineGO:Destroy() end        
    } )
    
    
    -- 
    if hit.gameObject ~= nil then
        local target = hit.gameObject.parent -- the character root
        if target ~= nil and target:HasTag( "character" ) then
            cprint( self.gameObject, "has hit", target , "with damage", self.damage)
            target.s:TakeDamage( self.damage, self.gameObject )
            --Daneel.Event.Fire( hitObject, "TakeDamage" )
            -- gain points ?
        end
    end
end

function Behavior:TakeDamage( amount, sourceGO )
    self.health = self.health - amount
    
    if self.health < 0 then
        self:Die()
        --Daneel.Event.Fire( "OnPlayerKilled", { victim = self.gameObject, killer = sourceGO } )
    end
end

function Behavior:Die()
    cprint( "Player died", self.gameObject )
    
    Client.player.isSpawned = false
    Level.levelSpawns[ Client.player.team ]:AddComponent( "Camera" )
    Level.hudCamera.Recreate()
    
    Level.menu.Show()
    self.gameObject:Destroy()
end
