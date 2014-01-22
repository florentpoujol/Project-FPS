

Player = {
    id = -1, -- given by the server
    name = "Player", -- set in the Main Menu - loaded from save
    
    team = 1, -- chosen by the server/player
    kills = 0,
    deaths = 0,
    isReady = false, -- has completely loaded the current level. Set to true in Start() in the common level manager, set to false in LoadLevel() below, used in Client:UpdateGameState()
    
    isSpawned = false,
    characterGO = nil,  
    
    messagesToSend = {},
}


Client = {
    isConnected = false,
    ip = "1270.0.1",
    
    server = nil, -- The server (server instance) the Client is connected to. Set in Client:OnConnected(), unset in Client.Init()
    player = nil, -- A copy of the Player object. Set in Client:OnConnected(), unset in Client.Init()
}


-- "Reset" a client
-- called a first time in Awake() below
function Client.Init()
    Client.isConnected = false
    Client.server = nil -- Client.server is nil on the server (when LocalServer is not nil)    
    Client.player = table.copy( Player, true ) -- no need to load the player name from storage here since it is set in Player.name
    
    -- for offline
    if not LocalServer then
        LocalServer = Server.New( Server.Config )
        LocalServer.isOffline = true
    end
    
    LocalServer.playersById[ -1 ] = Client.player
    
    IsClient = true
    IsServer = false
end


-- Cet Client's IP
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
function Client.ConnectAsPlayer( ipOrServer, callback )
    local server = ipOrServer
    if type( ipOrServer ) == "string" then
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


function Client.Disconnect()
    CS.Network.Disconnect()
    Client.Init()
    Scene.Load( "Menus/Server Browser" )
end


------------------------------------------------------------


function Behavior:Awake()
    self.gameObject.client = self
    -- self.gameObject and ServerGO should be the same game object
    
    if Client.server == nil and Client.player == nil then
        Client.Init() -- called from Awake() because of table.copy() (not sure it exists yet from the global scope)
    end
    
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
    
    Client.player = table.copy( Player )
    Client.player.id = data.playerId
    
    Daneel.Event.Fire( "OnConnected", Client.server ) -- "sends" the server data to the server browser
    --cprint( "Client OnConnected", data.playerId, Client.server )   
end
CS.Network.RegisterMessageHandler( Behavior.OnConnected, CS.Network.MessageSide.Players )


-- Called by the server just before the player is disconnected mostly to notify the client of the reason for the disconnection.
-- OR called by CS.Network.OnDisconnected() (NOT called by CS.Network.Disconnect())
function Behavior:OnDisconnected( data )
    if data ~= nil and data.reason ~= nil then
        -- called from the server
        cprint( "Client:OnDisconnected()", data.reason )
        Game.disconnectionReason = data.reason
        
        -- OnDisconnected is called from the server to notify of the reason for disconnection
        -- The player will then be disconnected via CS.Network.Server.DisconnectPlayer()
        -- which calls CS.Network.OnDisconnected() which calls OnDisconnected() one more time but without data
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
    --cprint(Client.player.id, "OnPlayerJoined", player.id )
    
    local server = GetServer()
    server.playersById[ player.id ] = player
    server.playerIds = table.getkeys( server.playersById )
        
    if player.id ~= Client.player.id then -- On server and Client when the new player is another player
        Tchat.AddLine( "Player #"..player.id.." '"..player.name.."' joined." )
    
    else -- newly connected player
        Client.player = table.merge( player )
        
        Daneel.Event.Listen( 
            "OnStart", 
            function()
                Tchat.AddLine( "You are now connected as player with id #"..player.id.." and name '"..player.name.."." )
                return false -- automatically stop to listen
            end, 
            true -- persistent listener, won't stop to listen when the scene changes
        ) 
        
        -- really gotta find a proper way to store data for after the scene is loaded !
        
        -- LoadLevel() below is called next by the server
    end
    
    Level.scoreboard.Update()
    
    -- The new character is created on the server and all pre-existing players only when it spawns
    
    -- All characters/objectives are created/updated on the newly connected player in Client:UpdateGameState() 
    -- which will be called by the server when the player is ready (has loaded the level).
    -- This player loads the level juste after Client:OnPlayerJoined() when the server calls Client:LoadLevel()
end
CS.Network.RegisterMessageHandler( Behavior.OnPlayerJoined, CS.Network.MessageSide.Players )


