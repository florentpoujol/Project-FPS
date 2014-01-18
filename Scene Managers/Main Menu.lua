
function Behavior:Awake()
    Daneel.Storage.Load( "ProjectFPS_ScreenSize", CS.Screen.GetSize(), function( screenSize, error )
        if error == nil then
            CS.Screen.SetSize( screenSize.x, screenSize.y )
        end
        print( "Screen size :", CS.Screen.GetSize() )
     end )
    
    Daneel.Event.Listen( "OnSceneLoad", CS.Input.UnlockMouse, true )
    
    
    CS.Web.Get( "https://dl.dropboxusercontent.com/u/51314747/craftstudio_tutos_script.css",nil, CS.Web.ResponseType.Text, function( error, text )
        if error ~= nil then
            print( "Couldn't get news!" )
            return
        end

        print("txt", text )
    end )
    
    
    
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
            Daneel.Storage.Save( "ProjectFPS_PlayerName", playerName, function( error )
                if error ~= nil then
                    Alert.SetText( "Error saving player name : "..error )
                end
            end )
            Player.name = playerName
        end
    end
    
    Daneel.Storage.Load( "ProjectFPS_PlayerName", "Player", function( playerName, error )
        if error ~= nil then
            Alert.SetText( "Error loading player name : "..error )
            return
        end
        
        inputGO.textRenderer.text = playerName
        Player.name = playerName
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
    
    -- create server
    text = subMenu:GetChild( "Server Manager", true )
    text:AddTag( "button" )
    text.OnClick = function() 
        Scene.Load( "Menus/Server Manager" )
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
    
    local go = GameObject.Get( "ScrollableText" )
    go:AddComponent( "ScrollableText", { 
        newLine = "<br>",
        Height = 2
    } )
    
    
    local text = "line1 <br>line2 <br>line3 <br>line4 <br>line5 <br>line6<br>line7 <br>line8"
    go.scrollableText:SetText( text )

    go.scrollableText.Height = 4
    go.scrollableText.scrollPosition = 3
    go.scrollableText:SetText( text )
    
end -- end Awake()


function Behavior:ShowSubMenu( subMenu )
    -- Hide all submenus
    for i, subMenu in ipairs( self.subMenus ) do
        subMenu.transform.position = Vector3( 0, 0, 10 )
    end
    
    if subMenu ~= nil then
        subMenu.transform.localPosition = Vector3(0)
    end
end
