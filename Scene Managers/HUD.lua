function Behavior:Awake()
    self.gameObject.parent.transform.position = Vector3(0,-999,0)
    GUI.Awake()
    
    Level.hudCamera = GameObject.Get( "HUD Camera" )
    Level.hudCamera.Recreate = function()
        local orthoScale = Level.hudCamera.camera.orthographicScale
        Level.hudCamera.camera:Destroy()
        Level.hudCamera:AddComponent( "Camera" )
        Level.hudCamera.camera.projectionMode = "orthographic"
        Level.hudCamera.camera.orthographicScale = orthoScale
    end
    
    Level.hud = GameObject.Get( "HUD" )
    Level.hud.Show = function()
        Level.menu.Hide()
        
        if Client.player.isSpawned then
            Level.hud.transform.localPosition = Vector3(0,0,-5)
            
        end
        Level.hud.isDisplayed = true
        InputManager.AddTag( "huddisplayed" )
    end
    Level.hud.Hide = function()
        Level.hud.transform.localPosition = Vector3(0,0,999)
        Level.hud.isDisplayed = false
        InputManager.RemoveTag( "huddisplayed" )
    end
    Level.hud.Hide()
    
    
    -- in-game menu   
    local changeTeamGO = GameObject.Get( "Change Team" )
    changeTeamGO:AddTag( "mouseinput" )
    changeTeamGO.OnClick = function()
        -- player.Die()
        
        cprint( "change team" )
    end
    
    local spawnGO = GameObject.Get( "Menu.Buttons.Spawn" )
    spawnGO:AddTag( "mouseinput" )
    spawnGO.OnClick = function()
        if not Client.player.isSpawned then
           --cprint( "spawn" )
           SpawnPlayer()
        end
    end
    
    local disconnectGO = GameObject.Get( "Disconnect" )
    disconnectGO:AddTag( "mouseinput" )
    disconnectGO.OnClick = function()
        Client.Disconnect()
        Scene.Load( "Menus/Main Menu" )
    end
    
    if not Client.isConnected then
        disconnectGO.textRenderer.text = "Exit to main menu"
    end
    
    
    Level.menu = GameObject.Get( "Menu" )
    Level.menu.Show = function()
        -- lock the player
        if CharacterScript ~= nil then
            CharacterScript.isLocked = true
        end
    
    
        -- update buttons
        if not LocalServer then
            if Client.player.isSpawned then
                spawnGO.textRenderer.text = "Suicide"
                spawnGO.OnClick = function()
                    if Client.isConnected then
                        ServerGO.networkSync:SendMessageToServer( "SetCharacterInput", { input = { spawnButtonClicked = true } } )
                        return
                    end
                        
                    if Client.player.isSpawned then
                       CharacterScript:Die()
                    end
                end
            else
                spawnGO.textRenderer.text = "Spawn"
                spawnGO.OnClick = function()
                    if Client.isConnected then
                        ServerGO.networkSync:SendMessageToServer( "SetCharacterInput", { input = { spawnButtonClicked = true } } )
                        return
                    end
                    
                    if not Client.player.isSpawned then
                       --cprint( "spawn" )
                       SpawnPlayer() -- in gametype script
                    end
                end
            end
        end
        
        -- update score board
        
        
        Level.hud.Hide()
        Level.menu.transform.localPosition = Vector3(0,0,-5)
        CS.Input.UnlockMouse()
        Level.menu.isDisplayed = true
        InputManager.AddTag( "menudisplayed" )        
    end
    Level.menu.Hide = function()
        if CharacterScript ~= nil then
            CharacterScript.isLocked = false
        end
        
        Level.menu.transform.localPosition = Vector3(0,0,999)
        CS.Input.LockMouse()
        Level.menu.isDisplayed = false
        InputManager.RemoveTag( "menudisplayed" )
    end
    Level.menu.Show()
    
    
    -- Tchat
    -- use the in-game tchat as Console and Alert
    
    local tchat = GameObject.Get( "Tchat Origin" )
    tchat.Show = function()
        tchat.transform.localPosition = Vector3(0,0,0)
        tchat.isDisplayed = true
    end
    tchat.Hide = function()
        tchat.transform.localPosition = Vector3(0,0,999)
        tchat.isDisplayed = false        
    end
    tchat.Show()
    
    local tchatToggle = GameObject.Get( "Tchat Toggle" )
    tchatToggle:AddTag( "mouseinput" )
    tchatToggle.OnClick = function()
        if tchat.isDisplayed then
            tchat.Hide()
        else
            tchat.Show()
        end
    end
    
    
    if LocalServer then
        changeTeamGO:Destroy()
        spawnGO:Destroy()
        disconnectGO:Destroy()
        
        -- Server admin use the tchat to control things
    end
end

function Behavior:Start()
    -- in Start to wait fr the input to be created
    
    local tchatGO = GameObject.Get( "Tchat" )
    local inputGO = tchatGO.child
    inputGO.child.modelRenderer.opacity = 0.2
    local defaultText = inputGO.textRenderer.text
    
    inputGO.input.OnFocus = function( input )
        if input.isFocused then
            input.gameObject.child.modelRenderer.opacity = 0.5
            InputManager.AddTag( "tchatfocused" )
        else
            input.gameObject.child.modelRenderer.opacity = 0.2
            InputManager.RemoveTag( "tchatfocused" )
        end
    end

end

function Behavior:Update()
    if InputManager.WasButtonJustReleased( "Escape", "tchatfocused", false ) then
        if Level.hud.isDisplayed then
            Level.menu.Show()
        else
            Level.hud.Show()
        end
    end
end