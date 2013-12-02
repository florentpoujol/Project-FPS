
Screen = { lastScreenSize = CS.Screen.GetSize() }

if CS.DaneelModules == nil then
    CS.DaneelModules = {}
end
CS.DaneelModules[ "Screen" ] = Screen


function Screen.Load()
    local OriginalHudNew = GUI.Hud.New
    
    -- override GUI.Hud.New so that hud component update their position whevever the screen is resized
    function GUI.Hud.New( gameObject, params )
        local hud = OriginalHudNew( gameObject, params )
        
        -- before a new originGO is created
        hud.SaveHudPosition = function()
            hud.savedPosition = hud.position
        end
        Daneel.Event.Listen( "SaveHudPosition", hud )
        
        -- after the new originGO has been created
        hud.OnScreenResized = function()
            if hud.savedPosition ~= nil then
                hud.position = hud.savedPosition
            end
        end
        Daneel.Event.Listen( "OnScreenResized", hud )
        
        return hud
    end
end

local frameCount = 0

function Screen.Update() 
    frameCount = frameCount + 1
    
    if frameCount % 30 == 0 then
        -- detect that the screen has been resized
        local screenSize = CS.Screen.GetSize()
        if screenSize.x ~= Screen.lastScreenSize.x or screenSize.y ~= Screen.lastScreenSize.y then
            Daneel.Event.Fire( "SaveHudPosition" )
            GUI.Config.originGO:Destroy()
            GUI.Awake() -- create a new GUI origin
            Daneel.Event.Fire( "OnScreenResized" )
            Screen.lastScreenSize = screenSize
        end
    end
end
