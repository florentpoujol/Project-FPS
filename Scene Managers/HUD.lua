function Behavior:Awake()
    self.gameObject.parent.transform.position = Vector3(0,-999,0)
    
    Level.hud = GameObject.Get( "HUD" )
    Level.hud.Show = function()
        Level.menu.Hide()
        Level.hud.transform.localPosition = Vector3(0,0,-5)
        Level.hud.isDisplayed = true
    end
    Level.hud.Hide = function()
        Level.hud.transform.localPosition = Vector3(0,0,999)
        Level.hud.isDisplayed = false
    end
    Level.hud.Hide()
    
    
    -- in-game menu
    --
    local go = GameObject.Get( "Suicide" )
    go:AddTag( "mouseinput" )
    go.OnClick = function()
        -- player.Die()
        
        cprint( "player die" )
    end
    
    local go = GameObject.Get( "Change Team" )
    go:AddTag( "mouseinput" )
    go.OnClick = function()
        -- player.Die()
        
        cprint( "change team" )
    end
    
    local spawnGO = GameObject.Get( "Menu.Buttons.Spawn" )
    spawnGO:AddTag( "mouseinput" )
    spawnGO.OnClick = function()
        if not Client.data.isSpawned then
           --cprint( "spawn" )
           SpawnPlayer()
        end
    end
    
    local go = GameObject.Get( "Disconnect" )
    if Client.isConnected then
        go:AddTag( "mouseinput" )
        go.OnClick = function()
            cprint( "Disconnect from server" )
            Client.Disconnect()
        end
    else
        go.textRenderer.opacity = 0
    end
    
    Level.menu = GameObject.Get( "Menu" )
    Level.menu.Show = function()
        Level.hud.Hide()
        Level.menu.transform.localPosition = Vector3(0,0,-5)
        CS.Input.UnlockMouse()
        Level.menu.isDisplayed = true
        
        if Client.data.isSpawned then
            spawnGO.textRenderer.opacity = 0
        else
            spawnGO.textRenderer.opacity = 1
        end
    end
    Level.menu.Hide = function()
        Level.menu.transform.localPosition = Vector3(0,0,999)
        CS.Input.LockMouse()
        Level.menu.isDisplayed = false
    end
    Level.menu.Hide()
    
    
end


function Behavior:UpdateScoreBoard()
    
end


function Behavior:Update()
    if CS.Input.WasButtonJustPressed( "Escape" ) then
        if Level.hud.isDisplayed then
            Level.menu.Show()
        else
            Level.hud.Show()
        end
    end
end