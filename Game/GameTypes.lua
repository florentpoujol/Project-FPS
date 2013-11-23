
function InitGameType( gt )
    if gt == nil then
        gt = "dm"
    end
    Game.gametype = gt
    
    for short, full in pairs( GameTypes ) do
        if short ~= gt then
            -- removed all gameObject than have a tag other than the current gt's tag
            for i, go in pairs( GameObject.GetWithTag( short ) ) do
                go:Destroy()
            end
        end
    end

    
    Game.spawns = {
        team1 = GameObject.GetWithTag( { "spawn", "team1" } ),
        team2 = GameObject.GetWithTag( { "spawn", "team2" } )
    }
end



function SpawnPlayer()
    local spawns = Game.spawns[ Client.team ]
    local spawnCount =  #spawns
    
    local characterPositions = {}
    for i, character in pairs( GameObject.GetWithTag( "character" ) ) do
        table.insert( characterPositions, character.transform.position )
    end
    
    local loopCount = 0
    local spawnPos = nil
    
    while true do
        loopCount = loopCount + 1
                
        local rand = math.floor( math.randomrange( 1, #spawns + 0.99 ) )
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
    end
    
    local playerGO = GameObject.New( CharacterPrefab )
    playerGO.physics:WarpPosition( spawnPos )
end

