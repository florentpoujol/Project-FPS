
Player = {
    defaultProperties = {
        id = 0, -- given by the server
        name = "Player", -- set in the Main Menu - loaded from save
        
        hasLeft = false,
        
        team = 1, -- chosen by the server/player
        kills = 0,
        deaths = 0,
        score = 0,
        isReady = false, -- has completely loaded the current level. Set to true in Start() in the common level manager, set to false in LoadLevel() below, used in Client:UpdateGameState()
        
        isSpawned = false,
        characterGO = nil,  
        
        messagesToSend = {},
    }
}

Player.__index = Player
Player.__tostring = function( player )
    return "Player: "..tostring(player.id)..": '"..tostring(player.name).."': "..tostring(player.team)
end

function Player.New( params )
    local player = table.copy( Player.defaultProperties, true )
    if params ~= nil then
        table.mergein( player, params )
    end
    return setmetatable( player, Player )
end

function Player.UpdateScore( player, score )
    if score ~= nil then
        player.score = player.score + score
        Level.scoreboard.Update()
    end
end


------

Client = {
    isConnected = false,
    ip = "1270.0.1", -- set in Client.GetIP()
    
    server = nil, -- The server (server instance) the Client is connected to. Set in Client:OnConnected(), unset in Client.Init()
    player = nil, -- A copy of the Player object this client controls. Set in Client.Init() or Client:OnConnected()
}


-- "Reset" a client and offline server
-- Called from Server.Stop(), server:Connect(), Client:OnDisconnected()
function Client.Init()
    Client.isConnected = false
    Client.server = nil -- Client.server is set to the server's instance of the server it is connected to (always nil when offine)
    Client.player = Player.New() -- A reference to a player tnstance in Client.server.playersById. No need to load the player name from storage here since it is set in Player.name.
    
    -- for offline
    LocalServer = Server.New( ServerConfig )
    LocalServer.isOnline = false
    LocalServer.playersById[ 0 ] = Client.player
end
Client.Init()


-- Cet the client's IP
function Client.GetIp( callback )
    CS.Web.Get( "http://craftstud.io/ip", nil, CS.Web.ResponseType.Text, function( error, ip )
        if error ~= nil then
            cprint( "Error getting IP", error.message )
            return
        end
        
        if ip == nil or ip == "" then
            cprint("GetIP : no IP returned")
        else
            local ips = ip:split( ',' ) -- when connected from some network, 2 IPs separated by a coma are returned
            Client.ip = ips[2] or ips[1]
            Client.ip = Client.ip:trim()
            cprint("GetIP : ", ip, Client.ip )
        end
    end )
end
Client.GetIp()


-- Connect to the provided ip or server and register as player
-- callback parameters is the success callback of CS.Network.Connect()
function Client.ConnectAsPlayer( ipOrServer, callback )
    local server = ipOrServer
    if type( ipOrServer ) == "string" then -- IP
        server = Server.New()
        server.ip = ipOrServer
    end
       
    server:Connect( function()
        ServerGO.networkSync:SendMessageToServer( "RegisterPlayer", { name = Player.name } )
        if callback ~= nil then
            callback()
        end
    end )
end


-- Called from UI script when player clicks on the Disconnect button in the menu
function Client.Disconnect()
    CS.Network.Disconnect()
    Client.Init()
    Scene.Load( "Menus/Server Browser" )
end


------------------------------------------------------------


function Behavior:Awake()
    self.gameObject.client = self
    -- self.gameObject and ServerGO (set in Server script) should be the same game object

    -- Called when a player is disconnected by the server with CS.Network.Server.DisconnectPlayer() 
    -- or when the server stops
    -- or when the client wasn't able to connect
    -- NOT called by CS.Network.Disconnect()
    -- CS.Network.Server.OnPlayerLeft() is called next (but not when the server stops)
    CS.Network.OnDisconnected( function()
        self:OnDisconnected()
    end )
end


------------------------------------------------------------
-- Network Message handlers


-- Called by CS.Network.Server.OnPlayerJoined() when the client has just connected to the server
-- Data holds the server data as well as the playerId
function Behavior:OnConnected( data )
    Client.isConnected = true
    LocalServer = nil
    
    Client.server = Server.New( data.server )
    for id, player in pairs( Client.server.playersById ) do
        Client.server.playersById[ id ] = Player.New( player )
    end
    
    -- at this point the client has not registered itself as a player yet
    -- so Client.server.playersById does not contain Client.player yet
    Client.player.id = data.playerId
    
    Daneel.Event.Fire( "OnConnected", Client.server ) -- "sends" the server data to the server browser
