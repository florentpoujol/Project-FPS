
-- The Console module adds the GUI.Console and GUI.ScrollableText components

-- GUI.Console is an overlay of a textarea where you can add text line by line with AddLine(), the new lines being shown at the bottom
-- GUI.ScrollableText is an overlay of a textArea which may not show all the lines and let the user browse through the text (change the displayed lines via mouse input)

Console = {}
if CS.DaneelModules == nil then
    CS.DaneelModules = {}
end  
CS.DaneelModules[ "Console" ] = Console


function Console.Load()
    GUI.Console = {}
    GUI.Console.__index = GUI.Console
    
    Daneel.Config.componentObjects.Console = GUI.Console
    table.insert( Daneel.Config.componentTypes, "Console" )
    Daneel.Config.objects.Console = GUI.Console   
    
    Daneel.SetComponents( { Console = GUI.Console } )
    
    function GUI.Console.New( gameObject, params )
        local console = setmetatable( {}, GUI.Console )
        gameObject.console = console
        
        console.textArea = gameObject.textArea
        if console.textArea == nil then
            console.textArea = GUI.TextArea.New( gameObject, { text = "" } )
        end
        console.height = 10 -- 10 lines
        console.showLineNumber = true
        console.lastLineNumber = 0
        console.filter = nil -- function which gets the line as argument and must return the line or false or nil (in which cases, the line is not added to the console)
        -- this allows to "listen" for commands (or slang) in the lines.
        
        if params ~= nil then
            console:Set( params )
        end
        
        return console
    end

    function GUI.Console.AddLine( console, line )
        if console.filter ~= nil then
            line = console.filter( line )
            if not line then
                return
            end
        end
        
        local lines = console.textArea.text:split( console.textArea.newLine )
        
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
    
    
    -----------
    
    GUI.ScrollableText = {}
    GUI.ScrollableText.__index = GUI.ScrollableText

    Daneel.Config.componentObjects.ScrollableText = GUI.ScrollableText
    table.insert( Daneel.Config.componentTypes, "ScrollableText" )
    Daneel.Config.objects.ScrollableText = GUI.ScrollableText
    
    Daneel.SetComponents( { ScrollableText = GUI.ScrollableText } )
    
function GUI.ScrollableText.New( gameObject, params )
    local scrollableText = GUI.TextArea.New( gameObject, { text = "scrollable <br> text" } )
    setmetatable( scrollableText, GUI.ScrollableText ) -- the function of the textArea are not accessible anymore since the metatable has been replaced
    -- I have to call Daneel.Utilities.AllowDynamicGetterAndSetters() myself to allow GUI.ScrollableText to be a "child" of GUI.TextArea
    gameObject.scrollableText = scrollableText
    
    scrollableText.Height = 10 -- 10 lines
    scrollableText.ScrollPosition = 1
    
    if params ~= nil then
        scrollableText:Set( params )
    end

    scrollableText.OnWheelUp = function()
        scrollableText:SetScrollPosition( -1, true ) -- could have a wheelIncrement param in the config
    end

    scrollableText.OnWheelDown = function()
        scrollableText:SetScrollPosition( 1, true )
    end
    
    return scrollableText
end

function GUI.ScrollableText.SetScrollPosition( scrollableText, position, isRelative )
    if isRelative then
       position = scrollableText.ScrollPosition + position
    end
    if position < 1 then
        position = 1
    end
    local maxPosition = #scrollableText.lines - scrollableText.Height
    if position > maxPosition then
        position = maxPosition
    end
    
    --print(position)
    local oldPosition = scrollableText.ScrollPosition
    scrollableText.ScrollPosition = position
    
    if oldPosition ~= position then
        scrollableText:SetText()
    end
end

