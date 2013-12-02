
function Behavior:Awake()

    -- server name
    local nameInputGO = GameObject.Get( "Name.Input" )
    nameInputGO.input.OnUpdate = function( input )
        local name = input.gameObject.textRenderer.text
        Daneel.Storage.Save( "Server Name", name )
        Server.data.name = name
    end
    nameInputGO.input.OnFocus = function( input )
        if input.isFocused then
            input.gameObject.child.modelRenderer.opacity = 0.5
        else
            input.gameObject.child.modelRenderer.opacity = 0.2        
        end
    end
    
    Server.data.name = Daneel.Storage.Load( "Server Name", "default Server Name" )
    nameInputGO.textRenderer.text = Server.data.name
        
    -- max players
    local playerInputGO = GameObject.Get( "Max Players.Input" )
    playerInputGO.input.OnUpdate = function( input )
        local count = tonumber( input.gameObject.textRenderer.text )
        Daneel.Storage.Save( "Server Max Players",  count )
        Server.data.maxPlayerCount = count
    end
    playerInputGO.input.OnFocus = function( input )
        if input.isFocused then
            input.gameObject.child.modelRenderer.opacity = 0.5
        else
            input.gameObject.child.modelRenderer.opacity = 0.2        
        end
    end
    
    Server.data.maxPlayerCount = Daneel.Storage.Load( "Server Max Players", 12 )
    playerInputGO.textRenderer.text = Server.data.maxPlayerCount
    
    -- start/stop button
    local buttonGO = GameObject.Get( "Start-Stop Button" )
    local startText = "Start server"
    local stopText = "Stop server"
    
    buttonGO.OnClick = function()
        if Server.isRunning then
            self:StopServer()
            buttonGO.textRenderer.text = startText
        else
            self:StartServer()
            buttonGO.textRenderer.text = stopText
        end
    end
    
    if Server.isRunning then
        buttonGO.textRenderer.text = stopText
    else
        buttonGO.textRenderer.text = startText
    end
    
    -- player count
    self.playerCountRndr = GameObject.Get( "PlayerCount" ).textRenderer
    self.playerCountRndr.text = 0
end


function Behavior:Update()
    if CS.Input.WasButtonJustPressed( "Escape" ) then
        Scene.Load( "Menus/Main Menu" )
    end
end


function Behavior:StartServer()
    Server.Start()
end


function Behavior:StopServer()
   Server.Stop()
end

