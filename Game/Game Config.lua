
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


Level = {} -- holds "menu", "hud", scorebpoard" keys (see the HUD script)
-- also "spawns" and "levelspanws" (from "Gametypes" script)

-- Gametype is always written with a lowercase t
Gametypes = {
    -- short = full
    dm = "Death Match",
    tdm = "Team Death Match",
    ctf = "Capture The Flag",
    cq = "Conquest",
    pl = "Payload",
}


-- Config for the server, 
-- This is just a placeholder, config should be read from a .json file acceessible via internet and the CS.Web API

-- When offline, "server" data is taken from there, or from the defaultConfig
ServerConfig = {
    maxPlayerCount = 12,
    name = "Florent's Server",
    iPrivate = false,
    
    game = {
        -- global game settings (will be applied for all levels/gametypes unless overridden in the rotation)
        scenePath = "Levels/Test Level", -- set in Client:LoadLevel
        gametype = "dm",
        friendlyFire = false,
        
        -- gametype specific settings ?   
        dm = {
            --roundLimit = 1, -- rounds before going to the next rotation
            --timeLimit = 10, -- minutes
            scoreLimit = 100, -- score limit per team (player in DM)
        },
        -- ...
        
        -- other setting (wepons damage, characters movement...)
        -- characterMoveSpeed = ?,
        -- characterJumpSpeed = ?,
        -- 
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
