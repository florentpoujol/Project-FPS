



function Behavior:Awake()

    -- server name
    local nameInputGO = GameObject.Get( "Name.Input" )
    nameInputGO.input.OnUpdate = function( input )
        local name = input.gameObject.textRenderer.text
        Daneel.Storage.Save( "Server Name", name )
    end
    nameInputGO.input.OnFocus = function( input )
        if input.isFocused then
            input.gameObject.child.modelRenderer.opacity = 0.5
        else
            input.gameObject.child.modelRenderer.opacity = 0.2        
        end
    end
    
    Server.name = Daneel.Storage.Load( "Server Name", "def Server Name" )
    nameInputGO.textRenderer.text = Server.name
        
    -- max players
    local playerInputGO = GameObject.Get( "Max Players.Input" )
    playerInputGO.input.OnUpdate = function( input )
        local count = input.gameObject.textRenderer.text
        Daneel.Storage.Save( "Server Max Players", tonumber( count ) )
    end
    playerInputGO.input.OnFocus = function( input )
        if input.isFocused then
            input.gameObject.child.modelRenderer.opacity = 0.5
        else
            input.gameObject.child.modelRenderer.opacity = 0.2        
        end
    end
    
    Server.maxPlayerCount = Daneel.Storage.Load( "Server Max Players", 12 )
    playerInputGO.textRenderer.text = Server.maxPlayerCount
    
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
    print("Start server")
    Server.Init()
    
    CS.Network.Server.Start()
    Server.isRunning = true
end


function Behavior:StopServer()
   print( "Stop Server" )
   CS.Network.Server.Stop()
   Server.Init()
end



function Behavior:UpdatePlayerList( data )
    print(Client.playerId, "ServerManager UpdatePlayerList", data.player.id )
    self.playerCountRndr.text = tonumber( self.playerCountRndr.text ) + 1
end
CS.Network.RegisterMessageHandler( Behavior.UpdatePlayerList, CS.Network.MessageSide.Server )


