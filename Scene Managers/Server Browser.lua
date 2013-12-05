
-- This script is on the same game object as the Server script

function Behavior:Awake()     
    local refreshGO = GameObject.Get( "Refresh" )
    refreshGO.OnClick = function()
        Alert.SetText( "Refreshing servers" )
        self:GetServers()
    end
    
    self.serversListGO = GameObject.Get( "Servers List" )
    --self.serversListGO.textArea.text = ""
    self:GetServers()
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
            for k,v in pairs( data ) do
                servers[k] = Server.New( v )
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
    end
    
    local server = nil
    local o = {}
    -- I use an object here because I can't create and call a local function in a single instruction (the variable that holds the function is nil inside the function)
    -- but it works when the function is in an object
    
    -- Test the connection to the server
    -- Display it in the list if the server can be reached,
    -- or register it to be removed from the server browser.
    --
    -- Inaccessible servers in the server browser happens when the server stops but don't removes itself from the server browser
    -- like when the game is closed by cliquing the window's red cross instead of calling CS.Exit()
    o.TestConnect = function()
        CS.Network.Disconnect()
        
        server = table.shift( servers )
        
        if server == nil then -- no more servers to test
            Alert.Hide()
            CS.Network.OnDisconnected( nil )
            return
        end
        
        --cprint("Testing connection with server", server)
        Alert.SetText( "Testing connection to "..(table.getlength( servers ) + 1).." more servers...", -1 )
        
        if server.ip == Client.ip then
            server.ip = "127.0.0.1"
        end
        
        CS.Network.Connect( server.ip, CS.Network.DefaultPort, function()
            -- if we can connect to the server, display it in the list
            --cprint("server OK", server)

            --CS.Network.Disconnect() -- this is too soon to disconnect
            -- OnConnected isn't called yet and it seems that it causes error when connecting again to the same server
            -- when refreshing the server list
            
            -- Update the server's list
            self.serversListGO.textArea.text = self.serversListGO.textArea.text .. "#"..server.id.." "..server.name .. "<br>"
            
            for i, textRenderer in ipairs( self.serversListGO.textArea.lineRenderers ) do -- ipairs is important here
                local go = textRenderer.gameObject
                if go.server == nil then
                    --cprint("set data on textRenderer", textRenderer, go, server )
                    
                    go.server = server
                    
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
            
            Tween.Timer( 10, o.TestConnect, { durationType = "frame" } ) -- wait 5 frame to let the time to client to be disconnect from the network
        end )
    end

    CS.Network.OnDisconnected( function()
        --cprint("unaccessible server", server)
        server:UpdateServerBrowser( true )
        o.TestConnect()
    end )
    
    o.TestConnect()
end


function Behavior:Update()
    if CS.Input.WasButtonJustPressed( "Escape" ) then
        self.GoBackToMainMenu()
    end
end


function Behavior:GoBackToMainMenu()
    --CS.Network.Disconnect()
    Client.Init()
    Scene.Load( "Menus/Main Menu" )
end
