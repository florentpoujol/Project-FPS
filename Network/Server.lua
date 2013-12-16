
ServerGO = nil -- the game object this script is attached to

LocalServer = nil -- is set in Server.Start() with a server instance if the player creates a local server (unset in Server.Stop())

Server = {
    localData = { -- stores the data that is saved locally and that can be set by the server admin
        name = "Default server name",
        maxPlayerCount = 10,
        isPrivate = false,
        initialScene = "Levels/Test Level" -- the scene to which the server admin is redirected when the server is created
    }, 
    
    defaultData = {
        serverBrowserAddress = nil, -- is set to the server browser address when server exist on it
        
        ip = "127.0.0.1",
        id = -1, -- the id of a server is given by the server browser
        scenePath = "", -- set in Client:LoadLevel
        gametype = "dm",
        
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
    
    local inputData = {
        id = server.id,
        ip = server.ip,
        name = server.name, -- storing the name on server browser isn't needed but do it anyway for debugging purpose
    }
    
    if delete then
        inputData.deleteFromServerBrowser = true -- only usefull when when == true
    end
    
    local serverBrowserAddress = server.serverBrowserAddress
    if serverBrowserAddress == nil then
        serverBrowserAddress = ServerBrowserAddress
    end
    
    CS.Web.Post( serverBrowserAddress, inputData, CS.Web.ResponseType.JSON, function( error, data )       
        if error ~= nil then
            cprint( "ERROR : can't contact server browser : ", serverBrowserAddress, error.message )
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
    
    --
    server.scenePath = server.initialScene
    Scene.Load( server.initialScene )
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
end


-- Connect the client to the provided server
function Server.Connect( server, callback )   
    Client.Init()
    
    if server.ip ~= nil then
        cprint("Server.Connect() : Connecting to : ", server )
        
        CS.Network.Connect( server.ip, CS.Network.DefaultPort, function()
            Client.server = server
            
            if callback ~= nil then
                callback()
            end
        end )
    else
        cprint("Server.Connect() : Can't connect because server's ip is nil : ", server )
    end
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
    self.gameObject.server = self
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
                -- this will be done in Client:OnPlayerLeft() too but must be done here to prevent sending the message to the disconnected player
                -- which throw a "System.Collections.Generic.KeyNotFoundException"
                
                self.gameObject.networkSync:SendMessageToPlayers( "OnPlayerLeft", data, LocalServer.playerIds )
                self.gameObject.client:OnPlayerLeft( data )
                --could also write self.gameObject:SendMessage( "OnPlayerLeft", data )
            end
        end
    )
    
    self.frameCount = 0
end


function Behavior:Update()
    if LocalServer == nil or #LocalServer.playerIds <  1 then
        return
    end
    
    self.frameCount = self.frameCount + 1
    
    if self.frameCount % 2 == 0 then
        local data = {}
        data.positionsByPlayerId = {}
        -- get characters position
        for id, player in pairs( LocalServer.playersById ) do 
            if player.characterGO ~= nil then
                data.positionsByPlayerId[ id ] = player.characterGO.transform.position
            end
        end
        
        -- others stuffs :
        -- position of objecive (flag, cart) ?
        -- state of objectives (height of flag, flag team)
        -- time until round ends
        
        self.gameObject.networkSync:SendMessageToPlayers( "UpdateGameState", data, LocalServer.playerIds )
    end
end


-- Called from the success callback sent to Server.Connect() from Client.ConnectAsPlayer().
-- Data only holds the client's name
function Behavior:RegisterPlayer( data, playerId )
    if table.getlength( LocalServer.playersById ) < LocalServer.maxPlayerCount then
        
        local player = table.copy( Player )
        player.id = playerId
        player.name = data.name
        
        if player.name == nil or player.name:trim() == "" then
            player.name = "John Doe " .. player.id
        end
        
        -- choose a team
        player.team = 1
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
        self.gameObject.client:OnPlayerJoined( player )
        
        local data = {
            scenePath = LocalServer.scenePath,
            gametype = LocalServer.gametype
        }
        
        self.gameObject.networkSync:SendMessageToPlayers( "LoadLevel", data, { player.id } ) 
        
    else
        self:DisconnectPlayer( playerId, "Server full" )
    end
end
CS.Network.RegisterMessageHandler( Behavior.RegisterPlayer, CS.Network.MessageSide.Server )


-- Disconnect the specified player from the server  and inform him of the reason
-- All other players are notified of the reason via CS.Network.Server.OnPlayerLeft()
function Behavior:DisconnectPlayer( id, reason )
    ServerGO.networkSync:SendMessageToPlayers( "OnDisconnected", { reason = reason }, { id } )
    
    LocalServer.playersById[ id ].reasonForDisconnection = reason
    
    CS.Network.Server.DisconnectPlayer( id )
end


-- Called from the client's Character script or menus
-- Data contains the player input
function Behavior:SetCharacterInput( data, playerId )
    if data.input.spawnButtonClicked then
        --cprint( "Player #"..playerId.." wants to spawn !" )
        
        local player = LocalServer.playersById[ playerId ]
        if not player.isSpawned and not player.characterGO then
            local data = {
                position = GetSpawnPosition( player ),
                playerId = player.id    
            }
            
            self.gameObject.networkSync:SendMessageToPlayers( "PlayerSpawned", data, LocalServer.playerIds ) -- why not leave player data be broadcasted via Client:UpdateGameState() and let this function creates the game objects ?
            self.gameObject.client:PlayerSpawned( data )
        end
    else
        LocalServer.playersById[ playerId ].input = data.input
    end
end
CS.Network.RegisterMessageHandler( Behavior.SetCharacterInput, CS.Network.MessageSide.Server )


-- Called from Start() in the common level manager (when a client has fully loaded a level)
-- Mark player as ready to receive game statut update via UpdateGameState()
function Behavior:MarkPlayerReady( data, playerId )
    LocalServer.playersById[ playerId ].isReady = true
end
CS.Network.RegisterMessageHandler( Behavior.MarkPlayerReady, CS.Network.MessageSide.Server )

