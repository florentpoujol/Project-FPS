
Server = {   
    maxPlayerCount = 12,
    name = "Server Name",
    level = "", --scene path
}

function Server.GetNetworkId()
    Server.lastNetworkId = Server.lastNetworkId + 1
    return Server.lastNetworkId
end

function Server.Init()  
    Server.playersById = {}
    Server.playerIds = {}
    Server.lastNetworkId = 100
    Server.isRunning = false
end
Server.Init()


Client = {
    name = "Player",
    ipToConnectTo = "127.0.0.1",
}

function Client.Init()
    Client.isConnected = false
    Client.id = -1
    Client.playersById = {}
    Client.playerIds = {}
end
Client.Init()


----------------------------------------------------------------------


function Behavior:Awake()
    self.gameObject.networkSync:Setup( 0 )
    
    -- Called when someone just arrived on the server, before the success callback of CS.NetWork.Connect() 
    -- (which is called even if the player is dosconnected from there)
    CS.Network.Server.OnPlayerJoined( 
        function( player )
            print("Server.OnPlayerJoined", player.id)

            if table.getlength( Server.playersById ) < Server.maxPlayerCount then
                player.isActive = false
                player.name = "Player #" .. player.id
                
                Server.playersById[ player.id ] = player
                table.insert( Server.playerIds, player.id )
            else
                -- Not allowed to connect

                -- ideally should send a player message with the reason for disconnect
                --self.gameObject.networkSync:SendMessageToPlayers( "OnDisconnected", { reason = "Server full" }, { player.id } )
                
                CS.Network.Server.DisconnectPlayer( player.id )
            end
            
            print("end on player joined")
        end
    )
    
    -- Called when a player left the server 
    -- because it disconnect itself via CS.Network.Disconnect()
    -- or it is disconnected via CS.Network.Server.DisconnectPlayer()
    -- or its game has shut down
    -- NOT called when the server stops
    CS.Network.Server.OnPlayerLeft( 
        function( playerId )
            print("Server.OnPlayerLeft", playerId)
            
            local player = Server.playersById[ playerId ]
            Server.playersById[ playerId ] = nil
            table.removevalue( Server.playerIds, playerId )
            
            self.gameObject.networkSync:SendMessageToPlayers( "OnPlayerDisconnected", { playerId = playerId }, Server.playerIds )
        end
    )
    
    
    -- Called when a player is disconnected by the server with CS.Network.Server.DisconnectPlayer() (and on server stop)
    -- NOT called by CS.Network.Disconnect()
    -- CS.Network.Server.OnPlayerLeft() is called next (but not when the server stops)
    CS.Network.OnDisconnected( function()
        print("CS.Network.OnDisconnected", Client.id)
        Client.Init()
        --Scene.Load( "Menu/Game Room" )
    end )
end

-- Called from the success callback of CS.Network.Connect() when a player successfully connected to the server
-- Activate a player on the server, send server data and player id to the player and notify other players of a new player
function Behavior:ActivatePlayerOnServer( data, playerId )
    print("ActivatePlayerOnServer", playerId )
    
    local player = Server.playersById[ playerId ]
    if player == nil then return end -- when can this happen ? > when ActivatePlayer() is called before CS.Network.Server.OnPlayerJoined() > when can this happend
       
    if data.playerName ~= nil then
        -- check if the name already exists and append the id it's the case
        for id, player in pairs( Server.playersById ) do
            print("player name", id, player.name, player.id)
            if id ~= playerId and player.name == data.playerName then
                data.playerName = data.playerName .. " " .. player.id
                print("changin player name")
                break
             end
        end
        
        player.name = data.playerName 
    end
    
    
    player.isActive = true
    
    local clientData = {
        playersById = Server.playersById,
        playerIds = Server.playerIds,
        id = playerId,
        name = player.name,
    }
    
    self.gameObject.networkSync:SendMessageToPlayers( "SetClientWithDataFromServer", clientData, { playerId } )
    
    self.gameObject.networkSync:SendMessageToPlayers( "OnPlayerActivated", { player = player }, Server.playerIds )
    
    self.gameObject:SendMessage( "UpdatePlayerList", { player = player } )
end
CS.Network.RegisterMessageHandler( Behavior.ActivatePlayerOnServer, CS.Network.MessageSide.Server )


--------------------------------------------------------------------------------


-- Called from ActivatePlayer() on the server when this new player is connected
-- called on a single player
function Behavior:SetClientWithDataFromServer( data )
    print(data.id, "SetClientWithDataFromServer")
    Client = table.merge( Client, data )
end
CS.Network.RegisterMessageHandler( Behavior.SetClientWithDataFromServer, CS.Network.MessageSide.Players )


-- Called from ServerActivatePlayer() on the server when a new player is connected and activated
function Behavior:OnPlayerActivated( data )
    print(Client.id, "OnPlayerActivated", data.player.id )
    Client.playersById[ data.player.id ] = data.player
end
CS.Network.RegisterMessageHandler( Behavior.OnPlayerActivated, CS.Network.MessageSide.Players )



function Behavior:OnPlayerDisconnected( data )
    print(Client.id, "OnPlayerDisconnected", data.playerId )
    
    --Client.playersById[ data.playerId ] = nil
    
    
end
CS.Network.RegisterMessageHandler( Behavior.OnPlayerDisconnected, CS.Network.MessageSide.Players )


