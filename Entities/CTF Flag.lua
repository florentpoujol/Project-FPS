
function Behavior:Awake()
    self.gameObject.s = self
    self.frameCount = 0
    
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
            if characterModelGO:GetChild("CTF Flag") == nil then -- player does not alreaddy carry a flag
                self:PickUp( characterModelGO )
            end
        
        elseif characterModelGO:HasTag( self.teamTag ) and not self.isPickedUp and not self.isAtBase then     
            -- player touch its team's flag when dropped and not at the base
            self:MoveToBase( playerId )
        
        elseif characterModelGO:HasTag( self.teamTag ) and not self.isPickedUp and self.isAtBase then
            -- player touch its team's flag at base when cariying enemy flag
            self:Capture( characterModelGO )
        end
    end
    
    self.hudFlagIconGO = GameObject.New("Flag icon", {
        hud = { position = Vector2(-10) },
        modelRenderer = { model = Team[1].models.ctf.flagIcon },
        transform = { localScale = 2 }
    } )
    
    -- Event fired by Server:MarkPlayerReady() which is called by the client from CommonLevelManager:Start()
    Daneel.Event.Listen( "OnPlayerReady", self.gameObject )
end


function Behavior:Start()
    -- in Start() to wait for the hud to be created
    self.hudFlagIconGO.parent = Level.hud
    self.hudFlagIconGO.hud.localLayer = 0
end


function Behavior:Update()
    self.frameCount = self.frameCount + 1
    
    if CharacterScript ~= nil and self.frameCount % 1 == 0 then
        local point = CharacterScript.cameraGO.camera:WorldToScreenPoint( self.iconGO.transform.position )
        local screenSize = CS.Screen.GetSize()
        
        if 
            (point.x > 0 and point.x < screenSize.x) and
            (point.y > 0 and point.y < screenSize.y) and
            point.z > 0
        then
            -- point is inside the screen but behind the player
            point.x = -50
            point.y = -50
        end

        self.hudFlagIconGO.hud.position = Vector2.New( point.x, point.y )
    end
end

CTFFlagIds = { 0, 0 }

function Behavior:SetTeam( team )
    SetEntityTeam( self, team )
            
    if self.team > 0 then
        self.gameObject.networkSync:Setup( NetworkSyncIds.CTFFlags * 100 + team * 10 + CTFFlagIds[team] ) -- 310 for the first flag (id=0) of the team 1
        CTFFlagIds[team] = CTFFlagIds[team] + 1
        
        self.modelGO.modelRenderer.model = Team[ self.team ].models.ctf.flag
        self.hudFlagIconGO.modelRenderer.model = Team[ self.team ].models.ctf.flagIcon
        
        if IsServer() then
            self.triggerGO.trigger.updateInterval = 4 -- "activate" the trigger
        end
    end
end


function Behavior:SetBase()
    self.isAtBase = true
    self.basePosition = self.gameObject.transform.position
end


-- Called from trigger.OnTriggerEnter() on the server (data is the playerId as a number)
-- or from the server (data contains the player id)
-- or from CTFFlag:Capture() on all players + server (data is nil)
function Behavior:MoveToBase( data, sendMessage )
    self.gameObject.parent = nil
    self.gameObject.transform.position = self.basePosition
    self.gameObject.transform.eulerAngles = Vector3(0)  
    self.isAtBase = true
    self.isPickedUp = false
    
    if data ~= nil then
        local playerId = data
        
        if type( data ) == "table" then
            playerId = data.playerId
        else
            data = { playerId = playerId }
        end
        self:Notify( "backtobase", playerId )
        GetPlayer( playerId ).characterGO:SendMessage("OnReturnedCTFFlag")
    end
    
    if IsServer(true) and sendMessage ~= false then
        -- 07/04 it seems that event if data is nil at this point, the function on the player side receive an (empty) table
        self.gameObject.networkSync:SendMessageToPlayers( "MoveToBase", data, LocalServer.playerIds ) 
    end
end
CS.Network.RegisterMessageHandler( Behavior.MoveToBase, CS.Network.MessageSide.Players )


-- data can be :
--         a table with the playerId of the player that picked up the flag (from CTFFlag:PickUp() from the server)
-- the character's model game object of the player that picked up the flag (from self.triggerGO.OnTriggerEnter() locally on the server)
function Behavior:PickUp( data ) 
    local player = nil
    
    if data.playerId then
        player = GetPlayer( data.playerId )
        data = player.characterGO.s.modelGO
    end

    if getmetatable( data ) == GameObject then -- data is the character's model game object
        self:AttachTo( data )
        
        if player == nil then
            player = GetPlayer( data.parent.s.playerId )
        end
        
        if IsServer(true) then
            self.gameObject.networkSync:SendMessageToPlayers( "PickUp", { playerId = player.id }, LocalServer.playerIds )    
        end
    end
    
    if player ~= nil then
        self:Notify( "pickedup", player.id )
        player.characterGO:SendMessage("OnPickUpCTFFlag")
    end
