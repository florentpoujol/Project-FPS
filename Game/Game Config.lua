
CS.Screen.SetSize( 1000, 680 )
CS.Physics.SetGravity( Vector3:New( 0, -100, 0 ) )


--ServerBrowserAddress = "http://localhost/CSServerBrowser/index.php"
ServerBrowserAddress = "http://csserverbrowser.florentpoujol.fr/index.php"


CS.FindAsset( "Test Map", "Map" ).levelBuilderBlocks = {
    {
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
    
    CTFFlags = { 3, 4 }

}


Game = {} -- 24/02 used ?


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


-- Gametype is always written with a lowercase t
Gametypes = {
    -- short = full
    dm = "Death Match",
    tdm = "Team Death Match",
    ctf = "Capture The Flag",
    cq = "Conquest",
    pl = "Payload",
}


-- Team specific data
Team = {}

local function SetTeamData( team )
    local sTeam = "Team"..team
    Team[ team ] = {
        models = {
            bulletTrail = Asset( sTeam.."/Bullet Trail" ),
            crosshair = Asset( sTeam.."/Crosshair" ),
            
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


-- Config for the server, 
-- Override Server.defaultConfig
-- This is just a placeholder, config should be read from a .json file acceessible via internet and the CS.Web API

-- When offline, "server" data is taken from there, or from the defaultConfig
ServerConfig = {
    maxPlayerCount = 12,
    name = "Florent's Server",
    isPrivate = false,
    
    game = {
        -- global game settings (will be applied for all levels/gametypes unless overridden in the rotation)
        scenePath = "Levels/Test Level", -- set in Client:LoadLevel
        gametype = "ctf",
        friendlyFire = false,
        
        --roundTime = 10, -- temp var set in Client:LoadLevel(), used in Gametype.Init()
        
        -- gametype specific settings ?   
        dm = {
            --roundLimit = 1, -- rounds before going to the next rotation
            timeLimit = 12*60+34, -- seconds
            --scoreLimit = 100, -- score limit per team (player in DM)
        },
        
        tdm = {
            --roundLimit = 1, -- rounds before going to the next rotation
            timeLimit = 600, -- seconds
            --scoreLimit = 100, -- score limit per team (player in DM)
        },
        
        ctf = {
            timeLimit = 600,
            captureLimit = 5,
            
            killScore = 10,
            deathScore = -5,
            
            flagCaptureScore = 20,
            flagPickupScore = 5,
            flagReturnHomeScore = 5
        },
        
        
        character = {
            rotationSpeed = 0.1,
            walkSpeed = 35.0,
            jumpSpeed = 1000, --100 = about one cube hight
            health = 3,
            
            -- this is placeholder, will be defined by each weapons
            weaponDamage = 1, -- same unit as health
            shootRate = 5, -- shoots per second
        }
    },
    
    -- the rotation table define the suite of levels and game parameters
    -- each rotation entries override the "game" table
    rotation = {},
}


-- Commands the server admin can issue via the tchat
AdminCmd = {
    kick = function( playerId )
        playerId = tonumber(playerId)
        local player = LocalServer.playersById[ playerId ]
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
            Game.gametype = gametype
            local server = Client.server or LocalServer
            if server ~= nil then
                server.gametype = gametype
            end
        end
        
        -- temp
        --Scene.Load( scene )
        
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
            gametype = Gametype.Config.gametype
        }
        ServerGO.networkSync:SendMessageToPlayers( "LoadLevel", data, LocalServer.playerIds )
        ServerGO.client:LoadLevel( data )
    end,
    
    stopserver = function()
        LocalServer.Stop()
        CS.Input.UnlockMouse()
        Scene.Load( "Menus/Main Menu" )
    end,
    
    changeteam = function( playerId )
        playerId = tonumber(playerId)
        local player = LocalServer.playersById[ playerId ]
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
    
    
    
    --[[
    nextrotation = function( id )
        if id == nil then
            id = LocalServer.currentRotationId + 1
        end
        
        local rotation = LocalServer.rotations[ id ]
        if rotation then
            if rotation.gametype then
                Game.gametype = rotation.gametype
                LocalServer.gametype = rotation.gametype
            end
            
            if rotation.scenePath then
                LocalServer.scenePath = rotation.scenePath
            end
            
            local data = {
                scenePath = LocalServer.scenePath,
                gametype = LocalServer.gametype
            }
            ServerGO.networkSync:SendMessageToPlayers( "LoadLevel", data, LocalServer.playerIds )
            ServerGO.client:LoadLevel( data )
        else
            Tchat.AddLine( "Bad rotation id", id )
        end
    end,
    ]]
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
