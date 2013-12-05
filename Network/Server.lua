
ServerGO = nil -- the game object this script is attached to

LocalServer = nil -- is set with a server instance if the player creates a local server

Server = {
    defaultData = {
        isRunning = false,
        serverBrowserAddress = nil, -- is set to the server browser address when server exist on it
        
        ip = "127.0.0.1",
        id = -1, -- the id of a server is given by the server browser
        level = "", --scene path
        
        playersById = {},
        playerIds = {},
        
        maxPlayerCount = 12,
        name = "Default Server Name",
    }
}
Server.__index = Server
Server.__tostring = function( server )
    return "Server: "..tostring(server.id)..": "..tostring(server.name)..": "..tostring(server.ip)
end


function Server.New( params )
    local server = table.copy( Server.defaultData )
    
    if type( params ) == "table" then
        server = table.merge( server, params )
    end

    server.playersById = {}
    server.playerIds = {}
    return setmetatable( server, Server )
end


function Server.UpdateServerBrowser( server, delete, callback )
    local argType = type( delete )
    if argType == "function" or argType == "userdata" then
        callback = delete
        delete = false
    end
    
    local data = table.copy( server, true ) -- recursive
    
    if delete then
        data = { id = data.id } -- remove all unnecessary data
        data.deleteFromServerBrowser = true -- only usefull when when == true
    end
    
    local serverBrowserAddress = server.serverBrowserAddress
    if serverBrowserAddress == nil then
        serverBrowserAddress = ServerBrowserAddress
    end
    
    CS.Web.Post( serverBrowserAddress, data, CS.Web.ResponseType.JSON, function( error, data )
        local action = "updated"
        if delete then
            action = "deleted"
        end
        
        if error ~= nil then
            if delete then
                cprint( "Error while deleting server from server browser : ", error )
            else
                cprint( "Error while updating server from server browser : ", error )
            end
            return
        end

        if data ~= nil then
            if data.deleteFromServerBrowser then
                cprint("Successfully delete server with id "..data.id.." from the server browser.")
                server.serverBrowserAddress = nil
                server.id = -1
                -- leave ip as the server's IP didn't change
            elseif data.ip ~= nil then
                cprint("Successfully created/updated server on the server browser : ", data.id, data.ip )
                server.serverBrowserAddress = serverBrowserAddress
                server.id = data.id
                server.ip = data.ip
            else
                cprint("Server browser Wut ?")
                table.print( data )
            end
        else
            cprint("Successfully did things on the server browser but didn't received data confirmation." )
        end
        
        if callback ~= nil then
            callback()
        end
    end )
    
end


-- start the local server
function Server.Start()
    if LocalServer ~= nil and LocalServer.isRunning then
        cprint("Server.Start() : server is already running")
        return
    end

    cprint("Start server")
    CS.Network.Server.Start()

    local server = Server.New()
    server.isRunning = true
    server.playersById = {}
    server.playerIds = {}

    server.name = Daneel.Storage.Load( "Server Name", Server.defaultData.name )    
    server.maxPlayerCount = Daneel.Storage.Load( "Server Max Players", Server.defaultData.maxPlayerCount )
    
    
    server:UpdateServerBrowser()   
    LocalServer = server
end


-- stop the local server
function Server.Stop( callback )
    if LocalServer ~= nil and LocalServer.isRunning then
        cprint( "Stop Server" )
        CS.Network.Server.Stop()
        LocalServer.isRunning = false
        LocalServer.playersById = {}
        LocalServer.playerIds = {}
        LocalServer:UpdateServerBrowser( true, callback )
        LocalServer = nil
    end
end


local OriginalExit = CS.Exit

function CS.Exit()   
    if LocalServer ~= nil and LocalServer.isRunning then
        Server.Stop( OriginalExit )
        -- what we want here is really to remove the server from the server browser
    else
        OriginalExit()
    end
end


----------------------------------------------------------------------


