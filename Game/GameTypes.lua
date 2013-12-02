
function InitGameType( gt )
    if gt == nil then
        gt = "dm"
    end
    Game.gametype = gt
    
    for short, full in pairs( GameTypes ) do
        if short ~= gt then
            -- removed all gameObject than have a tag other than the current gt's tag
            for i, go in pairs( GameObject.GetWithTag( short ) ) do
                if not go:HasTag( gt ) then
                    go:Destroy()
                end
            end
        end
    end

    
    -- actually just remove the camera component on the other team's level spawn
    -- so that the player "spawn" in its level spawn
    -- (the character is not spawned yet, but the player sees the level throught the camera on the level spawn)
    for i, gameObject in pairs( GameObject.GetWithTag( "levelspawn" ) ) do
        if not gameObject:HasTag( "team"..Client.data.team ) then
            --cprint("destroy camera on go", gameObject )
            --gameObject.camera:Destroy()
        end
    end
    
    Level.menu.Show()
    
    --
    Level.spawns = {
        GameObject.GetWithTag( { "spawn", "team1" } ),
        GameObject.GetWithTag( { "spawn", "team2" } )
    }
    
    print("test mouse input")
    for i, go in pairs (GameObject.GetWithTag( "mouseinput" )) do
        print(go, go.modelRenderer)
        if go.modelRenderer ~= nil then
        print(go.modelRenderer.model)
       end
    end
       print("test mouse input")
end



function SpawnPlayer()
    local spawns = Level.spawns[ Client.data.team ]
    local spawnCount = #spawns
    
    local characterPositions = {}
    for i, character in pairs( GameObject.GetWithTag( "character" ) ) do
        table.insert( characterPositions, character.transform.position )
    end
    
    local loopCount = 0
    local spawnPos = nil
    
    while true do
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
        
        if not tooClose then
            break
        end
    end
    
    local playerGO = GameObject.New( CharacterPrefab )
    playerGO.physics:WarpPosition( spawnPos )
    Client.data.isSpawned = true
end

