

function InitGametype( gt )
    if gt == nil then
        gt = "dm"
    end
    Game.gametype = gt
    
    local server = Client.server or LocalServer
    if server ~= nil then
        server.gametype = gt
    end
    
    -- remove all gameObject that don't have the current's gametype tag
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
    
    if Game.gametype == "dm" then
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


-- this function is useless
--[[
function SpawnPlayer( player ) -- done in Client:PlayerSpawned()
    if player == nil then
        player = Client.player
    end
    
    local spawnpos = GetSpawnPosition( player )
    
    -- remove level camera
    Level.levelSpawns[ player.team ].camera:Destroy()
    
    player.isSpawned = true -- do this before spawning the character so that the hud that is shon in the character Awake() is properly displayed
    local characterGO = GameObject.New( CharacterPrefab )
    characterGO.s.playerId = player.id
    characterGO.physics:WarpPosition( spawnPos )
    player.characterGO = characterGO
    return playerGO
end
]]

