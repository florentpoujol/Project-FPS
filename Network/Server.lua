
ServerGO = nil -- the game object this script is attached to

LocalServer = nil -- is set in Server.Start() with a server instance if the player creates a local server (unset in Server.Stop(), but immediately reset in Client.Init())
-- OR this is the offline server instance (set in Client.Init())
-- Is nil in connected client (unset in Client:OnConnected())

-- Server data is read from a .json file acceessible via internet and the CS.Web API
-- For now, we will just use the ServerConfig table found in the "Game Config" script instead


--ServerBrowserAddress = "http://localhost/CSServerBrowser/index.php"
ServerBrowserAddress = "http://csserverbrowser.florentpoujol.fr/index.php"

ServerConfigFilePath = "" -- set in Main menu

Server = {
    defaultProperties = {
        isOnline = false,
        
        serverBrowserAddress = nil, -- is set to the server browser address when server exist on it
        ip = "127.0.0.1",
        id = -1, -- the id of a server is given by the server browser
        
        playersById = {},
        playerIds = {},
    
        -- config set by the player
        maxPlayerCount = 12,
        name = "Default Server Name",
        iPrivate = false,
    
        game = {
            -- global game settings (will be applied for all levels/gametypes)
            
            scenePath = "Levels/Test Level", -- set in Client:LoadLevel
            gametype = "ctf",
            friendlyFire = false,
            
            roundTime = 600, -- set in Client:LoadLevel()
            
            -- gametype specific settings
            --[[
            generic gametype settings :
            {
                timeLimit = 600, -- in seconds
                scoreLimit = nil,
                killScore = 10,
                deathScore = -5,
                suicideScore = 0,
            }
            ]]
            
            dm = {
                timeLimit = 600, -- seconds
            },
            
            tdm = {
                timeLimit = 600, -- seconds
            },
            
            ctf = {
                timeLimit = 600,
                captureLimit = 5,
                
                killScore = 10,
                deathScore = -5,
                
                flagCaptureScore = 20,
                flagPickupScore = 5,
                flagReturnHomeScore = 5
            },
            
            
            character = {
                rotationSpeed = 0.1,
                walkSpeed = 18,
                jumpSpeed = 600, --200 = about one cube hight
                health = 3,
                
                weaponDamage = 1, -- same unit as health
                shootRate = 5, -- shoots per second
            }
        }, -- end of game table
    }
}

Server.__index = Server
Server.__tostring = function( server )
    return "Server: "..tostring(server.id)..": "..tostring(server.name)..": "..tostring(server.ip)
end

-- creates a new server instance (do not start the server)
function Server.New( params )
    local server = table.copy( Server.defaultProperties, true )
    
    if type( params ) == "table" then
        table.mergein( server, params, true )
    end

    return setmetatable( server, Server )
end


