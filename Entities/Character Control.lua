--[[PublicProperties
isPlayable boolean False
/PublicProperties]]

CharacterPrefab = CS.FindAsset( "Entities/Character" )
CharacterScript = nil -- used in HUD, only set for the character that the client controls

function Behavior:Awake()
    self.gameObject.s = self
    self.gameObject:AddTag( "character" )
    
    self.modelGO = self.gameObject:GetChild( "Model" )
    self.modelGO:AddTag( "characterModel" )
    self.cameraGO = self.gameObject:GetChild( "Camera", true )
    self.crosshairGO = self.cameraGO:GetChild( "Crosshair" )
    
    -- movements
    local gameConf = GetGameConfig()
    self.rotationSpeed = gameConf.character.rotationSpeed
    self.walkSpeed = gameConf.character.walkSpeed
    self.jumpSpeed = gameConf.character.jumpSpeed
    
    self.lookAngles = nil -- is set to the current's modelGO's euler angles the first time Update() runs

    self.isOnGround = true
    self.isFalling = false
     
    
    -- shooting
    self.maxHealth = gameConf.character.health
    self.health = self.maxHealth
    
    self.damage = gameConf.character.weaponDamage
    self.shootRate = gameConf.character.shootRate
    self.lastShootFrame = 0
    
    self.shootRay = Ray()
    
    --
    self.frameCount = 0
    self.isLocked = true
    
    if self.playerId == nil then -- set in Client:SpawnPlayer()
        self.playerId = 0
    end
    
    self:SetTeam(1)
        
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
        
    if self.playerId >= 0 then
        -- for debug
        self.gameObject.name = "Character: "..self.player.name
        self.modelGO.name = "Character model: "..self.player.name
    end
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


function Behavior:SetPlayerId( playerId )
    self.playerId = playerId
    self.player = GetPlayer( playerId )
    
    self.gameObject.networkSync:Setup( NetworkSyncIds.characters + playerId )
end


-- Called from Client:SpawnPlayer() or Awake() above
-- This character is the one the player controls
-- Never called on the server
function Behavior:SetupPlayableCharacter() 
    CharacterScript = self -- used in HUD
    self.isPlayable = true
    
    -- remove level spawn camera
    local camera = Level.levelSpawns[ self.team ].camera
    if camera then
        camera:Destroy()
    end
    
    -- create the player camera
    self.cameraGO:Set({ camera = { fov = 60 } })
    -- The Character prefab has no camera component so that characters spawn without camera


    -- hud
    Level.hudCamera.Recreate() -- recreate so that it is rendered after the player camera and the hud/menu appear over the world
    
    local hudGO = Level.hud
    
    self.hud = {}

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
    
    self.isLocked = false
    
    -- for CTF
    self.flagIconGO = Level.hud:GetChild("Flag Icon")
    self.flagIconGO.modelRenderer.model = Team[self.otherTeam].models.ctf.flagIcon
    if GetGametype() == "ctf" then
        self.flagIconGO.modelRenderer.opacity = 0.2
    else
        self.flagIconGO.modelRenderer.opacity = 0
    end
end

characterInputCount = 0
characterInputTime = os.clock()

serverCharacterInputCount = 0
serverCharacterInputTime = os.clock()


function Behavior:Update()
    
    if not IsServer() and not self.isPlayable then 
        return
    end
    -- runs when server or when client and is playable
    
    self.frameCount = self.frameCount + 1
    
    local server = GetServer()
    --local player = GetPlayer( self.playerId )
    local player = self.player
    
    if player ~= nil and player.hasLeft then
        player.isSpawned = false
        player.characterGO = nil
        self.gameObject:Destroy()
        cprint("Destroying character from ChracterControl:Update()")
        return
    end
    
    if IsServer(true) and player == nil then
        -- happens sometimes ?
        print("CharacterControl:Update() : player is nil on LocalServer", self.playerId )
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
        if not Level.menu.isDisplayed and not self.isLocked then
            input = {
                -- sends the raw input, let the server check for other conditions
                spaceWasJustPressed = CS.Input.WasButtonJustPressed( "Space" ),
                leftMouseWasJustPressed = CS.Input.WasButtonJustPressed( "LeftMouse" ),
                leftMouseIsDown = CS.Input.IsButtonDown( "LeftMouse" ),
                verticalAxis = CS.Input.GetAxisValue( "Vertical" ),
                horizontalAxis = CS.Input.GetAxisValue( "Horizontal" ),
                mouseDelta = CS.Input.GetMouseDelta(),
            }
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
    else
        return
    end
    
    -----
    
    if 
        input.verticalAxis ~= 0 or
        input.horizontalAxis ~= 0 or
        input.mouseDelta.x ~= 0 or
        input.mouseDelta.y ~= 0
    then
        self:Move( input )
    end
    
    
    if input.spaceWasJustPressed then
        self:Jump()
    end
    
    
    if 
        input.leftMouseWasJustPressed or
        input.leftMouseIsDown
    then
        self:Shoot()
    end
end


