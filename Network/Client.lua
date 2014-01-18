

Player = {
    id = -1, -- given by the server
    team = 1, -- chosen by the server/player
    kills = 0,
    deaths = 0,
    isReady = false, -- has completely loaded the current level. Set to true in Start() in the common level manager, set to false in LoadLevel() below.
    isSpawned = false,
    name = "Player", -- set in the Main Menu/ loaded from save
    
    messagesToSend = {},
}



Client = {
    isConnected = false,
    ip = "1270.0.1",
    
    server = nil, -- The server the Client is connected to. Server instance. Set in OnConnected(), unset in Client.Init()
    player = nil, -- A copy of the Player object. Set in Client:OnConnected(), unset in Client.Init()
}


function Client.Init()
    Client.isConnected = false
    --Client.server = Server.New() -- Client.server is nil on the server (when LocalServer is not nil)
    Client.server = nil -- Client.server is nil on the server (when LocalServer is not nil)    
    Client.player = table.copy( Player, true )
    -- no need to load the player name from storage here since it is set in Player.name
end
-- called a first time in Awake() below


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
            local ips = ip:split( ',' )
            Client.ip = ips[2] or ips[1]
            Client.ip = Client.ip:trim()
            cprint("GetIP : ", ip, Client.ip )
        end
    end )
end
Client.GetIp()



-- connect the client to the provided ip
function Client.ConnectToIp( ip, callback )
    if type( ip ) == "function" then
        callback = ip
        ip = nil
    end

    local server = Server.New()
    server.ip = ip

    server:Connect( callback )
end


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
    
    if Client.server == nil and Client.player == nil then
        Client.Init()
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
    
    local server = Client.server or LocalServer
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
            true -- persistent listener, won't be wiped when the scene changes
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
function Behavior:OnPlayerLeft( data )
    local server = Client.server or LocalServer
    local player = server.playersById[ data.playerId ]
    player.hasLeft = true
    
    if data.reason == nil then
        data.reason = "Disconnected"
    end
    
    local text = "Player '"..player.name.."' has left for reason : "..data.reason
    Tchat.AddLine( text )
    --table.print( player )
    if player.characterGO ~= nil then
        --cprint("destroying character", player.name, player.id)
        player.characterGO:Destroy() -- remove character
        
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
    local server = Client.server or LocalServer
    
    if server then
        for id, player in pairs( server.playersById ) do
            player.isReady = false -- set to true in Server:MarkPlayerReady()
            player.kills = 0
            player.deaths = 0
        end
    else
        Client.player.isReady = false -- set to true in "Common Level Manager:Start()"
    end
    
    if data.gametype ~= nil then
        server.gametype = data.gametype
        Game.gametype = data.gametype
    end
    if data.scenePath ~= nil then
        server.scenePath = data.scenePath
    end
    
    Scene.Load( server.scenePath )
end
CS.Network.RegisterMessageHandler( Behavior.LoadLevel, CS.Network.MessageSide.Players )


-- Called from Server:SetPlayerInput() on each client and the server,
-- or called from Client:UpdateGameState(),
-- or from the HUD (without data),
--
-- Data argument contains the position and playerId
function Behavior:SpawnPlayer( data )
    local server = LocalServer or Client.server
    
    local player = Client.player -- offline
    if server ~= nil then
        player = server.playersById[ data.playerId ]
    end
    
    player.isSpawned = true
    
    if data == nil then -- offline
        data = {
            position = GetSpawnPosition( player ),
            playerId = -1    
        }
    end
    
    local go = GameObject.New( CharacterPrefab )
    go.physics:WarpPosition( Vector3( data.position ) )

    go.s.playerId = data.playerId
    go.s.team = player.team
    player.characterGO = go
    
    if LocalServer == nil and player.id == Client.player.id then
        -- give control of the character to the player
        player.characterGO.s:SetupPlayableCharacter()
    end
    
    cprint(player.name.." ("..player.id..") has spawned")
end
CS.Network.RegisterMessageHandler( Behavior.SpawnPlayer, CS.Network.MessageSide.Players )

local lastDataId = -1
-- Update character and objectives position, + other game states
-- Called by Server:Update()
-- game object referrenced in data that does not exists yet on this client are created.
function Behavior:UpdateGameState( data )
    --[[
    if data.id ~= nil and data.id <= lastDataId then
        return
    end
    lastDataId = data.id or lastDataId
    ]]
    
    if Client.player.isReady then
        local server = Client.server or LocaServer
            
        if data.dataByPlayerId then
            for id, playerData in pairs( data.dataByPlayerId ) do
                local player = server.playersById[ id ]
                
                if player.characterGO ~= nil and player.characterGO.transform ~= nil  then                   
                    if playerData.position then
                        player.characterGO.physics:WarpPosition( Vector3( playerData.position ) )
                        --player.characterGO.transform:SetPosition( Vector3( playerData.position ) )
                    end
                    
                    if playerData.eulerAngles then
                        player.characterGO.physics:WarpEulerAngles( Vector3( playerData.eulerAngles ) )
                        --player.characterGO.transform:SetEulerAngles( Vector3( playerData.eulerAngles ) ) -- SetEulerAngles() doen't work here, yet it does in "Character Control"
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
            end
        end
    end
end
CS.Network.RegisterMessageHandler( Behavior.UpdateGameState, CS.Network.MessageSide.Players )







-----------------------------------------------
-- Remote Call
-- self.gameObject.networkSync:RemoteCall( "GlobalFunctionNameToCallOnTheServer", function( dataFromTheServer )  end )

NetworkSync.RemoteCall = {
    id = 0,
    callbacksById = {}
} 


-- @param networkSync (NetworkSync)
-- @param functionName (string) The name of the global function (may be nested in tables) to call on the server.
-- @param callback (function) [optional] The function called with the data from the server
function NetworkSync.RemoteCall( networkSync, functionName, remoteCallback )
    cprint("NetworkSync.RemoteCall", functionName )
    local id = NetworkSync.RemoteCall.id
    NetworkSync.RemoteCall.id = id + 1
    NetworkSync.RemoteCall.callbacksById[ id ] = remoteCallback
    networkSync:SendMessageToServer( "RemoteCallServer", { functionName = functionName, callbackId = id } )
end


function Behavior:RemoteCallServer( data, playerId )
    cprint("RemoteCallServer()")
    local f = table.getvalue( _G, data.functionName )
    local newData = f()
    
    if newData == nil then
        newData = {}
    end
    if type( newData ) ~= "table" then
        newData = { singleValue = newData }
    end
    newData.callbackId = data.callbackId
    
    self.gameObject.networkSync:SendMessageToPlayers( "RemoteCallClient", newData, { playerId } )
end
CS.Network.RegisterMessageHandler( Behavior.RemoteCallServer, CS.Network.MessageSide.Server )


function Behavior:RemoteCallClient( data )
    cprint("Behavior:RemoteCallClient()")
    
    local id = data.callbackId
    data.callbackId = nil
    if id ~= nil then
        local f = NetworkSync.RemoteCall.callbacksById[ id ]
        if f ~= nil then
            if data.singleValue ~= nil then
                data = data.singleValue
            end
            f( data )
        end
    end
end
CS.Network.RegisterMessageHandler( Behavior.RemoteCallClient, CS.Network.MessageSide.Players )