-- Called from CS.Network.Server.OnPlayerLeft()
-- on all remaining players and on the server.
-- Only receive the playerId  and (maybe) reason for disconnection.
-- NOT called on the disconnected player
function Behavior:OnPlayerLeft( data )
    local server = GetServer()
    local player = GetPlayer( data.playerId )
    player.hasLeft = true
    
    if data.reason == nil then
        data.reason = "Disconnected"
    end
    
    local text = "Player '"..player.name.."' has left for reason : "..data.reason
    Tchat.AddLine( text )
    
    if player.characterGO ~= nil then
        player.characterGO:Destroy() -- remove character
        player.characterGO = nil
    end
    -- /!\ if the player has an important item attached to it (ie: flag, bomb) /!\
    
    server.playersById[ data.playerId ] = nil
    server.playerIds = table.getkeys( server.playersById )
    
    Level.scoreboard.Update()
end
CS.Network.RegisterMessageHandler( Behavior.OnPlayerLeft, CS.Network.MessageSide.Players )


-- Called by the server when the admin change the level (from the Tchat script)
-- or by Server:RegisterPlayer() (Client:OnPlayerJoined() is called first)
function Behavior:LoadLevel( data )
    local server = GetServer()
    
    for id, player in pairs( server.playersById ) do
        player.isReady = false -- set to true locally in "Common Level Manager:Start()" or in Server:MarkPlayerReady() (useless to do and has not effect on clients)
        
        player.kills = 0
        player.deaths = 0
    end
    
    if data and data.gametype then
        server.game.gametype = data.gametype
    end
    if data.scenePath ~= nil then
        server.game.scenePath = data.scenePath
    end
    
    Scene.Load( server.game.scenePath )
end
CS.Network.RegisterMessageHandler( Behavior.LoadLevel, CS.Network.MessageSide.Players )


-- Called from Server:SetPlayerInput() on each client and the server,
-- or called from Client:UpdateGameState(),
-- or from the HUD (without data),
--
-- Data argument contains the position and playerId
function Behavior:SpawnPlayer( data )
    if not data then -- offline
        data = {
            playerId = -1
        }
    end
    
    local server = GetServer()
    local player = GetPlayer( data.playerId )
    player.isSpawned = true
    
    if not data.position then -- offline
        data.position = GetSpawnPosition( player )
    end
    
    local go = GameObject.New( CharacterPrefab )
    go.physics:WarpPosition( Vector3( data.position ) )

    go.s.playerId = data.playerId
    go.s.team = player.team
    player.characterGO = go
    
    if player.id == Client.player.id then
        -- give control of the character to the player
        player.characterGO.s:SetupPlayableCharacter()
    end
    
    print(player.name.." ("..player.id..") has spawned") -- should not cprint(), could be used for cheat
end
CS.Network.RegisterMessageHandler( Behavior.SpawnPlayer, CS.Network.MessageSide.Players )


-- Update character and objectives position, + other game states
-- Called by Server:Update()
-- game object referrenced in data that does not exists yet on this client are created.
function Behavior:UpdateGameState( data )
    if Client.player.isReady then
        if data.dataByPlayerId then
            local server = GetServer()
        
            for id, playerData in pairs( data.dataByPlayerId ) do
                local player = server.playersById[ id ]
                
                if player.characterGO ~= nil and player.characterGO.inner ~= nil then                   
                    if playerData.position then
                        player.characterGO.physics:WarpPosition( Vector3( playerData.position ) )
                        --player.characterGO.transform:SetPosition( Vector3( playerData.position ) )
                    end
                    
                    if playerData.eulerAngles then
                        player.characterGO.physics:WarpEulerAngles( Vector3( playerData.eulerAngles ) )
                        --player.characterGO.transform:SetEulerAngles( Vector3( playerData.eulerAngles ) ) -- SetEulerAngles() doen't work here, yet it does in "Character Control" script
                    end
                    
                    if playerData.messagesToSend then
                        for msgName, arguments in pairs( playerData.messagesToSend ) do
                            player.characterGO.s[msgName]( player.characterGO.s, unpack( arguments ) )
                        end
                    end
                else
                    self:SpawnPlayer( {
                        position = playerData.position,
                        playerId = id,
                    } )
                end
            end -- end for
        end -- end if dataByPlayerId
    end -- end if isReady
end
CS.Network.RegisterMessageHandler( Behavior.UpdateGameState, CS.Network.MessageSide.Players )
