function Behavior:Awake()
    self.gameObject.s = self
    
    self.team = 1
    self.teamTag = "team1"
    self.otherTeamTag = "team2"
    
    self.isPickedUp = false
    self:SetBase()
    
    self.modelGO = self.gameObject:GetChild("Model")
    self.iconGO = self.gameObject:GetChild("Icon")
    self.triggerGO = self.gameObject:GetChild("Trigger")
    self.triggerGO.modelRenderer.opacity = 0
    
    -- The trigger checks the "characterModel" tag
    -- This function is called whenever a player enters the flag's trigger
    self.triggerGO.OnTriggerEnter = function( characterModelGO )
        local playerId = characterModelGO.parent.s.playerId
        
        if characterModelGO:HasTag( self.otherTeamTag ) and not self.isPickedUp then
            -- player pickup enemy flag (at base or not at base)
            self:IsPickedUp( characterModelGO )
        
        elseif characterModelGO:HasTag( self.teamTag ) and not self.isPickedUp and not self.isAtBase then     
            -- player touch its team's flag when dropped and not at the base
            
            self:MoveToBase( playerId )
            if IsServer(true) then
                self.gameObject.networkSync:SendMessageToPlayers( "MoveToBase", { playerId = playerId }, Server.playerIds ) 
            end
        
        elseif characterModelGO:HasTag( self.teamTag ) and not self.isPickedUp and self.isAtBase then
            -- player touch its team's flag at base when cariying enemy flag
            self:Capture( characterModelGO )
        end
    end
end


function Behavior:Start()   
    self.hudFlagIconGO = GameObject.New("Flag icon", {
        hud = { 
            position = Vector2(-10),
            layer = 20, -- same layer as player HUD
        },
        modelRenderer = { model = Team[self.team].models.ctf.flagIcon },
        transform = { localScale = 2 }
    } )
    
    --[[
    Daneel.Event.Listen( "OnHudDisplayed", self.hudFlagIconGO )
    self.hudFlagIconGO.OnHudDisplayed = function( go )
        go.modelRenderer.opacity = 1
    end
    Daneel.Event.Listen( "OnHudHidden", self.hudFlagIconGO )
    self.hudFlagIconGO.OnHudHidden = function( go )
        go.modelRenderer.opacity = 0
    end]]
    
    self.frameCount = 0
end


function Behavior:Update()
    self.frameCount = self.frameCount + 1
    
    if CharacterScript ~= nil and self.frameCount % 3 == 0 then
        local point = CharacterScript.cameraGO.camera:WorldToScreenPoint( self.iconGO.transform.position )
        local screenSize = CS.Screen.GetSize()
        
        if 
            (point.x > 0 and point.x < screenSize.x) and
            (point.y > 0 and point.y < screenSize.y) and
            point.z > 0
        then
            -- point is inside the screen but behind the player
            -- move the point to the nearest edge of the screen
            if point.x < screenSize.x / 2 then
                point.x = point.x - 9999
            else
                point.x = point.x + 9999
            end
            if point.y < screenSize.y / 2 then
                point.y = point.y - 9999
            else
                point.y = point.y + 9999
            end
        end
            point.x = math.clamp( point.x, 10, screenSize.x-10 )
            point.y = math.clamp( point.y, 10, screenSize.y-10 )
        
        
        self.hudFlagIconGO.hud.position = Vector2.New( point.x, point.y )
    end
end


function Behavior:SetTeam( team )
    SetEntityTeam( self, team )
            
    if self.team > 0 then
        self.gameObject.networkSync:Setup( NetworkSyncIds.CTFFlags[self.team] )
        self.modelGO.modelRenderer.model = Team[ self.team ].models.ctf.flag
        
        if IsServer() then
            self.triggerGO.trigger.updateInterval = 4 -- "activate" the trigger
        end
    end
end


function Behavior:SetBase()
    self.isAtBase = true
    self.basePosition = self.gameObject.transform.position
end


-- data can contains the playerId of the player that moved the flag to its base
function Behavior:MoveToBase( data )
    self.gameObject.parent = nil
    self.gameObject.transform.position = self.basePosition
    self.gameObject.transform.eulerAngles = Vector3(0)  
    self.isAtBase = true
    self.isPickedUp = false
    
    if data ~= nil then
        local playerId = data
        if type( data ) == "table" then
            playerId = data.playerId
        end
        self:Notify( "backtobase", playerId )
    end
