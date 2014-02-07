
CS.Screen.SetSize( 1000, 680 )
CS.Physics.SetGravity( Vector3:New( 0, -100, 0 ) )


--ServerBrowserAddress = "http://localhost/CSServerBrowser/index.php"
ServerBrowserAddress = "http://csserverbrowser.florentpoujol.fr/index.php"


--- Level Builder
--[[
CS.FindAsset( "Tile Set 1", "TileSet" ).entitiesByBlockID = {
    -- [blockId] = "scene path",
}
]]

CS.FindAsset( "Test Map", "Map" ).levelBuilderBlocks = {
    {
        blockID = 4,
        min = { x = -20, y = 0, z = -40 },
        max = { x = 20, y = 0, z = 40 },
    }   
}



Game = {
    
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
Team = {

}

local function SetTeamData( team )
    local sTeam = "Team"..team
    Team[ team ] = {
        models = {
            bulletTrail = Asset( sTeam.."/Bullet Trail" ),
            crosshair = Asset( sTeam.."/Crosshair" ),
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
    iPrivate = false,
    
    game = {
        -- global game settings (will be applied for all levels/gametypes unless overridden in the rotation)
        scenePath = "Levels/Test Level", -- set in Client:LoadLevel
        gametype = "tdm",
        friendlyFire = false,
        
        -- gametype specific settings ?   
        dm = {
            --roundLimit = 1, -- rounds before going to the next rotation
            timeLimit = 12*60+34, -- seconds
            --scoreLimit = 100, -- score limit per team (player in DM)
        },
        
        tdm = {
            --roundLimit = 1, -- rounds before going to the next rotation
            timeLimit = 15, -- seconds
            --scoreLimit = 100, -- score limit per team (player in DM)
        },
        -- ...
        
        -- other setting (wepons damage, characters movement...)
        -- characterMoveSpeed = ?,
        -- characterJumpSpeed = ?,
        -- 
        character = {
            rotationSpeed = 0.1,
            walkSpeed = 35.0,
            jumpSpeed = 3000, --1000 = about one cube hight
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




function DaneelUserConfig()
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