-- this is basically the "move" function
function Behavior:Move( input )
    if Client.isConnected then
        self.gameObject.networkSync:SendMessageToServer( "Move", input, CS.Network.DeliveryMethod.ReliableSequenced, 1 )
        return
    end
    
    -- Rotate the character when the mouse moves around
    if self.lookAngles == nil then
        self.lookAngles = self.modelGO.transform.eulerAngles  -- this actually let the character correctly oriented when the first Update() is run
    end
    
    local mouseDelta = input.mouseDelta
    
    self.lookAngles.x = self.lookAngles.x - self.rotationSpeed * mouseDelta.y
    self.lookAngles.x = math.clamp( self.lookAngles.x, -60, 60 )
    self.lookAngles.y = self.lookAngles.y - self.rotationSpeed * mouseDelta.x
    
    self.modelGO.transform:SetEulerAngles( self.lookAngles )
    
    -- Moving around
    local vertical = input.verticalAxis
    local horizontal = input.horizontalAxis

    -- Walking forward / backward
    local newVelocity = Vector3:Forward() * vertical * self.walkSpeed
    -- Strafing (left/right)
    newVelocity = newVelocity - Vector3:Left() * horizontal * self.walkSpeed

    local characterOrientation = Quaternion:FromAxisAngle( Vector3:Up(), self.lookAngles.y )
    newVelocity = newVelocity:Rotate( characterOrientation )
    newVelocity.y = self.gameObject.physics:GetLinearVelocity().y
    
    self.gameObject.physics:SetLinearVelocity( newVelocity )  
end
CS.Network.RegisterMessageHandler( Behavior.Move, CS.Network.MessageSide.Server )


function Behavior:Jump()
    if Client.isConnected then
        self.gameObject.networkSync:SendMessageToServer( "Jump", nil, CS.Network.DeliveryMethod.ReliableOrdered, 2 )
        return
    end
    
    local bottomRay = Ray:New( self.gameObject.transform:GetPosition(), -Vector3:Up() )
    local groundDistance = bottomRay:IntersectsMapRenderer( Level.mapGO.mapRenderer ) 
    
    self.isOnGround = false
    if groundDistance ~= nil and groundDistance < 2 then
        self.isOnGround = true
    end
    
    if self.isOnGround then
        self.gameObject.physics:ApplyImpulse( Vector3:New( 0, self.jumpSpeed, 0 ) )       
        self.isOnGround = false
    end
end
CS.Network.RegisterMessageHandler( Behavior.Jump, CS.Network.MessageSide.Server )


function Behavior:Shoot()
    if Client.isConnected then
        self.gameObject.networkSync:SendMessageToServer( "Shoot", nil, CS.Network.DeliveryMethod.ReliableOrdered, 3 )
        return
    end
    
    if self.lastShootFrame + (60/self.shootRate) < self.frameCount then    
        self.lastShootFrame = self.frameCount
    else
        return -- not time to shoot again
    end
    
    self.shootRay.position = self.cameraGO.transform.position
    self.shootRay.direction = self.crosshairGO.transform.position - self.shootRay.position
    -- /!\ can't do that if the camera is not aligned with the character's main position
    -- just take the position and direction of the "gun" if any

    local mapHit = self.shootRay:IntersectsMapRenderer( Level.mapGO.mapRenderer, true )
    
    local tags = { "characterModel" }
    local server = GetServer()
    if not server.game.friendlyFire then
        -- firedly fire is OFF, only get the characters of the other team
       table.insert( tags, Team[self.team].otherTeamTag )
    end
    

    local characters = GameObject.GetWithTag( tags )
    -- characters is the list of the character's "Model" game object (with the model renderer), child of the character's root game object
    
    local characterHit = self.shootRay:Cast( characters, true )[1] -- true > sort by distance asc , first = closest
    -- characterHit is a RaycastHit (or nil) with data on the closest player hit
    
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
    
    -- Was something hit ?
    if hit.gameObject ~= nil then
        local target = hit.gameObject.parent -- the character root, hit.gameObject is the character's "Model" game object
        
        -- target is nil if hit == mapHit
        if target ~= nil and target:HasTag( "character" ) then
            target.s:TakeDamage( self.damage, self.playerId ) -- self.playerId is 0 when offline
        end
    end
    
    self:CreateShootLine( { endPosition = hit.hitLocation } )
end
CS.Network.RegisterMessageHandler( Behavior.Shoot, CS.Network.MessageSide.Server )


function Behavior:CreateShootLine( data )
    if data == nil then -- shoudl never happens
        data = {}
    end
    
    local endPosition = data.endPosition
    if endPosition == nil then -- 09/04/14 that's never the case ?
        endPosition = self.shootRay.position + self.shootRay.direction * 9999
    end
    
    if IsServer(true) then
        self.gameObject.networkSync:SendMessageToPlayers( "CreateShootLine", { endPosition = endPosition }, LocalServer.playerIds )
    end
    
    local lineGO = GameObject.New( "Line", {
        transform = { position = self.modelGO.transform.position },
        modelRenderer = { model = Team[ self.team ].models.bulletTrail },
        lineRenderer = { endPosition = Vector3(endPosition), width = 0.1 }
    } )
    
    Tween.Tweener( {
        target = lineGO.modelRenderer,
        property = "opacity",
        endValue = 0,
        duration = 1,
        OnComplete = function() lineGO:Destroy() end        
    } )
