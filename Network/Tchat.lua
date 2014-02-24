
-- Allow players to tchat over the network
-- Any texts can be displayed locally or sent over the network without user input
-- Add the script on a "Tchat" game object

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


function Behavior:Awake()
    Tchat.gameObject = self.gameObject
    self.gameObject.tchat = self
    
    self.gameObject.networkSync:Setup( 1 )
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
        -- updated in HUD:Start()
        self.input.OnFocus = function( input )
            if input.isFocused then
                input.gameObject.child.modelRenderer.opacity = 0.5
                InputManager.AddTag( "tchatfocused" )
            else
                input.gameObject.child.modelRenderer.opacity = 0.2
                InputManager.RemoveTag( "tchatfocused" )
            end
        end
    end
end


function Behavior:Update()
    if InputManager.WasButtonJustReleased( "TchatFocus", "tchatfocused", false ) then
        self.input:Focus( true )
    end
    
    if InputManager.WasButtonJustReleased( "Escape", "tchatfocused" ) then
        self.input:Focus( false )
    end
end

-- send a new line to add to the tchat
function Behavior:SendTextToServer( text )
    text = text:trim()
    if text:startswith( "/" ) then
        if IsServer then
            -- do stuff with the command
            text = text:sub( 2 ):trimstart()
            local command = text:split( " " )-- 1: command  2: parameters
            local cmdName = table.remove( command, 1 )
            
            -- allow for space in names surrounded by double quotes (only works for first param)
            local startIndex = -1
            local endIndex = -1
            local text = ""
            for i, param in ipairs( command ) do
                text = text .. param .. " "
                if param:find( '"', 1, true ) then
                    if startIndex == -1 then
                        startIndex = i
                        text = param:sub(2).." "
                    else
                        endIndex = i
                        text = text:sub( 1, #text-2 ) -- removes the last space and quote
                        break
                    end
                end            
            end
            if startIndex ~= -1 and endIndex > startIndex then
                command[ startIndex ] = text
                for i=startIndex+1, endIndex do
                    table.remove( command, startIndex+1 )
                end
            end
            
                        
            if cmdName ~= nil and AdminCmd[ cmdName ] ~= nil then
                AdminCmd[ cmdName ]( unpack(command) )
            elseif cmdName == nil then -- never happens, cmdName is always at least ""
                self.gameObject.console:AddLine( "Command unknow : "..tostring(text) )
            else
                self.gameObject.console:AddLine( "Command unknow '"..cmdName.."' with params : "..table.concat(command, ", " ) )
            end
            
        else
            self.gameObject.console:AddLine( "You are not allowed to issue commands on this server !" )
        end
        
        return
    end

    if Client.isConnected then
        self.gameObject.networkSync:SendMessageToServer( "BroadcastText", { text = text } )
    elseif IsServer then
        self:BroadcastText( { text = text }, -2 )
    else -- client offline
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
    
    local playerName = "[Server]"
    if data.senderId >= 0 then
        playerName = "[Player"..data.senderId.."]"
    end
    
    local server = Client.server or LocalServer
    if server == nil then
        cprint("server is nil", Client.server, LocalServer, Client.player)
        table.print(Client.player)
        return
    end
    local player = server.playersById[ data.senderId ]
    if player ~= nil then
        if IsServer then
            playerName = "["..player.name.."] ("..player.id..")"
        else
            playerName = "["..player.name.."]"
        end
    end

    self.gameObject.console:AddLine( playerName.." "..text )
end
CS.Network.RegisterMessageHandler( Behavior.ReceiveText, CS.Network.MessageSide.Players )
