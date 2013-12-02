
local NetworkSyncId = 1234

function Behavior:Awake()
    self.gameObject.tchat = self
    self.gameObject.networkSync:Setup( NetworkSyncId )
    GUI.Console.New( self.gameObject )
end

function Behavior:Start()
    self.input = self.gameObject:GetChild( "Input" ).input
    self.input.OnValidate = function( input )
        print("OnValidate", self.input )
        self:SendTextToServer( input.gameObject.textRenderer.text )
    end
    
    self.input.OnFocus = function( input )
        
        if input.isFocused then
            input.gameObject.child.modelRenderer.opacity = 0.5
        else
            input.gameObject.child.modelRenderer.opacity = 0.2        
        end
    end
end


function Behavior:SendTextToServer( text )
    if Client.isConnected then
        self.gameObject.networkSync:SendMessageToServer( "BroadcastText", { text = text } )
    else
        self.gameObject.console:AddLine( "offline : "..text )
    end
end


function Behavior:BroadcastText( data, playerId )
    self.gameObject.networkSync:SendMessageToPlayers( "GetTextFromServer", { text = data.text, senderId = playerId }, Server.playerIds )
end
CS.Network.RegisterMessageHandler( Behavior.BroadcastText, CS.Network.MessageSide.Server )


function Behavior:GetTextFromServer( data )
    local text = data.text
    if data.senderId ~= Client.id then
        local player = Client.playersById[ data.senderId ]
        if player == nil then
            print("player is nil", data.senderId)
            table.print( Client.playersById )
            return
        end
        text = player.name.." : "..text


    end
    self.gameObject.console:AddLine( text )
end
CS.Network.RegisterMessageHandler( Behavior.GetTextFromServer, CS.Network.MessageSide.Players )
