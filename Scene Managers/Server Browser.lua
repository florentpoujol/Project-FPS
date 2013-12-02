
--ServerBrowserAddress = "http://localhost/CSServerBrowser/index.php"
ServerBrowserAddress = "http://csserverbrowser.florentpoujol.fr/index.php"

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
    
    for i, child in pairs( self.serversListGO.children ) do
        child:Destroy()
    end
    
    CS.Web.Get( ServerBrowserAddress, nil, CS.Web.ResponseType.JSON, function( error, data )
        if error ~= nil then
            cprint( "Error getting servers", error )
            return
        end
        
        if data == nil or table.getlength( data ) == 0 then
            cprint("no server found")
            self.statusGO.textRenderer.text = "No server found !"
        else
            self:BuildServersList( data )
        end
    end )
end


function Behavior:BuildServersList( servers )
    local text = table.getlength( servers ).." servers found"
    cprint( text )
    self.statusGO.textRenderer.text = text

    local i = 0
    local yOffset = -2
    local server = nil
    
    local deadServers = {}
    local processDeadServers = function()
        for i, server in pairs( deadServers ) do
            cprint( "remove server", server.id, server.name, server.ip )
        end
    end
    
    local o = {}
    -- I use an object here because I can't vreate and call a local function in one instruction (the variable that holds the function is nil inside the function)
    -- but it works when the function is in an object (and probably a global function, too)
    o.TestConnect = function( callback )
        --table.print( servers )
        server = table.shift( servers )
        
        if server == nil then
            self.statusGO.textRenderer.text = ""
            processDeadServers()
            return
        end
        cprint("Testing connection with server", server.id, server.name, server.ip)
        
        if server.ip == Client.ip then
            server.ip = "127.0.0.1"
        end
        
        CS.Network.Connect( server.ip, CS.Network.DefaultPort, function()
            -- if we can connect to the server, display it in the list
            -- cprint("server OK", server.id, server.name, server.ip)
            
            
            
            CS.Network.Disconnect()
            local ip = server.ip
            local go = GameObject.New( "Server "..server.id, {
                parent = self.serversListGO,
                textRenderer = {
                    font = "Calibri",
                    text = "#"..server.id.." "..server.name.." ?/"..server.maxPlayerCount,
                    alignment = "left"
                },
                transform = {
                    localPosition = Vector3(0, yOffset * i, 0),
                    localScale = 0.2   
                },
                
                tags = { "mouseinput" },
                
                OnClick = function()
                    Server.interface:SendMessage( "ConnectClient", { ip = ip } )
                    
                end
            })
            
            i = i + 1
            
            o.TestConnect()
        end )
    end

    CS.Network.OnDisconnected( function()
        --cprint("unaccessible server", server.id, server.name, server.ip)
        table.insert( deadServers, server )
        o.TestConnect()        
    end )
    
    o.TestConnect()
    
    
    --self.statusGO.textRenderer.text = ""
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
