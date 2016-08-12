
-- Gametype is always written with a lowercase t

GametypeNames = {
    -- short = full
    dm = "Death Match",
    tdm = "Team Death Match",
    ctf = "Capture The Flag",
}


Gametype = {       
    roundEnded = false,
}


-- Called from "Common Level Manager:Start()"
function Gametype.StartRound( gt )
    if gt == nil then
        gt = GetGametype() or "dm"
    end
    Gametype.roundEnded = false
    
    local gameConfig = GetGameConfig()
    gameConfig.gametype = gt
    local gtConfig = GetGametypeConfig()
    
    if IsServer() then -- server or offline
        local time = gtConfig.timeLimit or 9999 --9999 s = 167 m = 2.8 h
        
        -- Level.timerGO is set in UI
        Level.timerGO.updateTweener = Tween.Tweener( time, 0, time, {
            OnUpdate = function( tweener )
                Level.timerGO.Update( tweener.value ) -- set in UI script
            end,
            updateInterval = 10, 
        } )
         
        if IsServer() then
            Level.timerGO.updateTweener.OnComplete = function()
                Gametype.EndRound()
            end
        end
    end
       
    -- remove all gameObjects that don't have the current gametype tag
    for short, full in pairs( GametypeNames ) do
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
    if not IsServer() and Client.player then -- is Client
        team = Client.player.team
    end
    Gametype.ResetLevelSpawn( team )
    
    if IsServer(true) then
        -- On the server, the level spawn is also the game object with the "Camera Control" script, that is moved by the admin
        Level.levelSpawns[1]:AddComponent( "Game/Camera Control", {
            moveOriented = true,
            moveSpeed = 1, -- default = 0.2 = very slow on the big test map
        } )
    end
   
    -- CTF
    if gt == "ctf" then
        local flagDummies = GameObject.GetWithTag( { "ctf", "flag", "team1" } )
        for i, flagDummy in pairs( flagDummies ) do
            local flag = GameObject.New("Entities/CTF Flag")
            flag.s:SetTeam(1)
            flag.transform.position = flagDummy.transform.position
            flag.s:SetBase()
            flagDummy:Destroy()
        end
        
        flagDummies = GameObject.GetWithTag( { "ctf", "flag", "team2" } )
        for i, flagDummy in pairs( flagDummies ) do
            local flag = GameObject.New("Entities/CTF Flag")
            flag.s:SetTeam(2)
            flag.transform.position = flagDummy.transform.position
            flag.s:SetBase()
            flagDummy:Destroy()
        end
    end
end


-- Make sure the team's level spawn has a camera and remove the camera to the other team's level spawn
-- so that the player "spawn" in its level spawn.
-- (the character is not spawned yet, but the player sees the level throught the camera on the level spawn)
function Gametype.ResetLevelSpawn( team )
    if team == nil then
        team = 1
    end
    local otherTeam = Team[team].otherTeam
    
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
-- Argument team may be the team as a number, a player instance, or nil.
-- Return the spawn game object.
-- Called from Server:SetCharacterInput() and Client:SpawnPlayer()
function Gametype.GetSpawn( team )   
    team = team or 1    
    local spawns = Level.spawns[ team ]
    
    if GetGametype() == "dm" then
        spawns = table.merge( Level.spawns[1], Level.spawns[2] )
    end
    
    local spawnCount = #spawns
    if spawnCount < 1 then
        cprint( "ERROR Gametype.GetSpawn() : Wrong spawn count", "spawnCount="..spawnCount, "team="..tostring(team) )
        return
    end
    
    local characterPositions = {}
    for i, character in pairs( GameObject.GetWithTag( "character" ) ) do
        table.insert( characterPositions, character.transform.position )
    end
    
    local loopCount = 0
    local spawnGO = nil
    
    -- find a spawn not too close to any other players
    repeat
        loopCount = loopCount + 1
        if loopCount > spawnCount * 10 then
            -- FIXME : find the most isolated spawn
            break
        end
        
        local rand = math.floor( math.randomrange( 1, spawnCount + 0.99 ) )
        
        spawnGO = spawns[ rand ]
        local spawnPos = spawnGO.transform.position
        local tooClose = false
        
        for i, characterPos in pairs( characterPositions ) do
            if Vector3.Distance( characterPos, spawnPos ) < 5 then
                tooClose = true
                break            
            end            
        end
    until not tooClose
    
    return spawnGO
end


-- Called when a round ends (because of time or score limit is reached) (on the server and all clients via Client:UpdateGameState())
function Gametype.EndRound()
    Gametype.roundEnded = true -- prevent player to spawn while waiting to move to the next map

    if IsServer(true) then
        ServerGO.networkSync:SendMessageToPlayers( "UpdateGameState", { roundEnded = true }, LocalServer.playerIds )
        
        
        for id, player in pairs( server.playersById ) do
            if player.characterGO then
                player.characterGO.s:Die() -- nil argument to tell the function that this is the end of the round and that it must not inscrese the death count or display message
                -- no need to run this code on all client sbecause the function will broadcast itself to the network
            end
        end
    
        Level.timerGO.updateTweener:Destroy()
        Level.timerGO.updateTweener = nil
    end
    
    -- force update of the timer
    Level.timerGO.Update( 0 )
    
    -- force update of the menu (already done from "Character Control":Die() for player who were spawned)
    Level.menu.Show()
    
    -- TODO
    -- load next level in ap rotation
    -- currently (04/2014) wait for the server admin to manually change gametype/level
end