end
CS.Network.RegisterMessageHandler( Behavior.OnConnected, CS.Network.MessageSide.Players )


-- Called by the server just before the player is disconnected mostly to notify the client of the reason for the disconnection.
-- OR called by CS.Network.OnDisconnected()
-- NOT called by CS.Network.Disconnect()
function Behavior:OnDisconnected( data )
    if data ~= nil and data.reason ~= nil then
        -- called from the server
        cprint( "Client:OnDisconnected()", data.reason )
        Client.disconnectionReason = data.reason
        
        -- OnDisconnected is called from the server to notify of the reason for disconnection
        -- The player will then be disconnected via CS.Network.Server.DisconnectPlayer()
        -- which calls CS.Network.OnDisconnected() 
        -- which calls Client:OnDisconnected() one more time but without data
    else
        -- called from CS.Network.OnDisconnected()
        Client.Init()
        Scene.Load( "Menus/Server Browser" )
    end
end
CS.Network.RegisterMessageHandler( Behavior.OnDisconnected, CS.Network.MessageSide.Players )


-- Called from Server:RegisterPlayer()
-- on the newly connected player, on all other players and on the server
function Behavior:OnPlayerJoined( player )   
    local server = GetServer()
    player = Player.New( player )
    server.playersById[ player.id ] = player
    server.playerIds = table.getkeys( server.playersById ) -- 06/04/14 why don't I just do table.insert( LocalServer.playerIds, player.id )
    
    if player.id ~= Client.player.id then -- On server and Client when the new player is another player
        Tchat.AddLine( "Player #"..player.id.." '"..player.name.."' joined." )
        Level.scoreboard.Update()
        
    else -- newly connected player
        Client.player = player -- the only new data at this point is the team
        
        Daneel.Event.Listen( 
            "OnStart", 
            function()
                Tchat.AddLine( "You are now connected as player with id #"..player.id.." and name '"..player.name.."." )
                return false -- automatically stop to listen
            end, 
            true -- persistent listener, won't stop to listen when the scene changes (but will still stop to listen because the function returns false (so this is a one-time persistent listener))
        )
        -- This displays the "you are now connected..." message in the chat after the proper level has been loaded
        -- (really gotta find a proper way to store data for after the scene is loaded !)
    end
    
    if IsServer(true) then
        self.gameObject.networkSync:SendMessageToPlayers( "OnPlayerJoined", player, LocalServer.playerIds )
        
        local data = {
            scenePath = LocalServer.game.scenePath,
            gametype = LocalServer.game.gametype,
        }
        self.gameObject.networkSync:SendMessageToPlayers( "LoadLevel", data, { player.id } ) 
    end
       
    -- The new character is created on the server and all pre-existing players only when it spawns
    
    -- All characters/objectives are created/updated on the newly connected player in Client:UpdateGameState() 
    -- which will be called by the server when the player is ready (has loaded the level).
    -- Client:LoadLevel() below is called next by the server (from Server:SpawnPlayer()) 
end
CS.Network.RegisterMessageHandler( Behavior.OnPlayerJoined, CS.Network.MessageSide.Players )


