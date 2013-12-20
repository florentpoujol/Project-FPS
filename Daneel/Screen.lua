
Screen = { lastScreenSize = CS.Screen.GetSize() }

if CS.DaneelModules == nil then
    CS.DaneelModules = {}
end
CS.DaneelModules[ "Screen" ] = Screen


function Screen.Load()

    -- override to allow to copy a Vector2 provided as parameter
    function Vector2.New(x, y)
        Daneel.Debug.StackTrace.BeginFunction("Vector2.New", x, y)
        local errorHead = "Vector2.New(x, y) : "
        local argType = Daneel.Debug.CheckArgType(x, "x", {"string", "number", "Vector2"}, errorHead)
        Daneel.Debug.CheckOptionalArgType(y, "y", {"string", "number"}, errorHead)
    
        if y == nil then y = x end
        local vector = setmetatable({ x = x, y = y }, Vector2)
        if argType == "Vector2" then
            vector.x = x.x
            vector.y = x.y
        end
        Daneel.Debug.StackTrace.EndFunction()
        return vector
    end

    local OriginalHudNew = GUI.Hud.New
    
    -- override GUI.Hud.New so that hud component update their position whevever the screen is resized
    function GUI.Hud.New( gameObject, params )
        local hud = OriginalHudNew( gameObject, params )
        
        -- before a new originGO is created
        hud.SaveHudPosition = function( data )
            -- should I force to save the position here ?
            -- (probably a lot of use cases where you need to/don't need to)
            -- (should save when saved postion is not relative or in percentage)
            if hud.savedPosition == nil then
                local position = hud.position
                -- transform in relative position
                local screenSize = data.oldScreenSize
                local diff = position - screenSize

                position.x = "s"..diff.x -- "s50" or "s-50"
                position.y = "s"..diff.y -- no need to add a + between s and the number, it works without it
                
                hud.savedPosition = position
            end
        end
        Daneel.Event.Listen( "SaveHudPosition", hud )
        
        -- after the new originGO has been created
        hud.OnScreenResized = function()
            if hud.savedPosition ~= nil then
                hud.position = hud.savedPosition
            end
        end
        Daneel.Event.Listen( "OnScreenResized", hud )
        -- SaveHudPosition and OnScreenResized are fired from Update() below
        
        return hud
    end
    
    
    
    
    local OriginalSetPosition = GUI.Hud.SetPosition
    -- override SetPosition to allow to set position relative to the screen size or in percentage
    function GUI.Hud.SetPosition(hud, position )
        hud.savedPosition = position
        --print("setposition", position)
        
        OriginalSetPosition( hud, GUI.Hud.FixPosition( position ) )
    end
end

local frameCount = 0

function Screen.Update() 
    frameCount = frameCount + 1
    
    if frameCount % 30 == 0 then
        -- detect that the screen has been resized
        local screenSize = CS.Screen.GetSize()
        if screenSize.x ~= Screen.lastScreenSize.x or screenSize.y ~= Screen.lastScreenSize.y then
            Daneel.Event.Fire( "SaveHudPosition", { oldScreenSize = Screen.lastScreenSize } )
            GUI.Config.originGO:Destroy()
            GUI.Awake() -- create a new GUI origin
            Daneel.Event.Fire( "OnScreenResized" )
            Screen.lastScreenSize = screenSize
            
            -- save the need size
            Daneel.Storage.Save( "ScreenSize", screenSize )
        end
    end
end
