
function Behavior:Awake()
    Client.Init()
    
    self.subMenus = {}
    
    
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
            Daneel.Storage.Save( "PlayerName", playerName )
            Client.name = playerName
        end
    end
    
    local playerName = Daneel.Storage.Load( "PlayerName", "Player" )
    inputGO.textRenderer.text = playerName
    Client.name = playerName
    
    
    -- Multi
    local button = GameObject.Get( "Multi" )
    local subMenu = button:GetChild( "Sub Menu" )
    table.insert( self.subMenus, subMenu )
    
    local text = button:GetChild( "Text" )
    text:AddTag( "button" )
    text.OnMouseEnter = function() self:ShowSubMenu( subMenu ) end
    
    -- IP input when joining a game
    local ipInput = subMenu:GetChild( "IP Input", true )
    local background = ipInput.child
    ipInput.input.OnFocus = function( input )
        local text = input.gameObject.textRenderer.text
        local defaultIP = "127.0.0.1"
        
        if input.isFocused then
            background.modelRenderer.opacity = 0.5
            if text == defaultIP then
                if Client.ipToConnectTo ~= nil then
                    input.gameObject.textRenderer.text = Client.ipToConnectTo
                else
                    input.gameObject.textRenderer.text = ""
                end
            end
            
        else
            background.modelRenderer.opacity = 0.2
            if text:trim() == "" then -- on loose focus
                input.gameObject.textRenderer.text = defaultIP
            end
        end
    end
    
    -- join a game and go to the server browser
    text = subMenu:GetChild( "Join", true )
    text:AddTag( "button" )
    text.OnClick = function()
        do return end
        
        local ipToConnectTo = ipInput.textRenderer.text
        if #ipToConnectTo:split( "." ) == 4 then -- probably a correct IP
            Client.ipToConnectTo = ipToConnectTo
            
            --Server.interface:SendMessage( "ConnectClient" )
            --Scene.Load( "Menus/Server Browser" )
            --cprint( "Join IP "..Client.ipToConnectTo )
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

    
    -- Hide all sub menus
    --self:ShowSubMenu( nil )
    self:ShowSubMenu( subMenu ) -- show multi
    
    -- start server
    --[[if not Server.isRunning then
        Server.Init()
        CS.Network.Server.Start()
        Server.isRunning = true
    end]]
    
    local ss = CS.Screen.GetSize()
    local test = GameObject.Get("Test HUD")
    local position = Vector2( 10, ss.y - 10 )
    test:AddComponent( "GUI.Hud", {
            position = position
         }
     )

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