-- Called from CS.Network.Server.OnPlayerLeft()
-- on all remaining players and on the server.
-- Only receive the playerId  and (maybe) reason for disconnection.
-- NOT called on the disconnected player
function Behavior:OnPlayerLeft( data )
    local server = GetServer()
    local player = GetPlayer( data.playerId )
    
    if data.reason == nil then
        data.reason = "Disconnected"
    end
    
    local text = "Player '"..player.name.."' has left for reason : "..data.reason
    Tchat.AddLine( text )
    
    player.hasLeft = true
    player.isSpawned = false
    if player.characterGO ~= nil then
        -- detach ctf flag
        local flag = player.characterGO.s.modelGO:GetChild("CTF Flag")
        if flag ~= nil then
            flag.s:Drop( player.id )
        end
        -- flag is dropped and moved at the correct location on all clients by the server
        -- but do it here too to make sure that the flag is dropped if the network is laggy
        -- flag variable will be nil if the flag has already been dropped (or current gametype isn't CTF)
        
        player.characterGO:Destroy() -- remove character
        player.characterGO = nil
    end
    
    server.playersById[ data.playerId ] = nil
    server.playerIds = table.getkeys( server.playersById )
    Level.scoreboard.Update()
    
    if IsServer(true) then
        self.gameObject.networkSync:SendMessageToPlayers( "OnPlayerLeft", data, LocalServer.playerIds )
    end
end
CS.Network.RegisterMessageHandler( Behavior.OnPlayerLeft, CS.Network.MessageSide.Players )


-- Called by the server when the admin change the level (see the AdminCmd object in "Game Config" script)
-- or by Server:RegisterPlayer() (Client:OnPlayerJoined() is called first)
function Behavior:LoadLevel( data )
    local server = GetServer()
    
    for id, player in pairs( server.playersById ) do
        player.isReady = false -- set to true locally in "Common Level Manager:Start()" or in Server:MarkPlayerReady() (useless to do and has not effect on clients)
        player.characterGO = nil
        player.isSpawned = false
        
        player.kills = 0
        player.deaths = 0
        player.score = 0
    end
    
    if data and data.gametype then
        server.game.gametype = data.gametype
    end
    if data.scenePath ~= nil then
        server.game.scenePath = data.scenePath
    end
    if data.roundTime then
        server.game.roundTime = data.roundTime
    end
    
    Scene.Load( server.game.scenePath )
end
CS.Network.RegisterMessageHandler( Behavior.LoadLevel, CS.Network.MessageSide.Players )


-- Called from Server:SetPlayerInput() on each client and the server,
-- or called from Client:UpdateGameState(),
-- or from the UI script (without data, when offline),
-- Data argument contains the playerId and the spawn's position and eulerAngles
function Behavior:SpawnPlayer( data )
    if not data then -- offline
        data = {
            playerId = 0
        }
    end
    
    local player = GetPlayer( data.playerId )
    
    if not data.position or not data.eulerAngles then -- offline
        local spawnGO = Gametype.GetSpawn( player.team )
        data.position = spawnGO.transform.position
        data.eulerAngles = spawnGO.transform.eulerAngles
    end
    
    local go = GameObject.New( CharacterPrefab )
    go.physics:WarpPosition( Vector3( data.position ) )
    go.s.modelGO.transform.eulerAngles = Vector3( data.eulerAngles )
    print("spawn player", IsServer(true), Vector3( data.eulerAngles ))
    
    go.s:SetPlayerId( player.id )
    go.s:SetTeam( player.team )
    player.characterGO = go
    player.isSpawned = true
    
    if not IsServer(true) and data.playerId == Client.player.id then
        -- give control of the character to the player
        player.characterGO.s:SetupPlayableCharacter()
    elseif IsServer(true) then
        self.gameObject.networkSync:SendMessageToPlayers( "SpawnPlayer", data, LocalServer.playerIds )
    end
end
CS.Network.RegisterMessageHandler( Behavior.SpawnPlayer, CS.Network.MessageSide.Players )


-- Called from UI script "Change Team" button OnClick event (when offline)
-- or from Server:SetPlayerInput() (when on the server)
-- or from the server (when connected client)
--
-- data contains the playerId, 
-- and the position and eulerAngles of the new spawn point (when called from the server)
function Behavior:ChangePlayerTeam( data )
    if GetGametype() == "dm" then
        return -- or force team at 1 ?
    end
    
    local player = GetPlayer( data.playerId )
    if player.isSpawned or player.characterGO then -- don't change team when player is alive
        return
    end
    
    if player.team == 1 then
        player.team = 2
    else
        player.team = 1
    end
    
    if IsServer(true) then
        self.gameObject.networkSync:SendMessageToPlayers( "ChangePlayerTeam", data, LocalServer.playerIds )
    elseif Client.player.id == player.id then
        Gametype.ResetLevelSpawn( player.team )
        Level.scoreboard.Update()
    end
end
CS.Network.RegisterMessageHandler( Behavior.ChangePlayerTeam, CS.Network.MessageSide.Players )


-- Update character and objectives position, + other game states
-- Called by Server:Update()
-- game object referrenced in data that does not exists yet on this client are created.
function Behavior:UpdateGameState( data )
    if data.roundEnded then
        Gametype.EndRound()
    end 
    

    if Client.player.isReady then
        if data.roundTime then
            Level.timerGO.Update( data.roundTime )
        end 
    
        -- spawn already spawned characters
        if data.playerIdsToSpawn then
            local server = GetServer()
        
            for i, id in pairs( data.playerIdsToSpawn ) do
                local player = server.playersById[ id ]
                
                if player.characterGO == nil then                   
                    self:SpawnPlayer( { playerId = id } )
                end
            endr
        end
    end
end
CS.Network.RegisterMessageHandler( Behavior.UpdateGameState, CS.Network.MessageSide.Players )
