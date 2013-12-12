
function InitGametype( gt )
    if gt == nil then
        gt = "dm"
    end
    Game.gametype = gt
    
    local server = Client.server or LocalServer
    if server ~= nil then
        server.gametype = gt
    end
    
    -- remove all gameObject than don't have the current's gametype tag
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
        GameObject.GetWithTag( { "spawn", "team1" } ),
        GameObject.GetWithTag( { "spawn", "team2" } )
    }
    
    Level.levelSpawns = {
        GameObject.GetWithTag( { "levelspawn", "team1" } )[1],
        GameObject.GetWithTag( { "levelspawn", "team2" } )[1],
    }
    
    -- remove the camera component on the other team's level spawn
    -- so that the player "spawn" in its level spawn
    -- (the character is not spawned yet, but the player sees the level throught the camera on the level spawn)
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



function SpawnPlayer()
    local spawns = Level.spawns[ Client.player.team ]
    local spawnCount = #spawns
    if spawnCount < 1 then
        cprint( "SpawnPlayer() : spawnCount="..spawnCount, Client.player.team )
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
    
    -- remove level camera
    Level.levelSpawns[ Client.player.team ].camera:Destroy()
    
    -- spawn the playable character
    Client.player.isSpawned = true -- do this before spawning the character so that the hud that is shon in the character Awake() is properly displayed
    local playerGO = GameObject.New( CharacterPrefab )
    playerGO.physics:WarpPosition( spawnPos )
    
end