function Behavior:Awake()
    ServerGO = self.gameObject
    self.gameObject.networkSync:Setup( 0 )

    
    -- Called when someone just arrived on the server, before the success callback of CS.NetWork.Connect() 
    -- (which is called even if the player is disconnected from there)
    CS.Network.Server.OnPlayerJoined( 
        function( player )
            cprint("Server.OnPlayerJoined", player.id)
            local data = {
                serverData = LocalServer,
                playerId = player.id
            }
            self.gameObject.networkSync:SendMessageToPlayers( "OnConnected", data, { player.id } )
        end
    )
    
    
    -- Called when a player left the server 
    -- because it disconnect itself via CS.Network.Disconnect()
    -- or it is disconnected via CS.Network.Server.DisconnectPlayer()
    -- or its game has shut down
    -- NOT called when the server stops
    CS.Network.Server.OnPlayerLeft( 
        function( playerId )
            cprint("Server.OnPlayerLeft", playerId)
            
            -- self.gameObject.networkSync:SendMessageToPlayers( "OnDisconnected", { reason = "Unknow" }, { playerId } )
            
            --local player = LocalServer.playersById[ playerId ]
            LocalServer.playersById[ playerId ] = nil
            LocalServer.playerIds = table.getkeys( LocalServer.playersById )
            
            self.gameObject.networkSync:SendMessageToPlayers( "SetClientData", { playersById = LocalServer.playersById }, LocalServer.playerIds )
        end
    )
end

--[[
-- called by a client, mostly to set its player name
function Behavior:SetPlayerData( data, playerId )
    local player = LocalServer.playersById[ playerId ]
    if player ~= nil then
        player = table.merge( player, data )
    end
    
    self.gameObject.networkSync:SendMessageToPlayers( "SetClientData", { playersById = LocalServer.playersById }, LocalServer.playerIds )
end
CS.Network.RegisterMessageHandler( Behavior.SetPlayerData, CS.Network.MessageSide.Server )
]]