-- Add, update or delete the provided server to/from the server browser
-- @param server (Server) The server instance.
-- @param delete (boolean) [optional] Tell whether to delete the server from the server browser (or add/update it).
-- @param callback (function or userdata) [optional] The callback function when the operation has been successfull.
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
        serverBrowserAddress = ServerBrowserAddress -- set above
    end
    
    CS.Web.Post( serverBrowserAddress, inputData, CS.Web.ResponseType.JSON, function( error, data ) 
        if error ~= nil then
            cprint( "ERROR : can't contact server browser : ", serverBrowserAddress, error.message )
            --table.print( inputData )
            return
        end
        
        -- data is the inputData, updated with the server id and ip
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
                cprint("Server browser error : empty confirmation data, probably nothing happened.")
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


-- Load the server's remote .json config file
-- Pass the resulting Lua table as first argument of the call back.
-- used in Server.Start()
function Server.LoadConfigFile( successCallback, errorCallback )
    CS.Web.Get( ServerConfigFilePath, nil, CS.Web.ResponseType.JSON, function( error, serverConfig )
        if error then
            Alert.SetText("Server config file path couldn't be read with error :", error.message )
            if errorCallback ~= nil then
                errorCallback()
            end
        end
        
        if successCallback ~= nil then
            successCallback( serverConfig )
        end
    end )
end


-- Start the local server.
-- Called from MainMenu manager
function Server.Start( serverBrowserCallback )
    if IsServer(true) then
        cprint( "Server.Start() : server is already running")
        return
    end
    
    local startServer = function( config )
        if config == nil then
            Alert.SetText( "Sarting server with default config." )
            config = ServerConfig -- placeholder
        end
        
        CS.Network.Server.Start()
                
        local server = Server.New( config )
        server.isOnline = true
        if not server.isPrivate then
            server:UpdateServerBrowser( serverBrowserCallback )   
        end
        
        LocalServer = server
        Scene.Load( server.game.scenePath )
    end
    
    -- try to get the server config path
    if ServerConfigFilePath:startswith( "http://" ) or ServerConfigFilePath:startswith( "https://" ) then
        Server.LoadConfigFile( 
            function( config )
                Alert.SetText( "Sarting server with config at URL : "..ServerConfigFilePath )
                startServer( config )
            end,
            startServer
        )
    else
        startServer()
    end
end


-- Stop the local server.
-- Called from Main Menu manager
function Server.Stop( callback )
    if IsServer(true) then
        Alert.SetText( "Stopping server" )
        CS.Network.Server.Stop()
        
        if not LocalServer.isPrivate then
            LocalServer:UpdateServerBrowser( true, callback )
        elseif callback ~= nil then
            callback()
        end
        
        LocalServer.playersById = {} -- 21/01/2014 : why do I do that ?
        LocalServer.playerIds = {}
        
        LocalServer = nil
        Client.Init()
    end
end


-- Connect the client to the provided server.
-- Called from Client.ConnectAsPlayer()
function Server.Connect( server, callback )   
    Client.Init()
    
    if server.ip ~= nil then
        local ip = server.ip
        if ip == Client.ip then
            ip = "127.0.0.1"
        end
        cprint("Server.Connect() : Connecting to : ", server, " With ip "..ip )
        
        
        CS.Network.Connect( ip, CS.Network.DefaultPort, function()           
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
    if IsServer(true) then
        Server.Stop( function() OriginalExit() end )
        -- what we want here is really to remove the server from the server browser
    else
        OriginalExit()
    end
end


----------------------------------------------------------------------
-- Global helpers

function IsServer( isOnline )
    if isOnline ~= nil then
        return (LocalServer ~= nil and LocalServer.isOnline == isOnline)
    else
        return LocalServer ~= nil
    end
end

function GetServer()
    return LocalServer or Client.server
end

function GetPlayer( playerId )
    return GetServer().playersById[ playerId ]
end

function GetGameConfig()
    return GetServer().game
end

function GetGametype()
    return GetGameConfig().gametype
end

function GetGametypeConfig( gt )
    if gt == nil then
        gt = GetGametype()
    end
    return GetGameConfig()[ gt ]
end


----------------------------------------------------------------------

function Behavior:Awake()
    ServerGO = self.gameObject
    self.gameObject.server = self
    self.gameObject.networkSync:Setup( NetworkSyncIds.Server )
    self.frameCount = 0
    
    -- Called when someone just arrived on the server, before the success callback of CS.NetWork.Connect() 
    -- (which is called even if the player is disconnected from there)
    CS.Network.Server.OnPlayerJoined( 
        function( player )
            --cprint("Server.OnPlayerJoined", player.id)
            local data = {
                server = table.copy( LocalServer ), -- copy so that modifying playersById and the player in the for loop below does not modify the actualy LocalServer and players
                -- Can't just recursively copy LocalServer because the game objects and components create recursive loops (that throw a stack overflow)
                playerId = player.id,
            }
            
            data.server.playersById = {}
            -- data.server.playerIds = nil -- let that, used in Server browser
            
            -- fill data.server.playersById
            for id, player in pairs( LocalServer.playersById ) do
                local playerCopy = table.copy( player )
                playerCopy.characterGO = nil -- must not include the characterGO property because the inner property can't be sent over the network (because it is of type userdata)
                playerCopy.isSpawned = false
                data.server.playersById[ id ] = playerCopy
            end
            
            -- player already spawned will be created in Client:UpdateGameState() if their coordinates are sent by Server:Update()
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
                
                self.gameObject.client:OnPlayerLeft( data )
            end
        end
    )
end


function Behavior:Update()
    if not IsServer(true) or #LocalServer.playerIds < 1 then
        return
    end
    
    self.frameCount = self.frameCount + 1
    local data = {}
    
    -- round time
    if self.frameCount % 5 == 0 then
        local tweener = Level.timerGO.updateTweener
        if tweener then
            data.roundTime = tweener.value
        end
        
        self.gameObject.networkSync:SendMessageToPlayers( "UpdateGameState", data, LocalServer.playerIds, CS.Network.DeliveryMethod.UnreliableSequenced, 2 )
    end    
    
    -- position and rotation
    if self.frameCount % 5 == 0 then
        for id, player in pairs( LocalServer.playersById ) do
            if player.isSpawned and player.characterGO ~= nil and player.characterGO.inner ~= nil then               
                local playerData = {
                    position = player.characterGO.transform:GetPosition(),
                    eulerAngles = player.characterGO.s.modelGO.transform:GetEulerAngles(),
                }
                
                player.characterGO.networkSync:SendMessageToPlayers( "UpdatePosition", playerData, LocalServer.playerIds, CS.Network.DeliveryMethod.UnreliableSequenced, 3 )
            end
        end
    end
end


-- Called from the success callback passed to Server.Connect() from Client.ConnectAsPlayer().
-- Data only holds the client's name
function Behavior:RegisterPlayer( data, playerId )
    if #LocalServer.playerIds < LocalServer.maxPlayerCount then
        
        local player = {} -- Player.New() is used in Client:OnPlayerJoined()
        player.id = playerId
        player.name = data.name
        
        if player.name == nil or player.name:trim() == "" then
            player.name = "John Doe " .. player.id
        end
        
        for id, _player in pairs( LocalServer.playersById ) do
            if player.name == _player.name then
                player.name = player.name.." "..player.id
                break
            end
        end
        
        -- choose a team
        player.team = 1
        if LocalServer.game.gametype ~= "dm" then
            local teamCount = { 0, 0 }
            for id, player in pairs( LocalServer.playersById ) do
                teamCount[ player.team ] = teamCount[ player.team ] + 1
            end
            if teamCount[1] > teamCount[2] then
                player.team = 2
            end
        end
        
        -- broadcast the new player
        self.gameObject.client:OnPlayerJoined( player ) 
    else
        self:DisconnectPlayer( playerId, "Server full" )
    end
end
CS.Network.RegisterMessageHandler( Behavior.RegisterPlayer, CS.Network.MessageSide.Server )


-- Disconnect the specified player from the server  and inform him of the reason
-- All other players are notified of the reason via CS.Network.Server.OnPlayerLeft()
function Behavior:DisconnectPlayer( id, reason )
    ServerGO.networkSync:SendMessageToPlayers( "OnDisconnected", { reason = reason }, { id } )
    LocalServer.playersById[ id ].reasonForDisconnection = reason -- used in CS.Network.Server.OnPlayerLeft()
    CS.Network.Server.DisconnectPlayer( id )
end

-- Called from the client's "Character Control" script or menus
-- Data contains the player input
function Behavior:SetCharacterInput( data, playerId )
    local player = LocalServer.playersById[ playerId ]
    -- spawn / suicide
    if data.input.spawnButtonClicked then       
        if not player.isSpawned and player.characterGO == nil then
            local spawnGO = Gametype.GetSpawn( player.team )
            
            local data = {
                playerId = playerId,
                position = spawnGO.transform.position,
                eulerAngles = spawnGO.transform.eulerAngles,
                
            }
            
            self.gameObject.client:SpawnPlayer( data )
        else -- suicide
            player.characterGO.s:Die( playerId )
        end
    
    -- changeteam
    elseif data.input.changeTeamButtonClicked then
        if not player.isSpawned and player.characterGO == nil then
            self.gameObject.client:ChangePlayerTeam( { playerId = playerId } ) 
        end
    end
end
CS.Network.RegisterMessageHandler( Behavior.SetCharacterInput, CS.Network.MessageSide.Server )


-- Called from Start() in the common level manager (when a client has fully loaded a level)
-- Mark player as ready to receive game statut update via Client:UpdateGameState()
function Behavior:MarkPlayerReady( data, playerId )
    LocalServer.playersById[ playerId ].isReady = true
    Daneel.Event.Fire("OnPlayerReady", playerId)
    
    -- create other characters on the client side
    local playerIdsToSpawn = {}
    for id, player in pairs( LocalServer.playersById ) do
        if player.isSpawned and player.characterGO ~= nil then
            table.insert( playerIdsToSpawn, id )    
        end
    end
    if #playerIdsToSpawn > 0 then
        self.gameObject.networkSync:SendMessageToPlayers( "UpdateGameState", { playerIdsToSpawn = playerIdsToSpawn }, { playerId } )
    end
end
CS.Network.RegisterMessageHandler( Behavior.MarkPlayerReady, CS.Network.MessageSide.Server )
-- Notifying the server of the readyness is actually currently useless since the server data is sent to all players anyway
-- "isReady" is only used on the client side in Client:UpdateGameState()
