
local function Show( gameObject )
    local position = gameObject.transform.position
    position.z = -10
    gameObject.transform.position = position
end

local function Hide( gameObject )
    local position = gameObject.transform.position
    position.z = 10
    gameObject.transform.position = position
end


-- que ce passe-t-il si un client essaye de se connecter depuis la game room à un server qui est sur une autre scène
-- que ce passe-t-il dans ce cas si cette scène a un networkSync avec le même ID 
-- peut-on créé un server indépendant (sans y connecter le host

function Behavior:Awake()  
    Client.isInGameRoom = true

    self.uiGO = GameObject.Get( "UI" )
    --Hide( self.uiGO )
    
    self.backButton = GameObject.Get( "Back Button" )
    --Show( self.backButton )
    self.backButton:AddTag( "buton" )
    self.backButton.OnClick = self.GoBackToMainMenu
    
    local joinGO = GameObject.Get( "Join" )
    joinGO:AddTag( "button" )
    joinGO.OnClick = function()
        self:Connect()
    end
    joinGO.textRenderer.text = "Join IP "..Client.ipToConnectTo
    print("Game Room Joinning IP "..Client.ipToConnectTo )
    
    --self.statusGO = GameObject.Get( "Game Status" )
    --Show( self.statusGO )
    
    
    local exitGO = GameObject.Get( "Exit" )
    exitGO.OnClick = function()
        print("user disconnect itself by  Network.Disconnect()")
        --CS.Network.Disconnect()
        CS.Exit()
    end
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
    Client.Init()
    
    cprint( "Connecting to IP "..Client.ipToConnectTo )
    
    CS.Network.Connect( Client.ipToConnectTo, CS.Network.DefaultPort, function()
        print("CS.Network.Connect success callback")
        Client.isConnected = true
        cprint( "Connected, waiting activation" )
        self.gameObject.networkSync:SendMessageToServer( "ActivatePlayerOnServer", { playerName = Client.name } ) -- activate player on the server, get server data and notify other players
    end )
    
 
end


function Behavior:OnPlayerActivated( data )
    print(Client.playerId, "Game room OnPlayerActivated", data.player.id )
    cprint( "Activated with id "..data.player.id.." "..data.player.name )
end
CS.Network.RegisterMessageHandler( Behavior.OnPlayerActivated, CS.Network.MessageSide.Players )
