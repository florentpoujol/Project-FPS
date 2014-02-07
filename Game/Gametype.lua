
Gametype = {
    Config = {},
    defaultConfig = {
        timeLimit = 600, -- 10 minutes
        --roundLimit = 1,
        --scoreLimit = 10,
    },
    
    --defauldmConfig = {},
    --defaultdmConfig = {},
}

-- called from "Common Level Manager:Start()"
function Gametype.Init( gt )
    if gt == nil then
        gt = "dm"
    end
    
    local server = GetServer()
    Gametype.Config = table.merge( Gametype.defaultConfig, server.game[ gt ] ) -- server.game[ gt ] may be nil
    
    local time = Gametype.Config.timeLimit

    Level.timerGO.updateTweener = Tween.Tweener( time, 0, time, {
        OnUpdate = function( tweener )
            Level.timerGO.Update( tweener.value )
        end,
        updateInterval = 10, 
    } )
     
    if server.isOffline or IsServer then
        Level.timerGO.updateTweener.OnComplete = function()
            print("timer complete")
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
    --print("Init game type", gt )

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


-- make sure the team's level spawn ahs a camera and remove the camera to the other team's level spawn
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
