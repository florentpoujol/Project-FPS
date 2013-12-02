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
    Level.menu = GameObject.Get( "Menu" )
    Level.menu.Show = function()
        Level.hud.Hide()
        Level.menu.transform.localPosition = Vector3(0,0,-5)
        CS.Input.UnlockMouse()
        Level.menu.isDisplayed = true
    end
    Level.menu.Hide = function()
        Level.menu.transform.localPosition = Vector3(0,0,999)
        CS.Input.LockMouse()
        Level.menu.isDisplayed = false
    end
    Level.menu.Hide()
    
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
    
    local go = GameObject.Get( "Spawn" )
    go:AddTag( "mouseinput" )
    go.OnClick = function()
        if not Client.isSpawned then
           cprint( "spawn" )
           SpawnPlayer()
        end
    end
    
    local go = GameObject.Get( "Disconnect" )
    go:AddTag( "mouseinput" )
    go.OnClick = function()
        cprint( "Disconnect from server" )
        Client.Disconnect()
    end
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