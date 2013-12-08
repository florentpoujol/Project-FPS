
Tchat = {
    gameObject = nil,
    
    -- interface to add a line in the tchat from another script   
    AddLine = function( text )
        if Tchat.gameObject ~= nil and Tchat.gameObject.inner ~= nil then
            print( text )
            Tchat.gameObject.console:AddLine( text )
        end
    end
}

local NetworkSyncId = 1234

function Behavior:Awake()
    Tchat.gameObject = self.gameObject
    self.gameObject.tchat = self
    
    self.gameObject.networkSync:Setup( NetworkSyncId )
    GUI.Console.New( self.gameObject )
end

function Behavior:Start()
    -- in Start() to wait for the input to be created
    
    self.input = self.gameObject:GetChild( "Input" ).input
    if self.input.OnValidate == nil then
        self.input.OnValidate = function( input )
            --print("OnValidate", self.input )
            local text = input.gameObject.textRenderer.text:trim()
            if text ~= "" then
                self:SendTextToServer( text )
            end
            input.gameObject.textRenderer.text = ""
        end
    end
    
    if self.input.OnFocus == nil then
        self.input.OnFocus = function( input )
            if input.isFocused then
                input.gameObject.child.modelRenderer.opacity = 0.5
            else
                input.gameObject.child.modelRenderer.opacity = 0.2        
            end
        end
    end
end


-- send a new line to add to the tchat
function Behavior:SendTextToServer( text )
    if text:startswith( "/" ) then
        if LocalServer ~= nil then -- or Client.data.isAdmin
            -- do stuff with the command
            text = text:sub( 2 )
            local command = text:split( " " )-- 1: command  2: parameters
            
            if command[1] == "kick" and command[2] ~= nil then
                -- check player id here
                LocalServer:DisconnectPlayer( command[2], "Has been kicked by server" )
            end
            
        else
            self.gameObject.console:AddLine( "You are not allowed to issue commands" )
            return
        end
    end




    if Client.isConnected then
        self.gameObject.networkSync:SendMessageToServer( "BroadcastText", { text = text } )
    elseif LocalServer ~= nil then
        self:BroadcastText( { text = text }, -2 )
    else
        self.gameObject.console:AddLine( text )
    end
end


-- called by a client to broadcast the text to all clients
function Behavior:BroadcastText( data, playerId )
    data = { text = data.text, senderId = playerId }
    self.gameObject.networkSync:SendMessageToPlayers( "ReceiveText", { text = data.text, senderId = playerId }, LocalServer.playerIds )
    self:ReceiveText( data )
--    self.gameObject.console:AddLine( "Server : "..data.text )
end
CS.Network.RegisterMessageHandler( Behavior.BroadcastText, CS.Network.MessageSide.Server )


-- called by the server, add a new line to the tchat
function Behavior:ReceiveText( data )
    local text = data.text
    
    local server = Client.server or LocalServer
    
    local playerName = "Server"
    if data.senderId >= 0 then
        playerName = "Player"..data.senderId
    end
    
    local player = server.playersById[ data.senderId ]
    if player ~= nil then
        if LocalServer ~= nil then
            playerName = player.name.." ("..player.id..")"
        else
            playerName = player.name    
        end
    end

    self.gameObject.console:AddLine( playerName.." : "..text )
end
CS.Network.RegisterMessageHandler( Behavior.ReceiveText, CS.Network.MessageSide.Players )
