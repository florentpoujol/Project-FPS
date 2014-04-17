
-- Spawned from "Common Level Manager:Awake()"

function Behavior:Awake()
    self.gameObject.parent.transform.position = Vector3(0,-999,0)
    GUI.Awake()
    -- the HUD Manager game object has to be on top of the herarchy of the hud because the HUD camera does not exist yet when the gui module is loaded but the "Hud Fixed" scripted behavior uses GUI.Hud.ToHudPosition()
    
    local server = GetServer()
    
    Level.hudCameraGO = GameObject.Get( "HUD Camera" )
    Level.hudCamera = Level.hudCameraGO
    Level.hudCameraGO.Recreate = function()
        local orthoScale = Level.hudCameraGO.camera.orthographicScale
        Level.hudCameraGO.camera:Destroy()
        Level.hudCameraGO:AddComponent( "Camera" )
        Level.hudCameraGO.camera.projectionMode = "orthographic"
        Level.hudCameraGO.camera.orthographicScale = orthoScale
    end
    
    
    ------------------------------------------------------
    -- player HUD
    
    
    Level.hud = GameObject.Get( "Player HUD" )
    Level.hud.Show = function()
        Level.menu.Hide()
                
        if Client.player.isSpawned then
            Level.hud.transform.localPosition = Vector3(0,0,-20) -- menu is at -10
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

    -- timer
    Level.timerGO = GameObject.Get( "Timer" )
    Level.timerGO.Update = function( time )
        local minutes = math.floor( time/60 )
        if minutes < 10 then
            minutes = "0"..minutes
        end
        local seconds = math.round( time % 60 )
        if seconds < 10 then
            seconds = "0"..seconds
        end
        Level.timerGO.textRenderer.text = minutes..":"..seconds    
    end
    -- Update tweener created in Gametype.StartRound()
    
       
    
    ---------------------------------------------------------------------
    -- In-game menu

    local changeTeamGO = GameObject.Get( "Change Team" )
    if server.game.gametype ~= "dm" then
        changeTeamGO:AddTag( "mouseinput" )
        changeTeamGO.OnClick = function()
            if Client.isConnected then
                ServerGO.networkSync:SendMessageToServer( "SetCharacterInput", { input = { changeTeamButtonClicked = true } } )
            else -- offline, is never the server as the button does not exists on the server
                ServerGO.client:ChangePlayerTeam( { playerId = Client.player.id } )
            end
        end
    else
        changeTeamGO:Destroy()
        changeTeamGO = nil
    end
    
    local spawnGO = GameObject.Get( "Menu.Buttons.Spawn" )
    spawnGO:AddTag( "mouseinput" )
    
    local disconnectGO = GameObject.Get( "Disconnect" )
    disconnectGO:AddTag( "mouseinput" )
    disconnectGO.OnClick = function()
        if Client.player.isSpawned then
            CharacterScript = nil
            Client.player.characterGO = nil
            Client.player.isSpawned = false
        end
            
        if Client.isConnected then
            Client.Disconnect() -- loads "Menus/Server Browser"
        else -- offline
            Scene.Load( "Menus/Main Menu" )
        end
    end
    
    if not Client.isConnected then
        disconnectGO.textRenderer.text = "Exit to main menu"
    end
    
    
    
    -- tutoGO is handled in Start()

    Level.menu = GameObject.Get( "Menu" )
    Level.menu.Show = function()
        -- lock the player
        if CharacterScript ~= nil then
            CharacterScript.isLocked = true
        end
    
        -- update buttons
        if not IsServer(true) then
            if not Gametype.roundEnded then
                if Client.player.isSpawned then
                    -- hide change team button
                    changeTeamGO.textRenderer.text = ""
                    
                    spawnGO.textRenderer.text = "Suicide"
                    spawnGO.OnClick = function()
                        if not Gametype.roundEnded then
                            if Client.isConnected then
                                ServerGO.networkSync:SendMessageToServer( "SetCharacterInput", { input = { spawnButtonClicked = true } } )
                            else
                                CharacterScript:Die( Client.player.id )
                            end
                        end
                    end
                else
                    changeTeamGO.textRenderer.text = "Change Team"
                    
                    spawnGO.textRenderer.text = "Spawn"
                    spawnGO.OnClick = function()
                        if Client.isConnected then
                            ServerGO.networkSync:SendMessageToServer( "SetCharacterInput", { input = { spawnButtonClicked = true } } )
                        else
                            ServerGO.client:SpawnPlayer()
                        end
                    end
                end
            else
                changeTeamGO.textRenderer.text = ""
                spawnGO.textRenderer.text = ""
            end
            
            CS.Input.UnlockMouse()
        end
        
        Level.hud.Hide()
        Level.menu.transform.localPosition = Vector3(0,0,-10) -- hud is at -20
        
        Level.menu.isDisplayed = true
        InputManager.AddTag( "menudisplayed" )
    end
    Level.menu.Hide = function()
        if CharacterScript ~= nil then
            CharacterScript.isLocked = false
        end
        
        Level.menu.transform.localPosition = Vector3(0,0,999)
        if not IsServer(true) then
            CS.Input.LockMouse()
        end
        Level.menu.isDisplayed = false
        InputManager.RemoveTag( "menudisplayed" )
    end
    --Level.menu.Show() -- in Start()
    
    
    ------------------------------------------------------------------------
    -- Scoreboard
    
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
    gametypeGO.textRenderer.text = "Gametype : "..GametypeNames[ server.game.gametype ]
    
    local levelGO = Level.scoreboard:GetChild( "Level", true )
    levelGO.textRenderer.text = "Level : "..Scene.current.path
    
    local nameListGO = Level.scoreboard:GetChild( "Name.List", true )
    local kdListGO = Level.scoreboard:GetChild( "KD.List", true )
    local scoreListGO = Level.scoreboard:GetChild( "Score.List", true )        
    
    Level.scoreboard.Update = function()
        -- update score board
        if Level.scoreboard.isDisplayed then
            local playersByScore = {}
            
            for id, player in pairs( server.playersById ) do
                table.insert( playersByScore, table.copy( player ) )
            end
            
            table.sortby( playersByScore, "kills", "desc" ) -- "desc" = big values first
            
            local nameListText = ""
            local kdListText = ""
            local scoreListText = ""
                           
            if server.game.gametype == "dm" then
                for i, player in ipairs( playersByScore ) do
                    local playerId = ""
                    if IsServer(true) then
                        playerId = " ("..player.id..") "
                    end
                    nameListText = nameListText..player.name..playerId..";"
                    kdListText = kdListText..player.kills.."/"..player.deaths..";"
                    scoreListText = scoreListText..player.score..";"
                end
            else
                nameListText = "----- Team 1 -----;"
                kdListText = " ;" -- leave the space at the beginning so that the newLine char is taken into account (to be fixed in TextAreas)
                scoreListText = " ;"
                for i, player in ipairs( playersByScore ) do
                    if player.team == 1 then
                        nameListText = nameListText..player.name..";"
                        kdListText = kdListText..player.kills.."/"..player.deaths..";"
                        scoreListText = scoreListText..player.score..";"
                    end
                end
                
                nameListText = nameListText..";----- Team 2 -----;"
                kdListText = kdListText..";;"
                scoreListText = scoreListText..";;"
                for i, player in ipairs( playersByScore ) do
                    if player.team == 2 then
                        nameListText = nameListText..player.name..";"
                        kdListText = kdListText..player.kills.."/"..player.deaths..";"
                        scoreListText = scoreListText..player.score..";"
                    end
                end
            end
            
            if nameListGO.textArea then
                nameListGO.textArea.text = nameListText
                kdListGO.textArea.text = kdListText
                scoreListGO.textArea.text = scoreListText
            end  
        end
    end
    
    
    ------------------------------------------------------
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
    
    if IsServer(true) then
        if changeTeamGO then
            changeTeamGO:Destroy()
        end
        spawnGO:Destroy()
        disconnectGO:Destroy()
        -- Server admin use the tchat to control things
    end
