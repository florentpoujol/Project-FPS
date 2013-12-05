--[[PublicProperties
isNPC boolean False
/PublicProperties]]

CharacterPrefab = CS.FindAsset( "Entities/Character" )

function Behavior:Awake()
    self.gameObject.s = self
    
    self.gameObject:AddTag( "characters" )
    
    CS.Input.LockMouse()
    
    self.mapGO = GameObject.Get( "Map" )
    self.modelGO = self.gameObject:GetChild( "Model" )
    self.modelGO:AddTag( "charactersModel" )
    self.trailGO = self.gameObject:GetChild( "Trail" )
    
    if not self.isNPC then
        self.cameraGO = self.gameObject:GetChild( "Camera" )
        self.camera2GO = self.gameObject:GetChild( "ThirdPersonCamera" )
        self.camera2GO.camera:SetRenderViewportPosition( 0.6, 0 ) -- right top
        self.camera2GO.camera:SetRenderViewportSize( 0.4, 0.4 )
        self.camera2GO.transform:LookAt( self.gameObject.transform.position )
    end
    
    
    -- hud
    local hudGO = Level.hud
    
    self.hud = {}
    self.hud.isOnGroundGO = hudGO:GetChild( "IsOnGround", true )
    self.hud.isFallingGO = hudGO:GetChild( "IsFalling", true )    
    self.hud.groundDistance = hudGO:GetChild( "GroundDistance", true )      
    self.hud.damages = hudGO:GetChild( "Damages.Text", true )   
    
    
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
    -- players can hold the left mouse button to "charge" the laser and do more than 1 damage
    
    self.shootRay = Ray()
    
    
    --
    self.frameCount = 0
end

function Behavior:Start()
    self.lastTrailPosition = self.gameObject.transform.position   
    
end

function Behavior:Update()
    if self.isNPC then return end
    
    self.frameCount = self.frameCount + 1
    
    -- Movement code mostly ripped from the Character Control script of the Sky Arena project (7DFPS 2013)  
    -- Jumping
    local bottomRay = Ray:New( self.gameObject.transform:GetPosition(), -Vector3:Up() )
    
    local groundDistance = bottomRay:IntersectsMapRenderer( self.mapGO.mapRenderer ) 
       
    local lastIsOnGround = self.isOnGround
    self.isOnGround = false
    if groundDistance ~= nil and groundDistance < 6 then
        self.isOnGround = true
    end
    
    if self.isOnGround and CS.Input.WasButtonJustPressed( "Space" ) then
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
    local vertical = CS.Input.GetAxisValue( "Vertical" )
    local horizontal = CS.Input.GetAxisValue( "Horizontal" )

    -- Walking forward / backward
    local newVelocity = Vector3:Forward() * vertical * self.walkSpeed
    -- Strafing
    newVelocity = newVelocity - Vector3:Left() * horizontal * self.walkSpeed

    local characterOrientation = Quaternion:FromAxisAngle( Vector3:Up(), self.angleY )
    newVelocity = Vector3.Transform( newVelocity, characterOrientation )
    newVelocity.y = velocity.y
    
    self.gameObject.physics:SetLinearVelocity( newVelocity )
    
    
    -- shooting
    local lastDamage = self.damage
    if CS.Input.IsButtonDown( "LeftMouse" ) then
        self.chargeFrame = self.chargeFrame + 1
        --if self.chargeFrame > self.maxChargeFrame + 30 then -- player holds the charge button 1/2 second more than necessary
          --  self.chargeFrame = 0
--        end
        
        self.damage = math.lerp( 1, self.maxDamage, self.chargeFrame / self.maxChargeFrame )
        self.damage = math.round( math.clamp( self.damage, 1, self.maxDamage ), 1 )
    end
    
    if CS.Input.WasButtonJustReleased( "LeftMouse" ) then
        self:Shoot()
        self.damage = 1
        self.chargeFrame = 0
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
    
    if lastDamage ~= self.damage then
        self.hud.damages.textRenderer.text = "Damages: "..tostring( math.round( self.damage, 1 ) )
    end
    
    if groundDistance == nil then
        groundDistance = 9999
    end
    self.hud.groundDistance.textRenderer.text = "groundDistance: "..tostring( math.round( groundDistance, 2 ) )
end


function Behavior:Shoot()
    self.shootRay.position = self.cameraGO.transform.position
    self.shootRay.direction = self.shootRay.position - self.gameObject.transform.position -- can't do that if the camera is not aligned with the character's main position
    
    local hit = self.shootRay:IntersectsMapRenderer( self.mapGO.mapRenderer, true ) -- tue > return raycast hit  
    
    local characterHit = self.shootRay:Cast( GameObject.GetWithTag( "charactersModel" ), true ) -- tue > sort by distance asc , first = closest 
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
    Draw.LineRenderer.New( lineGO, { endPosition = endPosition, width = math.lerp( 0.1, 2, self.damage / self.maxDamage ) } )
    
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
        if target ~= nil and target:HasTag( "characters" ) then
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
        Daneel.Event.Fire( "OnPlayerKilled", { victim = self.gameObject, killer = sourceGO } )
    end
end

function Behavior:Die()
    print( "Player died", self.gameObject )
    self.gameObject:Destroy()
end
