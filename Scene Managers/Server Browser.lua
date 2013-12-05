
-- This script is on the same game object as the Server script

function Behavior:Awake()  
    self.uiGO = GameObject.Get( "UI" )
        
    self.statusGO = GameObject.Get( "Status" )
    self.statusGO.textRenderer.text = "Getting servers..."
    cprint("Getting servers")
    
    local refreshGO = GameObject.Get( "Refresh" )
    refreshGO.OnClick = function()
        cprint( "Refreshing servers" )
        self:GetServers()
    end
    
    self.serversListGO = GameObject.Get( "Servers List" )
    self:GetServers()
end


function Behavior:GetServers()
    local servers = {}
    
    -- empty the current list of servers
    self.serversListGO.textArea.text = ""
    --for i, child in pairs( self.serversListGO.children ) do
        --child:Destroy()
    --end
    
    CS.Web.Get( ServerBrowserAddress, nil, CS.Web.ResponseType.JSON, function( error, data )
        if error ~= nil then
            cprint( "Error getting servers", error )
            self.statusGO.textRenderer.text = "Error getting servers"
            return
        end
        
        if data == nil or table.getlength( data ) == 0 then
            cprint("no server found")
            self.statusGO.textRenderer.text = "No server found."
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
    local text = table.getlength( servers ).." servers found"
    cprint( text )
    self.statusGO.textRenderer.text = text
    
    --local i = 0
    --local yOffset = -2
    local server = nil
    
    local deadServers = {} -- inaccessible servers
    local processDeadServers = function()
        cprint("Trying to remove "..#deadServers.." inaccessible servers")
        for i, server in pairs( deadServers ) do
            cprint( "Removing server", server )
            server:UpdateServerBrowser( true )
        end
    end
    
    local o = {}
    -- I use an object here because I can't create and call a local function in a single instruction (the variable that holds the function is nil inside the function)
    -- but it works when the function is in an object (and probably a global function, too)
    
    -- Test the connection to the server
    -- Display it in the list if the server can be reached,
    -- or register it to be removed from the server browser.
    --
    -- Inaccessible servers in the server browser happens when the server stops but don't removes itself from the server browser
    -- like when the game is close by cliquing the window's red cross instead of calling CS.Exit()
    o.TestConnect = function()
        --table.print( servers )
        server = table.shift( servers )
        
        if server == nil then -- no more servers to test
            self.statusGO.textRenderer.text = ""
            processDeadServers()
            return
        end
        cprint("Testing connection with server", server)
        
        if server.ip == Client.ip then
            server.ip = "127.0.0.1"
        end
        
        CS.Network.Connect( server.ip, CS.Network.DefaultPort, function()
            -- if we can connect to the server, display it in the list
            cprint("server OK", server)

            CS.Network.Disconnect()
            
            -- Create the gameObject to display the server's data and connect to it
            local ip = server.ip
            --[[
            GameObject.New( "Server "..server.id, {
                parent = self.serversListGO,
                textRenderer = {
                    --font = "Calibri",
                    text = 
                    alignment = "left"
                },
                transform = {
                    localPosition = Vector3(0, yOffset * i, 0),
                    localScale = 0.2   
                },
                
                tags = { "mouseinput" },
                
                OnClick = function()
                    ServerGO:SendMessage( "ConnectClient", { ip = ip } )
                end
            })
            
            i = i + 1
            ]]
            local text = self.serversListGO.textRenderer.text
            
            text = text .. "#"..server.id.." "..server.name .. "<br>"
            self.serversListGO.textArea.text = text
            for i, textRenderer in pairs( self.serversListGO.textArea.lineRenderers ) do
                --print(self.serversListGO, self.serversListGO.textArea, child)
                textRenderer.opacity = 0.5
            end
            
            -- TODO : use a TextArea and apply a function to each lines to render them clickable (
            -- > easy cliquable list (pass list items as array) ! Can be great for menus, too !
            
            o.TestConnect()
        end )
    end

    CS.Network.OnDisconnected( function()
        --cprint("unaccessible server", server)
        table.insert( deadServers, server )
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
    --Client.Init()
    Scene.Load( "Menus/Main Menu" )
end


function Behavior:Connect()
    Client.Connect()

end


function Behavior:OnPlayerActivated( data )
    print(Client.playerId, "Game room OnPlayerActivated", data.player.id )
    cprint( "Activated with id "..data.player.id.." "..data.player.name )
end
CS.Network.RegisterMessageHandler( Behavior.OnPlayerActivated, CS.Network.MessageSide.Players )
