
CS.Screen.SetSize( 1000, 680 )

CS.Physics.SetGravity( Vector3:New( 0, -100, 0 ) )


CS.FindAsset( "Test Map", "Map" ).levelBuilderBlocks = {
    {
        -- white ground
        blockID = 4,
        min = { x = -20, y = 0, z = -40 },
        max = { x = 20, y = 0, z = 40 },
    }   
}


-- networksync ids
NetworkSyncIds = {
    Server = 0,
    Tchat = 1,
    RandomMap = 2,
    
    CTFFlags = 3, -- *100 + team*10 + flag id,  so actual id are like 310 320
    
    characters = 20, -- + playerId
}


Level = {
    -- common level manager script
    mapGO = nil, -- "Map" game object (with the map renderer)
    
    -- HUD script
    hudCameraGO = nil, -- "Hud Camera" game object
    menu = nil,
    hud = nil,
    scoreboard = nil,
    
    -- gametypes
    spawns = {}, -- spawns GO by team
    levelSpawns = {}, -- level spawns GO by team
} 


-- Config for the server, 
-- Override Server.defaultConfig
-- This is just a placeholder, config should be read from a .json file acceessible via internet and the CS.Web API

-- When offline, server data is taken from there
ServerConfig = {
    maxPlayerCount = 12,
    name = "Florent's Server",
    isPrivate = false,
    
    game = {
        -- global game settings (will be applied for all levels/gametypes)
        scenePath = "Levels/Test Level", -- set in Client:LoadLevel
        gametype = "ctf",
        friendlyFire = false,
        
        -- gametype specific settings
        --[[
        generic gametype settings :
        {
            timeLimit = 600, -- in seconds
            scoreLimit = nil,
            
            killScore = 10,
            deathScore = -5,
            suicideScore = 0,
        }
        ]]
            
        -- gametype specific settings ?   
        dm = {
            timeLimit = 12*60+34, -- seconds
            scoreLimit = 100, -- score limit per team (player in DM)
        },
        
        tdm = {
            timeLimit = 600, -- seconds
            scoreLimit = 100, -- score limit per team (player in DM)
        },
        
        ctf = {
            timeLimit = 600,
            captureLimit = 5,
            
            killScore = 10,
            deathScore = -5,
            
            flagCaptureScore = 20,
            flagPickupScore = 5,
            flagReturnHomeScore = 5,
        },
        
        
        character = {
            rotationSpeed = 0.1,
            walkSpeed = 18,
            --walkSpeed = 10, -- which unit is this ?? It's certainly not units/second ! 1000 == about 10 units per second
            jumpSpeed = 600, --200 = about one cube hight
            health = 3,
            
            -- this is placeholder, will be defined by each weapons
            weaponDamage = 1, -- same unit as health
            shootRate = 5, -- shoots per second
        }
    },
}


-- Team specific data
Team = {}
local function SetTeamData( team )
    local sTeam = "Team"..team
    Team[ team ] = {
        models = {
            bulletTrail = Asset( sTeam.."/Bullet Trail" ),
            crosshair = Asset( "CommonTeam/Crosshair" ),
            
            ctf = {
                flag = Asset( sTeam.."/CTF/Flag" ),
                flagIcon = Asset( sTeam.."/CTF/Flag Icon" ),
            },
            
            character = {
                body = Asset( sTeam.."/Character/Body" )
            }
        }
    }
end
SetTeamData( 1 )
SetTeamData( 2 )

Team[1].otherTeam = 2
Team[1].tag = "team1"
Team[1].otherTeamTag = "team2"
Team[1].name = "Red"

Team[2].otherTeam = 1
Team[2].tag = "team2"
Team[2].otherTeamTag = "team1"
Team[2].name = "Blue"


-- Commands the server admin can issue via the tchat
AdminCmd = {
    kick = function( playerId )
        playerId = tonumber(playerId)
        local player = GetPlayer( playerId )
        if player == nil then
            Tchat.AddLine( "Unknow player id "..playerId )
        else
            ServerGO.server:DisconnectPlayer( playerId, "Kicked by server" )
        end
    end,
    
    ip = function() Client.GetIp() end,
    
    loadscene = function( path, gametype )
        local scene = Asset( path, "Scene" )
        if scene == nil then
            Tchat.AddLine( "Unknow scene with path '"..path.."'" )
            return
        end
        if gametype ~= nil then
            local gameConfig = GetGameConfig()
            if gameConfig ~= nil then
                gameConfig.gametype = gametype
            end
        end
        
        -- notify people of the server
        local data = {
            scenePath = path,
            gametype = gametype
        }
        ServerGO.networkSync:SendMessageToPlayers( "LoadLevel", data, LocalServer.playerIds )
        ServerGO.client:LoadLevel( data )
    end,
    
    reloadscene = function()
        local data = {
            scenePath = Scene.current.path, -- Gametype.Config.scenePath
            gametype = GetGametype()
        }
        ServerGO.networkSync:SendMessageToPlayers( "LoadLevel", data, LocalServer.playerIds )
        ServerGO.client:LoadLevel( data )
    end,
    
    stopserver = function()
        Server.Stop()
        CS.Input.UnlockMouse()
        Scene.Load( "Menus/Main Menu" )
    end,
    
    changeteam = function( playerId )
        playerId = tonumber(playerId)
        local player = GetPlayer( playerId )
        if player == nil then
            Tchat.AddLine( "Unknow player id "..playerId )
        else
            ServerGO.client:ChangePlayerTeam( { playerId = playerId } )
        end
    end,
    
    settime = function( time )
        local tweener = Level.timerGO.updateTweener
        time = tonumber( time )
        if tweener and type( time ) == "number" then
            tweener.duration = time
            tweener.startValue = time
            tweener:Restart()
            --ServerGO.networkSync:SendMessageToPlayers( "UpdateGameState", { roundTime = time }, LocalServer.playerIds )
        end
    end,
    
    followplayer = function( playerId )
        playerId = tonumber(playerId)
        local player = GetPlayer( playerId )
        if player == nil then
            Tchat.AddLine( "Unknow player id "..playerId )
        else
            if Level.levelSpawns[1].camera ~= nil then
                Level.levelSpawns[1].camera:Destroy()
                CS.Destroy( Level.levelSpawns[1]:GetComponent("Game/Camera Control") )
            end
            
            if player.characterGO ~= nil then
                player.characterGO.s.cameraGO:Set({ camera = { fov = 60 } })
                Level.hudCamera.Recreate()
            end
        end
    end,
    
    stopfollow = function()
        if Level.levelSpawns[1].camera == nil then
            Level.levelSpawns[1]:AddComponent("Camera")
            Level.levelSpawns[1]:AddComponent("Game/Camera Control", {
                moveOriented = true,
                moveSpeed = 1, -- default = 0.2 = very slow on the big test map
            } )
        end
    end,
}


function Daneel.UserConfig()
    return {
        textRenderer = {
            font = "Calibri"
        },
        
        debug = {
            enableDebug = true,
            enableStackTrace = true,
        }
    }
end