-- text argument can be a string, a table (the lines) or nil (the saved lines)
function GUI.ScrollableText.SetText( textArea, text )
    --Daneel.Debug.StackTrace.BeginFunction( "GUI.TextArea.SetText", textArea, text )
    --local errorHead = "GUI.TextArea.SetText( textArea, text ) : "
    --Daneel.Debug.CheckArgType( textArea, "textArea", "TextArea", errorHead )
    --Daneel.Debug.CheckOptionnalArgType( text, "text", {"string", "table"}, errorHead )
    --print("GUI.TextArea.SetText( textArea, text ) : ", textArea, text, textArea.newLine, textArea.ScrollPosition, textArea.Height )
    
    local lines = {}
    local textAreaScale = textArea.gameObject.transform:GetLocalScale()
    local argType = type( text )
    
    if argType == "string" then
        textArea.Text = text

        lines = { text }
        if textArea.newLine ~= "" then
            lines = string.split( text, textArea.NewLine )
        end

        -- areaWidth is the max length in units of each line
        local areaWidth = textArea.AreaWidth
        if areaWidth ~= nil and areaWidth > 0 then
            -- cut the lines based on their length
            local tempLines = table.copy( lines )
            lines = {}

            for i = 1, #tempLines do
                local line = tempLines[i]

                if textArea.textRuler:GetTextWidth( line ) * textAreaScale.x > areaWidth then
                    line = string.totable( line )
                    local newLine = {}

                    for j, char in ipairs( line ) do
                        table.insert( newLine, char )

                        if textArea.textRuler:GetTextWidth( table.concat( newLine ) ) * textAreaScale.x > areaWidth then
                            table.remove( newLine )
                            table.insert( lines, table.concat( newLine ) )
                            newLine = { char }

                            if not textArea.WordWrap then
                                newLine = nil
                                break
                            end
                        end
                    end

                    if newLine ~= nil then
                        table.insert( lines, table.concat( newLine ) )
                    end
                else
                    table.insert( lines, line )
                end
            end -- end loop on lines
        end
    elseif argType == "table" then -- type table = lines
        lines = text
    else -- nil
        lines = textArea.lines
    end

    textArea.lines = lines
    local linesCount = #lines

    lines = {}
    for i, line in ipairs( textArea.lines ) do
        if i >= textArea.ScrollPosition and i <= textArea.ScrollPosition + textArea.Height then
            table.insert( lines, line )
        end
    end

    local lineRenderers = textArea.lineRenderers
    local lineRenderersCount = #lineRenderers
    local lineHeight = textArea.LineHeight / textAreaScale.y
    local gameObject = textArea.gameObject
    local textRendererParams = {
        font = textArea.Font,
        alignment = textArea.Alignment,
        opacity = textArea.Opacity,
    }

    -- calculate position offset of the first line based on vertical alignment and number of lines
    -- the offset is decremented by lineHeight after every lines
    local offset = -lineHeight / 2 -- verticalAlignment = "top"
    if textArea.VerticalAlignment == "middle" then
        offset = lineHeight * linesCount / 2 - lineHeight / 2
    elseif textArea.VerticalAlignment == "bottom" then
        offset = lineHeight * linesCount - lineHeight / 2
    end

    for i, line in ipairs( lines ) do
        textRendererParams.text = line

        if lineRenderers[i] ~= nil then
            lineRenderers[i].gameObject.transform:SetLocalPosition( Vector3:New( 0, offset, 0 ) )
            lineRenderers[i]:Set( textRendererParams )
        else
            local newLineGO = GameObject.New( "TextArea" .. textArea.id .. "-Line" .. i, {
                parent = gameObject,
                transform = {
                    localPosition = Vector3:New( 0, offset, 0 ),
                    localScale = Vector3:New(1),
                },
                textRenderer = textRendererParams,
                
                tags = { "guiComponent" },

                OnWheelUp = function()
                    textArea:SetScrollPosition( 1, true ) -- could have a wheelIncrement param in the config
                end,

                OnWheelDown = function()
                    textArea:SetScrollPosition( -1, true )
                end,
            })

            table.insert( lineRenderers, newLineGO.textRenderer )
        end

        offset = offset - lineHeight 
    end

    -- this new text has less lines than the previous one
    if lineRenderersCount > linesCount then
        for i = linesCount + 1, lineRenderersCount do
            lineRenderers[i]:SetText( "" )
        end
    end

    Daneel.Event.Fire( textArea, "OnUpdate", textArea )

    Daneel.Debug.StackTrace.EndFunction()
end
end





------------------------------------------------
-- cprint - Console print
-- automatically print on screen via the GUI.Console component of a "Console" or "Tchat" game object (if one exists in the scene)

local consoleGO = nil

function cprint( ... )
    print( ... )
      
    if consoleGO == nil or consoleGO.inner == nil then    
        consoleGO = GameObject.Get( "Console" )
        
        if consoleGO == nil then
            consoleGO = GameObject.Get( "Tchat" )
        end
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


function Behavior:Update() -- only used in server browser
    -- toggle console
    if CS.Input.WasButtonJustPressed( "Console" ) then -- OemPlus +=}
        local zero = Vector3(0)
        local scale = self.gameObject.transform.localScale
        if scale == zero then
            self.gameObject.transform.localScale = self.gameObject.lastScale
        else
            self.gameObject.lastScale = scale
            self.gameObject.transform.localScale = zero
        end
    end
end


------------------------------------------------
-- Alert - notification area
-- provide a way to notify player (give him feedback) of something happening
-- while in-game, this can be done via the tchat instead

Alert = {
    gameObject = nil,
    tweener = nil,
    messages = {},
}

function Alert.SetText( text, time )
    if Alert.gameObject == nil or Alert.gameObject.inner == nil then
        Alert.gameObject = GameObject.Get( "Alert" )
    end
    
    if Alert.gameObject == nil then
        return
    end
    
    if time == nil then
        time = 3 -- 3 seconds
    end
    
    --[[if Alert.tweener ~= nil then
        -- stores the text for later
        table.insert( Alert.messages, { text = text, time = time } )
        return
    end]]
    if Alert.tweener ~= nil then
        Alert.tweener:Destroy()
    end
    
    Alert.gameObject.child.textRenderer.text = text
    Alert.gameObject.hud.layer = 2
    
    if time > 0 then
        Alert.tweener = Tween.Timer( time, function()
            -- OnComplete callback
            if #Alert.messages > 0 then
                local msg = table.remove( Alert.messages, 1 )
                Alert.tweener = nil
                Alert.SetText( msg.text, msg.time )
            else
                Alert.Hide()            
            end
        end )
    end
end

function Alert.Hide()
    --cprint("Alert hide")
    if Alert.gameObject == nil or Alert.gameObject.inner == nil then
        Alert.gameObject = GameObject.Get( "Alert" )
    end
    if Alert.gameObject == nil then
        return
    end
    
    Alert.tweener:Destroy()
    Alert.tweener = nil
    Alert.gameObject.hud.layer = -50
end