end


function Behavior:Start()
    -- in Start to wait for the input and textArea to be created
    
    -- Tuto
    local tutoGO = GameObject.Get( "Tuto" )
    if not IsServer(true) then
        tutoGO.hud.position = Vector2( "30%", 10 )
    end
    tutoGO.textArea.areaWidth = (CS.Screen.GetSize().x - tutoGO.hud.position.x - 10).."px"
    
    local commonText = "Press Escape to toggle menu;Press Tab to see the score board;Press T to write in the tchat (Enter to send, Escape to unfocus);"
    local playerText = commonText.."Move like in any oter FPS;"
    local serverText = commonText.."Move with ZQ/WASD/Arrows; Toggle mouse cursor with right click;; Send commands via the tchat :;/kick [player id] (to kick player);/ip (to get your ip);/stopserver (to stop the server and go back to the server manager);/loadscene [scene path] [gametype] (to load the provided menu/level with the provided gametype);Put double quotes (\") arond the scene path if it has spaces in it;/reloadscene to reload the current scene with same gametype;/settime [time in seconds] (to set the remaining time. Once it reached zero you have to change or reload the scene)"
    
    if IsServer(true) then
        tutoGO.textArea.text = serverText
    else
        tutoGO.textArea.text = playerText
    end
    
    Level.menu.Show()
    
    
    -- Chat
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
