 
Server = {
    interface = nil, -- this gameObject
    isRunning = false,
    
    defaultData = {
        ip = "127.0.0.1",
        id = -1,
        level = "", --scene path
        
        playersById = {},
        playerIds = {},
    },
    data = {
        maxPlayerCount = 12,
        name = "Server Name",
    }
}

function Server.Init()
    Server.isRunning = false
    Server.data = table.merge( Server.data, Server.defaultData )
end


function Server.UpdateServerBrowser( delete )
    local data = Server.data
    if delete then
        data.deleteFromServerBrowser = true -- only usefull when when == true
    end
    
    CS.Web.Post( ServerBrowserAddress, data, CS.Web.ResponseType.JSON, function( error, data )
        local action = "updated"
        if delete then
            action = "deleted"
        end
            
        if error ~= nil then
            cprint( "Error "..action.." server on server browser", error )
            return
        end

        if data ~= nil then
            if data.id ~= nil then
                Server.data.id = data.id
                Server.data.ip = data.ip
            end
            
            cprint("Successfully "..action.." server on the server browser", Server.data.id, Server.data.ip )
        else
            cprint("Successfully "..action.." server on the server browser but didn't received data confirmation" )
        end
    end )
    
end


function Server.Start()
    if Server.isRunning then
        cprint("Server.Start() : server is already running")
        return
    end
    
    cprint("Start server")
    Server.Init()
    CS.Network.Server.Start()
    Server.isRunning = true
    
    Server.UpdateServerBrowser()
end

function Server.Stop()
   cprint( "Stop Server" )
   Server.UpdateServerBrowser( true )
   
   CS.Network.Server.Stop()
   Server.Init()
end


local OriginalExit = CS.Exit

function CS.Exit()
    if Server.isRunning then
        Server.Stop()
    end
    OriginalExit()
end

----------------------------------------------------------------------


Client = {
    isConnected = false,
    ipToConnectTo = "127.0.0.1",
    ip = "1270.0.1",
    
    defaultData = {
        id = -1,
        playersById = {},
        playerIds = {},
        team = 1,
        isSpawned = false
    },
    data = {
        name = "Player",
    }
}

function Client.Init()
    Client.isConnected = false
    Client.data = table.merge( Client.data, Client.defaultData )
end

function GetIp( o )
    CS.Web.Get( "http://craftstud.io/ip", nil, CS.Web.ResponseType.Text, function( error, data )
        if error ~= nil then
            cprint( "Error getting IP", error )
            return
        end
        
        if data == nil then
            cprint("GetIP : no IP returned")
        else
            o.ip = data
            cprint("GetIp : ", data )
        end
    end )
end

GetIp( Client )


----------------------------------------------------------------------


function Behavior:Awake()
    Server.interface = self.gameObject
    self.gameObject.networkSync:Setup( 0 )

    
    -- Called when someone just arrived on the server, before the success callback of CS.NetWork.Connect() 
    -- (which is called even if the player is disconnected from there)
    CS.Network.Server.OnPlayerJoined( 
        function( player )
            cprint("Server.OnPlayerJoined", player.id)
            local data = {
                serverData = Server.data, -- only playersById is usefull
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
            
            --local player = Server.data.playersById[ playerId ]
            Server.data.playersById[ playerId ] = nil
            Server.data.playerIds = table.getkeys( Server.data.playersById )
            
            self.gameObject.networkSync:SendMessageToPlayers( "SetClientData", { playersById = Server.data.playersById }, Server.data.playerIds )
        end
    )
    
    
    -- Called when a player is disconnected by the server with CS.Network.Server.DisconnectPlayer() 
    -- or when the server stops
    -- or when the client wasn't able to connect
    -- NOT called by CS.Network.Disconnect()
    -- CS.Network.Server.OnPlayerLeft() is called next (but not when the server stops)
    CS.Network.OnDisconnected( 
        function()
            cprint("CS.Network.OnDisconnected", Client.data.id)
            --Client.Init()
            --Scene.Load( "Menus/Server Browser" )
        end
    )
end


function Behavior:SetPlayerData( data, playerId )
    local player = Server.data.playersById[ playerId ]
    if player ~= nil then
        player.activationTimer:Destroy()
        player.activationTimer = nil
        player = table.merge( player, data )
    end
    
    self.gameObject.networkSync:SendMessageToPlayers( "SetClientData", { playersById = Server.data.playersById }, Server.data.playerIds )
end
CS.Network.RegisterMessageHandler( Behavior.SetPlayerData, CS.Network.MessageSide.Server )



function Behavior:RegisterAsPlayer( data, playerId )
    if table.getlength( Server.data.playersById ) < Server.data.maxPlayerCount then
        player.isActive = false
        player.name = "Player #" .. player.id
        if data.name ~= nil then
            player.name = data.name
        end
        --[[player.activationTimer = Tween.Timer(1, function()
            self.gameObject.networkSync:SendMessageToPlayers( "OnDisconnected", { reason = "Not activated on time." }, { player.id } )
            CS.Network.Server.DisconnectPlayer( player.id )
        end]]
        
        Server.data.playersById[ player.id ] = player
        Server.data.playerIds = table.getkeys( Server.data.playersById )
        
        self.gameObject.networkSync:SendMessageToPlayers( "OnConnected", { playerId = player.id }, { player.id } )
    else
        self.gameObject.networkSync:SendMessageToPlayers( "OnDisconnected", { reason = "Server full" }, { player.id } )
        CS.Network.Server.DisconnectPlayer( player.id )
    end
end


--------------------------------------------------------------------------------
-- Client side


-- called by the client to connect to a server
function Behavior:ConnectClient( data )
    if data == nil then data = {} end

    Client.Init()
    if data.ip ~= nil then
        Client.ipToConnectTo = data.ip
    end
    
    cprint( "ConnectClient() : Connecting client to IP "..Client.ipToConnectTo )
    
    CS.Network.Connect( Client.ipToConnectTo, CS.Network.DefaultPort, function()
        
        self.gameObject.networkSync:SendMessageToServer( "RegisterAsPlayer" )
    end )
end


function Behavior:OnConnected( data )
    Client.isConnected = true
    cprint( "Client OnConnected" )
    
    if data.playerId ~= nil then
        Client.data.id = data.playerId
    end
end
CS.Network.RegisterMessageHandler( Behavior.OnConnected, CS.Network.MessageSide.Players )




-- called by the client to disconnect itself from a server
function Behavior:DisconnectClient()
    if Client.isConnected then
        CS.Network.Disconnect() -- will call CS.Network.Server.OnPlayerLeft()
    end
    cprint("DisconnectClient()")
    
    Client.Init()
    Scene.Load( "Menu/Server Browser" )
end

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
    Client.data = table.merge( Client.data, data )
    if data.playersById ~= nil then
        Client.data.playerIds = table.getkeys( Client.data.playersById )
    end
    cprint("Client SetClientData", Client.data.id)
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


