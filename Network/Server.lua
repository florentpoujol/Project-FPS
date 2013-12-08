

----------------------------------------------------------------------
-- SERVER SIDE

ServerGO = nil -- the game object this script is attached to

LocalServer = nil -- is set in Server.Start() with a server instance if the player creates a local server (unset in Server.Stop())

Server = {
    initialScene = "Levels/Test level", -- the scene to which the server admin is redirected when the server is created
    
    localData = {}, -- stores the data that is saved locally and that can be set by the server admin (name, maxPlayerCount)
    
    defaultData = {
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
    
    local inputData = table.copy( server, true ) -- recursive
    
    if delete then
        inputData = { id = server.id } -- remove all unnecessary data
        inputData.deleteFromServerBrowser = true -- only usefull when when == true
    end
    
    local serverBrowserAddress = server.serverBrowserAddress
    if serverBrowserAddress == nil then
        serverBrowserAddress = ServerBrowserAddress
    end
    
    CS.Web.Post( serverBrowserAddress, inputData, CS.Web.ResponseType.JSON, function( error, data )       
        if error ~= nil then
            if delete then
                cprint( "Error while deleting server from server browser : ", error.message )
            else
                cprint( "Error while updating server from server browser : ", error.message )
            end
            table.print( inputData )
            return
        end

        if data ~= nil then
            if data.deleteFromServerBrowser then
                --cprint("Successfully delete server with id "..data.id.." from the server browser.")
                server.serverBrowserAddress = nil
                server.id = -1
                -- leave ip as the server's IP didn't change
            elseif data.ip ~= nil then
                --cprint("Successfully created/updated server on the server browser : ", data.id, data.ip )
                server.serverBrowserAddress = serverBrowserAddress
                server.id = data.id
                server.ip = data.ip
            else
                --cprint("Server browser error : empty confirmation data, probably nothing happened.")
                table.print( server )
                table.print( inputData )
                table.print( data )
            end
        else -- shouldn't happens since the server browser always send at least an empty table
            cprint("Successfully did things on the server browser but didn't received data confirmation." )
        end
        
        if callback ~= nil then
            callback( server, data, error )
        end
    end )
    
end


-- start the local server
function Server.Start( callback )
    if LocalServer then
        msg( "Server.Start() : server is already running")
        return
    end

    msg( "Starting server" )
    CS.Network.Server.Start()

    local server = {}
    server.playersById = {}
    server.playerIds = {}
    server = table.merge( server, Server.localData )
    
    setmetatable( server, Server )
    
    if not server.isPrivate then
        server:UpdateServerBrowser( callback )   
    end
    
    LocalServer = server
    
    
end


-- stop the local server
function Server.Stop( callback )
    if LocalServer ~= nil and LocalServer then
        msg( "Stopping server" )
        CS.Network.Server.Stop()
        LocalServer.playersById = {}
        LocalServer.playerIds = {}
        if not LocalServer.isPrivate then
            LocalServer:UpdateServerBrowser( true, callback )
        else
            callback()
        end
        LocalServer = nil
    end
    
    Client.isHost = false
end


local OriginalExit = CS.Exit

function CS.Exit()   
    if LocalServer ~= nil and LocalServer then
        Server.Stop( function() OriginalExit() end )
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
            --cprint("Server.OnPlayerJoined", player.id)
            local data = {
                server = LocalServer,
                playerId = player.id,
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
            --cprint("Server.OnPlayerLeft", playerId)
            
            local player = LocalServer.playersById[ playerId ]
            -- player will be nil if the client hasn't registered as player
            -- which happens when the server browser connects to the server

            if player ~= nil then                
                local data = { 
                    playerId = playerId,
                    reason = player.reasonForDisconnection   
                }
                
                table.removevalue( LocalServer.playerIds, playerId )
                -- this will be done in OnPlayerLeft too but must be done here to prevent sending the message to the disconnected player
                -- which throw a "System.Collections.Generic.KeyNotFoundException"
                
                self.gameObject.networkSync:SendMessageToPlayers( "OnPlayerLeft", data, LocalServer.playerIds )
                self:OnPlayerLeft( data )
            end
        end
    )
    
    
    
    
    -- Called when a player is disconnected by the server with CS.Network.Server.DisconnectPlayer() 
    -- or when the server stops
    -- or when the client wasn't able to connect
    -- NOT called by CS.Network.Disconnect()
    -- CS.Network.Server.OnPlayerLeft() is called next (but not when the server stops)
    CS.Network.OnDisconnected( function()
        self:OnDisconnected()
    end )
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
-- data mostly hold the client's name, sent to the client by OnPlayerJoined() via OnConnected()
function Behavior:RegisterPlayer( data, playerId )
    if table.getlength( LocalServer.playersById ) < LocalServer.maxPlayerCount then
        
        local player = table.copy( Client.defaultData )
        player.id = playerId
        player.name = data.name
        
        if player.name == nil or player.name == "" then
            player.name = "Player #" .. player.id
        end
        
        -- choose a team
        local teamCount = { 0, 0 }
        for id, player in pairs( LocalServer.playersById ) do
            teamCount[ player.team ] = teamCount[ player.team ] + 1
        end
        if teamCount[1] > teamCount[2] then
            player.team = 2
        end
        
        -- the connected player already has the playersById table via "OnConnected"
        LocalServer.playersById[ player.id ] = player
        LocalServer.playerIds = table.getkeys( LocalServer.playersById )
        
        self.gameObject.networkSync:SendMessageToPlayers( "OnPlayerJoined", player, LocalServer.playerIds )
        self:OnPlayerJoined( player )
    else
        LocalServer:DisconnectPlayer( playerId, "Server full" )
    end
end
CS.Network.RegisterMessageHandler( Behavior.RegisterPlayer, CS.Network.MessageSide.Server )



function Server.DisconnectPlayer( server, id, reason, tellOthers )
    ServerGO.networkSync:SendMessageToPlayers( "OnDisconnected", { reason = reason }, { id } )
    
    LocalServer.playersById[ id ].reasonForDisconnection = reason
    -- player will be removed from playersById in self:OnPlayerLeft
    
    CS.Network.Server.DisconnectPlayer( id )
end

--------------------------------------------------------------------------------
-- CLIENT SIDE


Client = {
    isConnected = false,
    isHost = false,
    ip = "1270.0.1",
    server = nil, -- The server the Client is connected to. Server instance. Set in OnConnected(), unset in Client.Init()
    
    defaultData = {
        id = -1,
        team = 1,
        kills = 0,
        death = 0,
        isSpawned = false,
    },
    
    data = {
        name = "Player", -- set in the main menu
    },
}


function Client.Init()
    Client.isConnected = false
    Client.isHost = false
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
            local ips = ip:split( ',' )
            Client.ip = ips[2] or ips[1]
            Client.ip = Client.ip:trim()
            cprint("GetIP : ", ip, Client.ip )
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

    server:Connect( callback )
end


function Client.ConnectAsPlayer( ipOrServer, callback )
    local server = ipOrServer
    if type( ipOrServer ) == "string" then
        server = Server.New()
        server.ip = ipOrServer
    end
       
    server:Connect( function()
        ServerGO.networkSync:SendMessageToServer( "RegisterPlayer", { name = Client.data.name } )
        if callback ~= nil then
            callback()
        end
    end )
end


function Client.Disconnect()
    if Client.isConnected then
        CS.Network.Disconnect()
    end
    Client.Init()
end


-- Called by OnPlayerJoined() on the server
-- data holds the server data as well as the playerId
function Behavior:OnConnected( data )
    Client.isConnected = true
    Client.server = Server.New( data.server )
    Client.data.id = data.playerId
    --cprint( "Client OnConnected", data.playerId, Client.server )
end
CS.Network.RegisterMessageHandler( Behavior.OnConnected, CS.Network.MessageSide.Players )



-- called by the server just before the player is disconnectd mainly to notify the client of the reason for the disconnection
-- OR called by CS.Network.OnDisconnected()
function Behavior:OnDisconnected( data )
    if data ~= nil and data.reason ~= nil then
        cprint( "Client OnDisconnected()", data.reason )
        Game.disconnectionReason = data.reason
        
        -- OnDisconnected is called from the server to notify of the reason for disconnection
        -- The player will then be disconnected via CS.Network.Server.DisconnectPlayer()
        -- which calls CS.Network.OnDisconnected() which calls OnDisconnected() one more time but without data
    else
        Client.Init()
        Scene.Load( "Menus/Server Browser" )
        
        -- should find a better message system that stores one or several msg and displays them to the player and console them whenever possible
    end
end
CS.Network.RegisterMessageHandler( Behavior.OnDisconnected, CS.Network.MessageSide.Players )


-- Called from ActivatePlayer() on the server when this new player is connected
-- called on a single player
function Behavior:SetClientData( data )
    --cprint("Client SetClientData", Client.data.id)
    
    Client = table.deepmerge( Client, data )
    
    if table.getvalue( data, "server.playersById" ) ~= nil then
        Client.server.playerIds = table.getkeys( Client.server.playersById )
    end
end
CS.Network.RegisterMessageHandler( Behavior.SetClientData, CS.Network.MessageSide.Players )



-- called from RegisterPlayer()
function Behavior:OnPlayerJoined( player )
    --cprint(Client.data.id, "OnPlayerJoined", player.id )
    
    local server = Client.server or LocalServer
    server.playersById[ player.id ] = player
    server.playerIds = table.getkeys( server.playersById )
    
    if player.id ~= Client.data.id then
        Tchat.AddLine( "Player #"..player.id.." '"..player.name.."' joined." )
    else
        Client.data = table.merge( player )
        Tchat.AddLine( "You are now connected as player with id #"..player.id.." and name '"..player.name.."." )
    end    
    
    -- create character

end
CS.Network.RegisterMessageHandler( Behavior.OnPlayerJoined, CS.Network.MessageSide.Players )



-- called from CS.Network.Server.OnPlayerLeft()
-- only receive the playerId + reason for disconnection (maybe)
function Behavior:OnPlayerLeft( data )
    --cprint(Client.data.id, "OnPlayerDisconnected", data.playerId )
    
    local server = Client.server or LocalServer
    local player = server.playersById[ data.playerId ]
    
    if data.reason == nil then
        data.reason = "Disconnected"
    end
    
    local text = "Player '"..player.name.."' has left for reason : "..data.reason
    Tchat.AddLine( text )
    
    -- remove character
    -- player.characterGO:Destroy()
    -- /!\ if the player wears an important item (flag, bomb)
    
    server.playersById[ data.playerId ] = nil
    server.playerIds = table.getkeys( server.playersById )
end
CS.Network.RegisterMessageHandler( Behavior.OnPlayerLeft, CS.Network.MessageSide.Players )






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


