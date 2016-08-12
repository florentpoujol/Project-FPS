
function Behavior:Awake()
    -- LocalServer is set in Client.Init()


    Daneel.Storage.Load( "ProjectFPS_ScreenSize", CS.Screen.GetSize(), function( screenSize, error )
        if error == nil then
            CS.Screen.SetSize( screenSize.x, screenSize.y )
        end
        --print( "Screen size :", CS.Screen.GetSize() )
     end )
    
    Daneel.Event.Listen( "OnSceneLoad", CS.Input.UnlockMouse, true )
    
    
    
    local testLevel = GameObject.Get( "Test Level" )
    testLevel:AddTag( "button" )
    testLevel.OnClick = function()
        Scene.Load( "Levels/Test Level" )
    end
    
    
    -- Player Name
    local inputGO = GameObject.Get( "Player Name.Input" )
    local background = inputGO.child
    
    inputGO.input.OnFocus = function( input )
        local playerName = input.gameObject.textRenderer.text
        
        if input.isFocused then
            background.modelRenderer.opacity = 0.5
            
            
        else
            if playerName:trim() == "" then -- don't let the name empty
                playerName = "Player"
                input.gameObject.textRenderer.text = playerName
            end
            
            background.modelRenderer.opacity = 0.2
            Daneel.Storage.Save( "PFPS_PlayerName", playerName, function( error )
                if error ~= nil then
                    Alert.SetText( "Error saving player name : "..error )
                end
            end )
            Player.name = playerName
        end
    end
    
    Daneel.Storage.Load( "PFPS_PlayerName", "Player", function( playerName, error )
        if error ~= nil then
            Alert.SetText( "Error loading player name : "..error )
            return
        end
        
        inputGO.textRenderer.text = playerName
        Player.name = playerName
        Client.player.name = playerName
    end )
    
   
    -- Multi
    local button = GameObject.Get( "Multi" )
    local subMenu = button:GetChild( "Button Group" )
    
    -- IP input when joining a game
    local ipInput = subMenu:GetChild( "IP Input", true )
    local background = ipInput.child
    ipInput.input.OnFocus = function( input )
        local text = input.gameObject.textRenderer.text
        local defaultIP = "127.0.0.1"
        
        if input.isFocused then
            background.modelRenderer.opacity = 0.5
            
        else -- on loose focus
            background.modelRenderer.opacity = 0.2
            if text:trim() == "" then 
                input.gameObject.textRenderer.text = defaultIP
            end
        end
    end
    
    -- join a game and go to the server browser
    local text = subMenu:GetChild( "Join", true )
    text:AddTag( "button" )
    text.OnClick = function()
        local ip = ipInput.textRenderer.text
        if #ip:split( "." ) == 4 then -- probably a correct IP           
            Client.ConnectAsPlayer( ip, function() Alert.SetText("Client is connected") end )
        else
            -- makes the input flash
            local oldOpacity = background.modelRenderer.opacity
            background.modelRenderer.opacity = oldOpacity + 0.3
            Tween.Timer( 0.3, function() background.modelRenderer.opacity = oldOpacity end )
        end
    end
    
    -- server browser
    text = subMenu:GetChild( "Server Browser", true )
    text:AddTag( "button" )
    text.OnClick = function() 
        Scene.Load( "Menus/Server Browser" )
    end
    
    --[[
    -- server manager
    text = subMenu:GetChild( "Server Manager", true )
    text:AddTag( "button" )
    text.OnClick = function() 
        Scene.Load( "Menus/Server Manager" )
    end
    ]]
    
    -- server config url
    local inputGO = GameObject.Get( "Server Config Path.Input" )
    inputGO.input.OnValidate = function( input )
        ServerConfigFilePath = input.gameObject.textRenderer.text
        self:SaveConfigFilePath()        
    end
    inputGO.input.OnFocus = function( input )
        if input.isFocused then
            input.backgroundGO.modelRenderer.opacity = 0.5
        else
            ServerConfigFilePath = input.gameObject.textRenderer.text
            self:SaveConfigFilePath()
            input.backgroundGO.modelRenderer.opacity = 0.2        
        end
    end
    
    -- load config file path
    self:GetServerConfigPath( function( path )
        Server.configFilePath = path
        inputGO.textRenderer.text = path
    end )
      
    
    -- server start/stop button
    local buttonGO = GameObject.Get( "Server Start-Stop Button" )
    buttonGO:AddTag( "button" )
    local startText = "Start server"
    local stopText = "Stop server"
    
    buttonGO.OnClick = function()
        if IsServer(true) then
            Server.Stop( function( server, data )
                if data and data.deleteFromServerBrowser then
                    Alert.SetText( "Successfully removed the server from the server browser" )
                end
            end )
            buttonGO.textRenderer.text = startText
        else
            Server.Start( function( server )
                if server.id ~= nil then
                    Alert.SetText( "Successfully posted on the server browser with id "..server.id.." and IP "..server.ip )
                else
                    Alert.SetText( "Unable to contact the server browser" )
                end
            end )
            buttonGO.textRenderer.text = stopText
        end
    end
    
    if IsServer(true) then
        buttonGO.textRenderer.text = stopText
    else
        buttonGO.textRenderer.text = startText
    end
    
    
    -- /Multi
    
    -- exit
    local exitGO = GameObject.Get( "Exit" )
    exitGO:AddTag( "button" )
    exitGO.OnClick = function() 
        CS.Exit()
    end
    
    -- Hide all sub menus
    --self:ShowSubMenu( nil )
        
end -- end Awake()


function Behavior:SaveConfigFilePath()
    Daneel.Storage.Save( "PFPS_ServerConfigFilePath", ServerConfigFilePath, function( error )
        if error ~= nil then
            Alert.SetText( "Unable to save server data : can't write data" )
        else
            Alert.SetText( "Config file path saved successfully." )
        end
    end )
    
    --if Server.configFilePath:startswith( "http://" ) or Server.configFilePath:startswith( "https://" ) then
    if ServerConfigFilePath:match( "^http.+\.json$" ) then
        Server.LoadConfigFile()
    else
        Alert.SetText("The server config file url must begin by 'http' and ends by '.json'.")
    end
end


function Behavior:GetServerConfigPath( callback )

    Daneel.Storage.Load( "PFPS_ServerConfigFilePath", {}, function( value, error ) 
        if error ~= nil then
            Alert.SetText( "ERROR : Unable to load config file path : "..error )
            cprint( "ERROR : Unable to load  config file path : "..error )
            return
        end
        
        if type( value ) ~= "table" and callback ~= nil then
            callback( value )
        end
    end )
    
end


function Behavior:ShowSubMenu( subMenu )
    -- Hide all submenus
    for i, subMenu in ipairs( self.subMenus ) do
        subMenu.transform.position = Vector3( 0, 0, 10 )
    end
    
    if subMenu ~= nil then
        subMenu.transform.localPosition = Vector3(0)
    end
end
