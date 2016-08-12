
-- Allow to save hud component's position when the windows is resized in order to automatically reposition them

Screen = { lastScreenSize = CS.Screen.GetSize() }


Daneel.modules[ "Screen" ] = Screen


function Screen.Load()
    local OriginalHudNew = GUI.Hud.New
    
    -- override GUI.Hud.New so that hud component update their position whevever the screen is resized
    function GUI.Hud.New( gameObject, params )
        local hud = OriginalHudNew( gameObject, params )
        
        hud.cameraGO:AddTag( "hud_camera" )
        
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
    function GUI.Hud.SetPosition(hud, position )
        hud.savedPosition = position
        OriginalSetPosition( hud, position )        
    end
end

local frameCount = 0

function Screen.Update() 
    frameCount = frameCount + 1
    
    if frameCount % 30 == 0 then
        -- detect that the screen has been resized
        local screenSize = CS.Screen.GetSize()
        if screenSize.x ~= Screen.lastScreenSize.x or screenSize.y ~= Screen.lastScreenSize.y then
        --if screenSize ~= Screen.lastScreenSize then
            Daneel.Event.Fire( "SaveHudPosition", { oldScreenSize = Screen.lastScreenSize } )
            print( "recreate origin go", screenSize, Screen.lastScreenSize )
            -- create a new origin GO for cameras
            for i, cameraGO in pairs( GameObject.GetWithTag( "hud_camera" ) ) do
                if cameraGO.hudOriginGO ~= nil then
                    -- should check that origin GO have no children
                    cameraGO.hudOriginGO:Destroy()
                end
                GUI.Hud.CreateOriginGO( cameraGO )
            end
            
            Daneel.Event.Fire( "OnScreenResized" )
            Screen.lastScreenSize = screenSize
            
            -- save the size
            Daneel.Storage.Save( "ProjectFPS_ScreenSize", screenSize )
        end
    end
end