end
CS.Network.RegisterMessageHandler( Behavior.MoveToBase, CS.Network.MessageSide.Players )


-- data can be :
--         a table with the playerId of the player that picked up the flag (from CTFFlag:IsPickedUp() from the server)
-- the character's model game object of the player that picked up the flag (from self.triggerGO.OnTriggerEnter() locally on the server)
function Behavior:IsPickedUp( data ) 
    local player = nil
    
    if data.playerId then
        player = GetPlayer( data.playerId )
        data = player.characterGO.s.modelGO
    end

    if getmetatable( data ) == GameObject then -- data is the character's model game object
        self.isPickedUp = true
        self.isAtBase = false
        self.gameObject.parent = data
        self.gameObject.transform.localPosition = Vector3(0,-1,0)
        
        if player == nil then
            player = GetPlayer( data.parent.s.playerId )
        end
        
        if IsServer(true) then
            self.gameObject.networkSync:SendMessageToPlayers( "IsPickedUp", { playerId = player.id } )    
        end
    end
    
    if player ~= nil then
        self:Notify( "pickedup", player.id )
    end
end
CS.Network.RegisterMessageHandler( Behavior.IsPickedUp, CS.Network.MessageSide.Players )

-- data can be :
-- the playerId when the flag is dropped                                   (from CharacterControl:Die() or Client:OnPlayerLeft() locally on the server or clients)
-- a table with the flag's absolute position of where it has been dropped  (from CTFFlag:IsDropped() from the server)
function Behavior:IsDropped( data )
    local argType = type( data )
    local playerId = data
    
    self.isPickedUp = false
    self.gameObject.parent = nil
    self.gameObject.transform.eulerAngles = Vector3(0)

    if argType == "number" then
        -- called from CharacterControl:Die() on the erver
        -- or Client:OnPlayerLeft() on all clients

        if IsServer(true) then
            -- broadcast flag position to make sure it is "dropped" at the same position, no matter what local position as the player when he dies/disconnect
            local position = self.gameObject.transform.position
            self.gameObject.networkSync:SendMessageToPlayers( "IsDropped", { position = position, playerId = playerId  } )
        end

    elseif argType == "table" then
        -- called from CTFFlag:IsDropped() on all clients, from the server
        
        if data.position then
            self.gameObject.transform.position = Vector3( data.position )
        end
        
        if data.playerId then
            playerId = data.playerId
        end
    end
    print("isdropped")
    if playerId ~= nil then
        self:Notify( "dropped", playerId )
    end
end
CS.Network.RegisterMessageHandler( Behavior.IsDropped, CS.Network.MessageSide.Players )


function Behavior:Notify( event, playerId )
    local teamName = "Red"
    if self.team == 2 then
        teamName = "Blue"
    end
    local player = GetPlayer( playerId )
    
    local text = ""
    if event == "pickedup" then
        text = player.name.." has picked up the "..teamName.." flag !"
    elseif event == "backtobase" then
        text = player.name.." has moved the "..teamName.." flag back to base !"
    elseif event == "dropped" then
        text = player.name.." has dropped the "..teamName.." flag !"
    elseif event == "captured" then
        local teamName = "Red"
        if self.team == 1 then
            teamName = "Blue"
        end
        text = player.name.." has captured the "..teamName.." flag !"
    end
    
    if text ~= "" then
        Tchat.AddLine( text )
    end
end


-- called from OnTriggerEnter, on the server
-- or from the server on all clients
function Behavior:Capture( data )
    local eneyFlagGO = nil
    local playerId = nil
    
    if getmetatable( data ) == GameObject then
        -- 
        eneyFlagGO = data:GetChild("CTF Flag")
        playerId = data.parent.s.playerId
        
        if IsServer(true) then
            self.gameObject.networkSync:SendMessageToPlayers( "Capture", { playerId = playerId  } )
        end
    else
        -- called from server on all clients
        -- data contains the playerId
        playerId = data.playerId
        eneyFlagGO = GetPlayer( playerId ).characterGO.s.modelGO:GetChild("CTF Flag")
    end

     if eneyFlagGO ~= nil then
        
        
        -- score point
        --characterModelGO.parent.s:UpdateScore( GetServer().game.ctf.flagSecureScore )
        
        eneyFlagGO.s:MoveToBase()
        self:Notify( "captured", playerId )
    end
end
CS.Network.RegisterMessageHandler( Behavior.Capture, CS.Network.MessageSide.Players )
