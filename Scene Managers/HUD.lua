function Behavior:Awake()
    self.gameObject.parent.transform.position = Vector3(0,-999,0)
    GUI.Awake()
    -- the HUD Manager game object has to be on top of the herarchy of the hud because the HUD camera does not exist yet when the gui module is loaded but the "Hud Fixed" scripted behavior uses GUI.Hud.ToHudPosition()
    
    Level.hudCamera = GameObject.Get( "HUD Camera" )
    Level.hudCamera.Recreate = function()
        local orthoScale = Level.hudCamera.camera.orthographicScale
        Level.hudCamera.camera:Destroy()
        Level.hudCamera:AddComponent( "Camera" )
        Level.hudCamera.camera.projectionMode = "orthographic"
        Level.hudCamera.camera.orthographicScale = orthoScale
    end
    
    
    -- hud
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
    
    
    -- In-game menu
    local changeTeamGO = GameObject.Get( "Change Team" )
    changeTeamGO:AddTag( "mouseinput" )
    changeTeamGO.OnClick = function()
        -- player.Die()
        cprint( "change team" )
    end
    
    local spawnGO = GameObject.Get( "Menu.Buttons.Spawn" )
    spawnGO:AddTag( "mouseinput" )
    --[[spawnGO.OnClick = function()
        if not Client.player.isSpawned then
           --cprint( "spawn" )
           SpawnPlayer()
        end
    end]]
    
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
                    
                    CharacterScript:Die()
                end
            else
                spawnGO.textRenderer.text = "Spawn"
                spawnGO.OnClick = function()
                    if Client.isConnected then
                        ServerGO.networkSync:SendMessageToServer( "SetCharacterInput", { input = { spawnButtonClicked = true } } )
                        return
                    end
                    
                    ServerGO.client:SpawnPlayer()
                end
            end
        end
        
        Level.hud.Hide()
        Level.menu.transform.localPosition = Vector3(0,0,-5)
        if not LocalServer then
            CS.Input.UnlockMouse()
        end
        Level.menu.isDisplayed = true
        InputManager.AddTag( "menudisplayed" )
    end
    Level.menu.Hide = function()
        if CharacterScript ~= nil then
            CharacterScript.isLocked = false
        end
        
        Level.menu.transform.localPosition = Vector3(0,0,999)
        if not LocalServer then
            CS.Input.LockMouse()
        end
        Level.menu.isDisplayed = false
        InputManager.RemoveTag( "menudisplayed" )
    end
    --Level.menu.Show() -- in Start()
    
    
    -- scoreboard
    Level.scoreboard = GameObject.Get( "Scoreboard" )
    Level.scoreboard.Show = function()
        Level.scoreboard.transform.localPosition = Vector3(0,0,-4) -- -4 instead of -5 to put the scoreboard in front of the hud or menu
        Level.scoreboard.isDisplayed = true
        Level.scoreboard.Update()
    end
    Level.scoreboard.Hide = function()
        Level.scoreboard.transform.localPosition = Vector3(0,0,999)
        Level.scoreboard.isDisplayed = false
    end
    Level.scoreboard.Hide()
    
    local gametypeGO = Level.scoreboard:GetChild( "Gametype", true )
    gametypeGO.textRenderer.text = "Gametype : "..Gametypes[ Game.gametype ]
    
    local levelGO = Level.scoreboard:GetChild( "Level", true )
    levelGO.textRenderer.text = "Level : "..Scene.current.path
    
    local nameListGO = Level.scoreboard:GetChild( "Name.List", true )
    local kdListGO = Level.scoreboard:GetChild( "KD.List", true )
    --local scoreListGO = GameObject.Get( "Scoreboard.Score.List" )        
    
    Level.scoreboard.Update = function()
        -- update score board
        local server = LocalServer or Client.server
        if Level.scoreboard.isDisplayed and server then
            local playersByScore = {}
            
            for id, player in pairs( server.playersById ) do
                table.insert( playersByScore, table.merge( player ) )
            end
            
            table.sortby( playersByScore, "kills", "desc" ) -- big values first
            
            local nameListText = ""
            local kdListText = ""
                           
            if Game.gametype == "dm" then
                for i, player in ipairs( playersByScore ) do
                    local playerId = ""
                    if LocalServer then
                        playerId = " ("..player.id..") "
                    end
                    nameListText = nameListText..player.name..playerId..";"
                    kdListText = kdListText..player.kills.."/"..player.deaths..";"
                end
            else
                nameListText = "----- Team 1 -----;"
                kdListText = ";"
                for i, player in ipairs( playersByScore ) do
                    if player.team == 1 then
                        nameListText = nameListText..player.name..";"
                        kdListText = kdListText..player.kills.."/"..player.deaths..";"
                    end
                end
                
                nameListText = nameListText..";----- Team 2 -----;"
                kdListText = ";;"
                for i, player in ipairs( playersByScore ) do
                    if player.team == 2 then
                        nameListText = nameListText..player.name..";"
                        kdListText = kdListText..player.kills.."/"..player.deaths..";"
                    end
                end
            end
            
            if nameListGO.textArea then
                nameListGO.textArea.text = nameListText
                kdListGO.textArea.text = kdListText
            end  
        end
    end
      
    
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
    -- in Start to wait for the input nd textArea to be created
    local tutoGO = GameObject.Get( "Tuto" )
    tutoGO.textArea.areaWidth = (CS.Screen.GetSize().x-100).."px"
    
    local commonText = "Press Escape to toggle menu;Press T to write in the tchat (Enter to send, Escape to unfocus);"
    local playerText = commonText.."Move like in any oter FPS;"
    local serverText = commonText.."Move with ZQ/WASD/Arrows; Toggle mouse cursor with right click;; Send commands via the tchat :;/kick [player id] (to kick player);/ip (to get your ip);/stopserver (to stop the server and go back to the server manager);/loadscene [scene path] [gametype] (to load the provided menu/level with the provided gametype);"
    if LocalServer then
        tutoGO.textArea.text = serverText
    else
        tutoGO.textArea.text = playerText
    end
    
    Level.menu.Show()
    
    
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
    
    if CS.Input.WasButtonJustPressed( "Tab" ) then
        Level.scoreboard.Show()
    end
    
    if CS.Input.WasButtonJustReleased( "Tab" ) then
        Level.scoreboard.Hide()
    end
end