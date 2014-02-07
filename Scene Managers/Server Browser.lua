
-- This script is on the same game object as the Server script

function Behavior:Awake()     
    local refreshGO = GameObject.Get( "Refresh" )
    refreshGO.OnClick = function()
        self:GetServers()
    end
    
    self.serversListGO = GameObject.Get( "Servers List" )
    self.deadIPs = {} -- IPs we can't reach
    -- keep the list here so that we don't try to connect again when refreshing the list if it was not deleted from the server browser
    
    if Game.disconnectionReason ~= nil then -- set in Client:OnDisconnected()
        Alert.SetText( "You have been disconnected for reason : "..Game.disconnectionReason )
        Game.disconnectionReason = nil
    else
        self:GetServers()
    end
end


function Behavior:GetServers()
    Alert.SetText( "Getting servers..." )
    local servers = {}
 
    CS.Web.Get( ServerBrowserAddress, nil, CS.Web.ResponseType.JSON, function( error, data )
        if error ~= nil then
            Alert.SetText( "Error getting servers : "..error.message )
            return
        end
        
        if data == nil or table.getlength( data ) == 0 then
            Alert.SetText( "No server found." )
            self.serversListGO.textArea.text = "No server found."
        else
            local servers = {}
            for id, serverData in pairs( data ) do
                if not table.containsvalue( self.deadIPs, serverData.ip ) then
                    servers[ id ] = Server.New( serverData )
                end
            end

            self:BuildServersList( servers )
        end
    end )
end


function Behavior:BuildServersList( servers )
    -- empty the current list of servers
    self.serversListGO.textArea.text = ""
    for i, textRenderer in pairs( self.serversListGO.textArea.lineRenderers ) do
        textRenderer.gameObject.server = nil
        Daneel.Event.StopListen( "OnConnected", textRenderer.gameObject )
        textRenderer.gameObject.OnConnected = nil
    end
    
    local server = nil
    local serverCount = 0
    local disconnectTimer = nil
    local o = {}
    -- I use an object here because I can't create and call a local function in a single instruction (the variable that holds the function is nil inside the function)
    -- but it works when the function is in an object
    
    -- Test the connection to the server (and receive data from it (nane, player count, level) (in Server:OnConnected()))
    -- Display it in the list if the server can be reached,
    -- or register it to be removed from the server browser.
    --
    -- Inaccessible servers in the server browser happens when the server stops but don't removes itself from the server browser
    -- like when the game is closed by cliquing the window's red cross instead of calling CS.Exit()
    o.TestConnect = function()
        CS.Network.Disconnect()
        if disconnectTimer ~= nil then
            disconnectTimer:Destroy()
        end
        
        server = table.shift( servers )
        
        if server == nil then -- no more servers to test
            Alert.SetText( "" )
            if serverCount == 0 then
                Alert.SetText( "No server found." )
                self.serversListGO.textArea.text = "No server found."
            end
            CS.Network.OnDisconnected( nil )
            return
        end
        
        local disconnectTime = 5
        Alert.SetText( "Testing connection to "..(table.getlength( servers ) + 1).." more servers...", disconnectTime )
        
        if server.ip == Client.ip then
            server.ip = "127.0.0.1"
        end
        
        -- Disconnect if the server hasn't responded in 5 seconds (CS.Network.Connect() takes 12 seconds to do that automatically)
        disconnectTimer = Tween.Timer( disconnectTime, function()
            table.insert( self.deadIPs, server.ip )
            server:UpdateServerBrowser( true )
            o.TestConnect()
        end )
        
        CS.Network.Connect( server.ip, CS.Network.DefaultPort, function()
            -- can connect to the server, display it in the list
            -- cprint("server OK", server)
            
            serverCount = serverCount + 1

            --CS.Network.Disconnect() -- this is too soon to disconnect
            -- Client:OnConnected() isn't called yet and it seems that it causes error when connecting again to the same server
            -- when refreshing the server list ?
            Tween.Timer( 0.2, o.TestConnect ) -- call the function again to test the next server
            
            disconnectTimer:Destroy()
            
            -- Update the server's list            
            self.serversListGO.textArea.text = self.serversListGO.textArea.text .. "#"..server.id.." "..server.name .. "<br>"
            
            for i, textRenderer in ipairs( self.serversListGO.textArea.lineRenderers ) do -- ipairs is important here
                -- the lineRenderers are the text renderers that display the individual lines of the text area
                
                local go = textRenderer.gameObject
                if go.server == nil then
                    --cprint("set data on textRenderer", textRenderer, go, server )
                    go.server = server
                    
                    Daneel.Event.Listen( "OnConnected", go ) -- don't make the function listen to the event to be able to stop to listen
                    go.OnConnected = function( _server )
                        if _server.id ~= go.server.id then -- don't compare ip here > 21/01/2014 why ?
                            return
                        end
                        -- fired in Client:OnConnected() with the data of the recently connected server
                        -- update the text with server's data (name, playerCount, ...)
                        go.server = _server
                        textRenderer.text = textRenderer.text.." | "..#_server.playerIds.."/".._server.maxPlayerCount.." | ".._server.game.gametype.." | ".._server.game.scenePath
                        return false
                    end
                                        
                    go:AddTag( "mouseinput" )
                    go.OnMouseEnter = function()
                        textRenderer.opacity = 0.7
                    end
                    go.OnMouseExit = function()
                        textRenderer.opacity = 1
                    end
                    go.OnClick = function()
                        Alert.SetText( "Connecting to server '"..go.server.name.."'..." )
                        Client.ConnectAsPlayer( go.server )
                    end
                    break
                end
            end
        end )
    end

    CS.Network.OnDisconnected( function()
        table.insert( self.deadIPs, server.ip )
        server:UpdateServerBrowser( true )
        o.TestConnect()
    end )
    
    o.TestConnect() -- start to test the servers
end


function Behavior:Update()
    if CS.Input.WasButtonJustPressed( "Escape" ) then
        Client.Init()
        Scene.Load( "Menus/Main Menu" )
    end
end