end
CS.Network.RegisterMessageHandler( Behavior.CreateShootLine, CS.Network.MessageSide.Players )


-- Called from Shoot() above.
-- Or called from the server (damage is the data)
function Behavior:TakeDamage( damage, killerPlayerId )
    if type( damage ) == "table" then
        killerPlayerId = damage.killerPlayerId
        damage = damage.damage
    end
    
    if IsServer(true) then
        self.gameObject.networkSync:SendMessageToPlayers( "TakeDamage", { damage = damage, killerPlayerId = killerPlayerId }, LocalServer.playerIds )
    end
    
    self.health = self.health - damage
    if self.hud ~= nil and self.hud.healthbar ~= nil then
        -- happens when : this character is the one the player (a connected client or offline) controls
        self.hud.healthbar.value = self.health
    end
    
    if not Client.isConnected and self.health <= 0 then -- offline or server
        self:Die( killerPlayerId )
    end
end
CS.Network.RegisterMessageHandler( Behavior.TakeDamage, CS.Network.MessageSide.Players )


-- killerPlayerId 
-- (nil) From Gametype.EndRound()
-- (number) The id of the killer player - From CharacterControl:TakeDamage() locally on any client, From Server:SetCharacterInput() locally on the server
-- (table) From the server.
function Behavior:Die( killerPlayerId )
    if type( killerPlayerId ) == "table" then
        killerPlayerId = killerPlayerId.killerPlayerId
    end
    
    local server = GetServer()
    local player = self.player
    
    if killerPlayerId ~= nil then
        local deadName = "Dead Name"
        deadName = self.player.name
        self.player.deaths = self.player.deaths + 1
        
        local gtConfig = GetGametypeConfig()
        self.player:UpdateScore( gtConfig.deathScore )
    
        local text = ""
                
        local killerName = "Killer Name"
        if killerPlayerId ~= self.playerId then -- not a suicide
            local killer = GetPlayer( killerPlayerId )
            text = killer.name.." has killed "..deadName
            
            killer.kills = killer.kills + 1
            killer:UpdateScore( gtConfig.killScore )
        else
            text = deadName.." committed suicide."
        end
        
        Tchat.AddLine( text )
    end
    
    
    -- CTF
    if server.game.gametype == "ctf" then
        -- detach ctf flag
        local flag = self.modelGO:GetChild("CTF Flag")
        if flag ~= nil then
            flag.s:Drop( self.playerId )
        end
        -- flag is dropped and moved at the correct location on all clients by the server
        -- but do it here too to make sure that the flag is dropped if the network is laggy
        -- "flag" variable will be nil if the flag has already been dropped
    end
    
    --
    self.player.isSpawned = false
    self.player.characterGO = nil
    self.gameObject:Destroy()

    
    if IsServer(true) then
        self.gameObject.networkSync:SendMessageToPlayers( "Die", { killerPlayerId = killerPlayerId }, LocalServer.playerIds )
    end
    
    if self.isPlayable then
        CharacterScript = nil
        Client.player.isSpawned = false
        Client.player.characterGO = nil
        Gametype.ResetLevelSpawn( player.team )
        Level.menu.Show()
    end
end
CS.Network.RegisterMessageHandler( Behavior.Die, CS.Network.MessageSide.Players )


-- CTF events sent by the CTFFlag script

function Behavior:OnPickUpCTFFlag()
    self.player:UpdateScore( GetGametypeConfig().flagPickupScore )

    if self.isPlayable and self.flagIconGO ~= nil then
        local endScale = self.flagIconGO.transform.localScale
        Tween.Tweener.New( {
            startValue = Vector3(50,50,1),
            endValue = endScale,
            property = "localScale",
            target = self.flagIconGO.transform,
            duration = 0.5
        } )
            
        local currentPos = self.flagIconGO.hud.position
        local middle = CS.Screen.GetSize()/2
        Tween.Tweener.New( {
            startValue = middle,
            endValue = currentPos,
            property = "position",
            target = self.flagIconGO.hud,
            duration = 0.5,
        } )
        
        self.flagIconGO.modelRenderer.opacity = 1
    end
end

function Behavior:OnCaptureCTFFlag()
    self.player:UpdateScore( GetGametypeConfig().flagCaptureScore )
    
    if self.isPlayable and self.flagIconGO ~= nil then
        self.flagIconGO.modelRenderer.opacity = 0.2
    end
end

function Behavior:OnReturnedCTFFlag()
    self.player:UpdateScore( GetGametypeConfig().flagReturnHomeScore )
end


-- Called by Server:Update()
function Behavior:UpdatePosition( data )
if data.eulerAngles then
        self.modelGO.transform:SetEulerAngles( Vector3( data.eulerAngles )  )
    end
    
    if data.position then
        self.gameObject.physics:WarpPosition( Vector3( data.position ) )
    end
    
    
end
CS.Network.RegisterMessageHandler( Behavior.UpdatePosition, CS.Network.MessageSide.Players )
