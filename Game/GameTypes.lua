

function InitGametype( gt )
    if gt == nil then
        gt = "dm"
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
    
    -- remove the camera component on the other team's level spawn
    -- so that the player "spawn" in its level spawn
    -- (the character is not spawned yet, but the player sees the level throught the camera on the level spawn)
    --
    -- On the server, the level spawn is also the game object with the "Camera Control" script, that is moved by the admin
    local serverAdminGO = nil
    
    for i, gameObject in pairs( GameObject.GetWithTag( "levelspawn" ) ) do
        if not gameObject:HasTag( "team"..Client.player.team ) then
            --cprint("destroy camera on go", Client.data.team, gameObject )
            gameObject.camera:Destroy()
        else
            serverAdminGO = gameObject
        end
    end
    
    if LocalServer then
        serverAdminGO:AddComponent( "Game/Camera Control", {
            moveOriented = true,
            moveSpeed = 1, -- default = 0.2 = very slow on the big test map
        } )
    end
end


function GetSpawnPosition( player )
    if player == nil then
        player = Client.player
    end
    
    local spawns = Level.spawns[ player.team ]
    
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
    
    -- find a spawn without another player too close
    repeat
        loopCount = loopCount + 1
        
        local rand = math.floor( math.randomrange( 1, spawnCount + 0.99 ) )
        
        spawnPos = spawns[ rand ].transform.position
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
    
    if spawnPos == nil then
        spawnPos = Vector3(0)
    end
    
    return spawnPos
end

