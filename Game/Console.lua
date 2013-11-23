
function table.reverse( t )
    local length = #t
    local newTable = {}
 
    for i, v in ipairs( t ) do
        table.insert( newTable, 1, v )
    end
    
    return newTable
end

function LoadGUIConsole()
    GUI.Console = {}
    GUI.Console.__index = GUI.Console
    
    function GUI.Console.New( gameObject )
        local console = setmetatable( {}, GUI.Console )
        gameObject.console = console
        console.textArea = gameObject.textArea
        console.height = 10 -- 10 lines
        console.showLineNumber = true
        console.lastLineNumber = 0
        console.filter = nil -- function which gets the line as argument and must return the line or false or nil (in which cases, the line is not added to the console)
        -- this allows to "listen" for commands (or slang) in the lines.
        
        return console
    end

    function GUI.Console.AddLine( console, line )
        if console.filter ~= nil then
            line = console.filter( line )
            if not line then
                return
            end
        end
        print("-------- add line -----")
        local lines = console.textArea.text:split( console.textArea.newLine )
        table.print( lines )
        if console.showLineNumber then
            line = "#"..console.lastLineNumber.." "..line
            console.lastLineNumber = console.lastLineNumber + 1
        end
        table.insert( lines, line )
        lines = table.reverse( lines )
        
        local newLines = {}
        for i = 1, console.height do
            if lines[ i ] ~= nil then
                table.insert( newLines, lines[ i ] )
            end
        end
        newLines = table.reverse( newLines )
        
        local text = table.concat( newLines, console.textArea.newLine )
        console.textArea.text = text
    end
end



------------------------------------------------

local consoleGO = nil

function cprint( ... )
    print( ... )
    
    if consoleGO == nil or consoleGO.inner == nil then    
        consoleGO = GameObject.Get( "Console" )
    end
    
    if consoleGO ~= nil then
        if consoleGO.console == nil then
            GUI.Console.New( consoleGO )
        end

        local line = ""
        
        for k, v in pairs ( {...} ) do
            if k == 1 then
                line = tostring(v)
            else
                line = line .. " , " .. tostring(v)
            end
        end
        
        consoleGO.console:AddLine( line )
    end
end


function Behavior:Update()
    -- toggle console
    if CS.Input.WasButtonJustPressed( "Console" ) then
        local zero = Vector3(0)
        local scale = self.gameObject.transform.localScale
        if scale == zero then
            self.gameObject.transform.localScale = self.gameObject.lastScale
        else
            print("hide")
            self.gameObject.lastScale = scale
            self.gameObject.transform.localScale = zero
        end
    end
end
