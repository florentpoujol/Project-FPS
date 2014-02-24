
Gametype = {
    Config = {},
    defaultConfig = {
        timeLimit = 600, -- 10 minutes
        --roundLimit = 1,
        --scoreLimit = 10,
    },
    
    --defauldmConfig = {},
    --defaultdmConfig = {},
    
    roundEnded = false,
}

-- called from "Common Level Manager:Start()"
function Gametype.Init( gt )
    if gt == nil then
        gt = "dm"
    end
    Gametype.roundEnded = false
    
    local server = GetServer()
    Gametype.Config = table.merge( Gametype.defaultConfig, server.game[ gt ] ) -- server.game[ gt ] may be nil
    
    if LocalServer then -- server or offline
        local time = Gametype.Config.timeLimit
        
        Level.timerGO.updateTweener = Tween.Tweener( time, 0, time, {
            OnUpdate = function( tweener )
                Level.timerGO.Update( tweener.value ) -- set in HUD script
            end,
            updateInterval = 10, 
        } )
         
        if server.isOffline or IsServer then
            Level.timerGO.updateTweener.OnComplete = function()
                Gametype.OnRoundEnd()
            end
        end
    end
       
    -- remove all gameObject that don't have the current gametype tag
    for short, full in pairs( Gametypes ) do
        if short ~= gt then
            for i, go in pairs( GameObject.GetWithTag( short ) ) do
                if not go:HasTag( gt ) then
                    go:Destroy()
                end
            end
        end
    end

    --
    Level.spawns = {
        GameObject.GetWithTag( { "spawn", "team1", gt } ),
        GameObject.GetWithTag( { "spawn", "team2", gt } )
    }
        
    Level.levelSpawns = {
        GameObject.GetWithTag( { "levelspawn", "team1" } )[1],
        GameObject.GetWithTag( { "levelspawn", "team2" } )[1],
    }
    
    local team = 1
    if IsClient and Client.player then
        team = Client.player.team
    end
    Gametype.ResetLevelSpawn( team )
    
    if IsServer then
        -- On the server, the level spawn is also the game object with the "Camera Control" script, that is moved by the admin
        Level.levelSpawns[1]:AddComponent( "Game/Camera Control", {
            moveOriented = true,
            moveSpeed = 1, -- default = 0.2 = very slow on the big test map
        } )
    end
   
end


-- make sure the team's level spawn has a camera and remove the camera to the other team's level spawn
-- so that the player "spawn" in its level spawn
-- (the character is not spawned yet, but the player sees the level throught the camera on the level spawn)
function Gametype.ResetLevelSpawn( team )
    if team == nil then
        team = 1
    end
    local otherTeam = 2
    if team == 2 then
        otherTeam = 1
    end
    
    local spawn = Level.levelSpawns[ team ]
    if not spawn.camera then
        spawn:AddComponent( "Camera" )
    end
    
    spawn = Level.levelSpawns[ otherTeam ]
    if spawn.camera then
        spawn.camera:Destroy()
    end
    
    Level.hudCamera.Recreate()
end


-- Find a spawn point not too close to any player(depend on the team and game type)
-- Return the spawn game object
function Gametype.GetSpawn( team )   
    local argType = type( team )
    if argType == "table" then -- player
        team = team.team
    elseif argType == "nil" then
        if Client.player then
            team = Client.player.team
        else
            team = 1
        end
    end
    
    local spawns = Level.spawns[ team ]
    
    local gametype = Server.defaultConfig.game.gametype
    local server = GetServer()
    if server then
        gametype = server.game.gametype
    end
    
    if gametype == "dm" then
        spawns = table.merge( Level.spawns[1], Level.spawns[2] )
    end
         
    local spawnCount = #spawns
    if spawnCount < 1 then
        cprint( "SpawnPlayer() : spawnCount="..spawnCount, player.team )
        return
    end
    
    local characterPositions = {}
    for i, character in pairs( GameObject.GetWithTag( "character" ) ) do
        table.insert( characterPositions, character.transform.position )
    end
    
    local loopCount = 0
    local spawnPos = nil
    local spawnGO = nil
    
    -- find a spawn without another player too close
    repeat
        loopCount = loopCount + 1
        
        local rand = math.floor( math.randomrange( 1, spawnCount + 0.99 ) )
        
        spawnGO = spawns[ rand ]
        spawnPos = spawnGO.transform.position
        local tooClose = false
        
        if loopCount > spawnCount * 10 then
            break
            -- TODO : find the most isolated spawn
        end
        
        for i, characterPos in pairs( characterPositions ) do
            if Vector3.Distance( characterPos, spawnPos ) < 5 then
                tooClose = true
                break            
            end            
        end
    until not tooClose
    
    return spawnGO
end


function Gametype.OnRoundEnd()
    Gametype.roundEnded = true -- prevent player to spawn while waiting to 
    
    if LocalServer then 
        if not LocalServer.isOffline then
            ServerGO.networkSync:SendMessageToPlayers( "UpdateGameState", { roundEnded = true }, LocalServer.playerIds )
        end
        
        for id, player in pairs( LocalServer.playersById ) do
            if player.characterGO then
                player.characterGO.s:Die( -1 ) -- -1 to tell the function that this is the end of the round and that it must not inscrese the death count or display message
                -- the function will broadcast itself to the network to destroy the player
            end
        end
        
        -- force update of the timer
        Level.timerGO.updateTweener:Destroy()
        Level.timerGO.updateTweener = nil
          
    end

    -- force update of the timer
    Level.timerGO.Update( 0 ) 
    
    -- force update of the menu (already done from "Character Control:Die() for player who were spawned)
    Level.menu.Show()
    
    
    -- destroy all relevant game type object (nothing in DM or TDM)
    
    
    -- destroy all player
    
    -- force display of the menu, prevent them to 
    
end