-- called from ConnectClient(), by a client
-- data mostly hold the client's id, sent to the client by OnPlayerJoined() via OnConnected()
function Behavior:RegisterAsPlayer( data, playerId )
    if table.getlength( LocalServer.playersById ) < LocalServer.maxPlayerCount then
        
        
        player.isActive = false
        player.name = "Player #" .. player.id
        if data.name ~= nil then
            player.name = data.name
        end
        --[[player.activationTimer = Tween.Timer(1, function()
            self.gameObject.networkSync:SendMessageToPlayers( "OnDisconnected", { reason = "Not activated on time." }, { player.id } )
            CS.Network.Server.DisconnectPlayer( player.id )
        end]]
        
        LocalServer.playersById[ player.id ] = player
        LocalServer.playerIds = table.getkeys( LocalServer.playersById )
        
        self.gameObject.networkSync:SendMessageToPlayers( "OnConnected", { playerId = player.id }, { player.id } )
    else
        self.gameObject.networkSync:SendMessageToPlayers( "OnDisconnected", { reason = "Server full" }, { playerId } )
        CS.Network.Server.DisconnectPlayer( player.id )
    end
end


--------------------------------------------------------------------------------
-- Client side

Client = {
    isConnected = false,
    ipToConnectTo = "127.0.0.1",
    ip = "1270.0.1",
    server = nil, -- The server the Client is connected to. Server instance. Set in OnConnected(), unset in Client.Init()
    
    defaultData = {
        id = -1,
        playersById = {},
        playerIds = {},
        team = 1,
        isSpawned = false
    },
    data = { -- player data exchanged with the server
        name = "Player",
    }
}

function Client.Init()
    Client.isConnected = false
    Client.server = nil
    Client.data = table.merge( Client.data, Client.defaultData )
end


-- Cet Client's IP
function Client.GetIp( callback )
    CS.Web.Get( "http://craftstud.io/ip", nil, CS.Web.ResponseType.Text, function( error, ip )
        if error ~= nil then
            cprint( "Error getting IP", error )
            return
        end
        
        if ip == nil then
            cprint("GetIP : no IP returned")
        else
            Client.ip = ip
            cprint("GetIP : ", ip )
        end
    end )
end
Client.GetIp()


-- connect the client to the provided server
function Server.Connect( server, callback )
    if callback == nil then
        callback = function() end
    end
    Client.Init()
    if server.ip ~= nil then
        cprint("Server.Connect() : Connecting to : ", server )
        
        CS.Network.Connect( server.ip, CS.Network.DefaultPort, function()
            Client.server = server
            callback()
        end )
    else
        cprint("Server.Connect() : Can't connect because server's ip is nil : ", server )
    end
end


-- connect the client to the provided ip
function Client.ConnectToIp( ip, callback )
    if type( ip ) == "function" then
        callback = ip
        ip = nil
    end

    local server = Server.New()
    server.ip = ip
    if server.ip == nil then
        server.ip = Client.ipToConnectTo
    end
    server:Connect( callback )
end


function Client.ConnectAsPlayer( ipOrServer, callback )
    local server = ipOrServer
    if type( ipOrServer ) == "string" then
        server = Server.New()
        server.ip = ipOrServer
    end
    
    server:Connect( function()
        self.gameObject.networkSync:SendMessageToServer( "RegisterAsPlayer", { name = Client.data.name } )
    end )
end

-- called by the client to connect to a server
--[[
function Behavior:ConnectClient( data )
    if data == nil then data = {} end

    Client.Init()
    if data.ip ~= nil then
        Client.ipToConnectTo = data.ip
    end
    
    cprint( "ConnectClient() : Connecting client to IP "..Client.ipToConnectTo )
    
    CS.Network.Connect( Client.ipToConnectTo, CS.Network.DefaultPort, function()
        
    end )
end
]]

-- Called by OnPlayerJoined() on the server
-- data holds the server data as well as the playerId
function Behavior:OnConnected( data )
    cprint( "Client OnConnected" )
    Client.isConnected = true
    Client.server = Server.New( data.serverData )
    Client.data.id = data.playerId
end
CS.Network.RegisterMessageHandler( Behavior.OnConnected, CS.Network.MessageSide.Players )





-- called by the client to disconnect itself from a server
function Behavior:DisconnectClient()
    if Client.isConnected then
        CS.Network.Disconnect() -- will call CS.Network.Server.OnPlayerLeft() but not CS.Network.OnDisconnected()
    end
    cprint("DisconnectClient()")
    
    Client.Init()
    Scene.Load( "Menu/Server Browser" )
end


-- Called when a player is disconnected by the server with CS.Network.Server.DisconnectPlayer() 
-- or when the server stops
-- or when the client wasn't able to connect
-- NOT called by CS.Network.Disconnect()
-- CS.Network.Server.OnPlayerLeft() is called next (but not when the server stops)
CS.Network.OnDisconnected( 
    function()
        cprint("CS.Network.OnDisconnected", Client.data.id)
        Client.Init()
        --Scene.Load( "Menus/Server Browser" )
    end
)


-- called by the server just before the player is disconnectd
-- mainly to notify the client of the reson for the disconnection
function Behavior:OnDisconnected( data )
    Client.Init()
    cprint( "Client OnDisconnected()", data.reason )
end
CS.Network.RegisterMessageHandler( Behavior.OnDisconnected, CS.Network.MessageSide.Players )



-- Called from ActivatePlayer() on the server when this new player is connected
-- called on a single player
function Behavior:SetClientData( data )
    cprint("Client SetClientData", Client.data.id)
    
    Client.data = table.merge( Client.data, data )
    if data.playersById ~= nil then
        Client.data.playerIds = table.getkeys( Client.data.playersById )
    end  
end
CS.Network.RegisterMessageHandler( Behavior.SetClientData, CS.Network.MessageSide.Players )


-- Called from ActivatePlayer() on the server when a new player is connected and activated
--[[function Behavior:OnPlayerActivated( data )
    cprint(Client.data.id, "OnPlayerActivated", data.player.id )
    Client.data.playersById[ data.player.id ] = data.player
end
CS.Network.RegisterMessageHandler( Behavior.OnPlayerActivated, CS.Network.MessageSide.Players )
]]

-- called from CS.Network.Server.OnPlayerLeft()
--[[function Behavior:OnPlayerDisconnected( data )
    cprint(Client.data.id, "OnPlayerDisconnected", data.playerId )
    
    --Client.data.playersById[ data.playerId ] = nil
end
CS.Network.RegisterMessageHandler( Behavior.OnPlayerDisconnected, CS.Network.MessageSide.Players )
]]





-----------------------------------------------
-- Remote Call
-- self.gameObject.networkSync:RemoteCall( "GlobalFunctionNameToCallOnTheServer", function( dataFromTheServer ) --[[do stuff on server]] end

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