end
CS.Network.RegisterMessageHandler( Behavior.PickUp, CS.Network.MessageSide.Players )


-- go (GameObject) is the character's model game object.
-- Called by PickUp() and OnPayerReady()
function Behavior:AttachTo( go )
    self.isPickedUp = true
    self.isAtBase = false
    self.gameObject.parent = go
    self.gameObject.transform.localPosition = Vector3(0,-1,0)
    self.gameObject.transform.localEulerAngles = Vector3(0)
end


-- data can be :
-- the playerId when the flag is dropped                                   (from CharacterControl:Die() or Client:OnPlayerLeft() locally on the server or clients)
-- a table with the flag's absolute position of where it has been dropped  (from CTFFlag:Drop() from the server)
function Behavior:Drop( data )
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
            self.gameObject.networkSync:SendMessageToPlayers( "Drop", { position = position, playerId = playerId  } )
        end

    elseif argType == "table" then
        -- called from CTFFlag:Drop() on all clients, from the server
        
        if data.position then
            self.gameObject.transform.position = Vector3( data.position )
        end
        
        if data.playerId then
            playerId = data.playerId
        end
    end
    
    if playerId ~= nil then
        self:Notify( "dropped", playerId )
        -- no need to send the drop notification to the player since the only case when it drops the flag is when it dies
    end
end
CS.Network.RegisterMessageHandler( Behavior.Drop, CS.Network.MessageSide.Players )


-- Notify players of what happend via the chat
function Behavior:Notify( event, playerId )
    if playerId == nil then
        return
    end

    local teamName = "Red"
    if self.team == 2 then
        teamName = "Blue"
    end
    local player = GetPlayer( playerId )
    
    local text = event
    if event == "pickedup" then
        text = "picked up"
    elseif event == "backtobase" then
        text = "returned"
    elseif event == "captured" then
        teamName = "Red"
        if self.team == 1 then
            teamName = "Blue"
        end
    end
    
    if text ~= "" then       
        Tchat.AddLine( player.name.." has "..text.." the "..teamName.." flag !" )
    end
end


-- data can be :
-- (GameObject) The character model's game object - From OnTriggerEnter()
-- (table) Contains the player id - From CTFFlag:Capture() on the server to all clients
function Behavior:Capture( data )
    local eneyFlagGO = nil
    local playerId = nil
       
    if getmetatable( data ) == GameObject then
        -- on server from OnTriggerEnter()
        eneyFlagGO = data:GetChild("CTF Flag")
        playerId = data.parent.s.playerId
        
        if IsServer(true) then
            self.gameObject.networkSync:SendMessageToPlayers( "Capture", { playerId = playerId  }, LocalServer.playerIds )
        end
    else
        -- called from server on all clients
        playerId = data.playerId
        eneyFlagGO = GetPlayer( playerId ).characterGO.s.modelGO:GetChild("CTF Flag")
    end

    if eneyFlagGO ~= nil then
        local player = GetPlayer( playerId )
        
        eneyFlagGO.s:MoveToBase( nil, false ) -- don't send message
        self:Notify( "captured", playerId )
        player.characterGO:SendMessage("OnCaptureCTFFlag")
    end
end
CS.Network.RegisterMessageHandler( Behavior.Capture, CS.Network.MessageSide.Players )


-- Catch the event fired in Server:MarkPlayerReady() (data contains the playerId in the first index or the playerId key), itself called by a client when finished loading the level (CommonLevelManager:Start())
-- Send to the client the current state of the flag
function Behavior:OnPlayerReady( data )
    local playerId = data[1]

    if IsServer(true) then
        data = {}
        if self.isPickedUp then
            data.parentId = self.gameObject.parent.parent.s.playerId -- self.gameObject.parent is the character model game object (if the flag is currently pickedup by a player)
        elseif not self.isAtBase then
            -- flag not picked up, just send its position if it is not at the base
            data.position = self.gameObject.transform.position
        end
        
        if data.parentId ~= nil or data.position ~= nil then
            self.gameObject.networkSync:SendMessageToPlayers( "OnPlayerReady", data, { playerId } )
        end
    else
        if data.parentId ~= nil then
            local characterGO = GetPlayer( data.parentId ).characterGO

            self.gameObject.parent = characterGO.s.modelGO
            self.gameObject.transform.localPosition = Vector3(0,-1,0)
            self.gameObject.transform.localEulerAngles = Vector3(0)
        elseif data.position then
            self.gameObject.transform.position = Vector3( data.position )
        end
    end
end
CS.Network.RegisterMessageHandler( Behavior.OnPlayerReady, CS.Network.MessageSide.Players )


