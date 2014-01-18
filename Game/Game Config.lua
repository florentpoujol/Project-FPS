
CS.Screen.SetSize( 1000, 680 )
--CS.Screen.SetResizable( false )
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
    -- the Game objet holds data that must be accessible when offline
    -- other data about the game which makes sens in an online context are hold by Client.server
       
    gametype = "dm",
    friendlyFire = true,
}


Level = {}

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

-- easier to set up this way than create UI but it is only possible if they have access to the source code...
-- they can use "config" file that the game access throught the web api (works in a dropbox)
-- or they could use Keriz's CSSave editor
ServerConfig = {
    current = 1, -- id of the current/first item playing
    
    {
        scene = "Levels/Test Level",
        gametype = "dm",
        -- maxRoundCount = 2,
        -- friendlyFire = false,
        
    },
    {
        scene = "Levels/Test Level",
        gametype = "tdm",
    },
    
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


local OriginalFunc = CS.Input.LockMouse
function CS.Input.LockMouse()
    CS.Input.isMouseLocked = true
    OriginalFunc()
end

local OriginalFunc = CS.Input.UnlockMouse
function CS.Input.UnlockMouse()
    CS.Input.isMouseLocked = false
    OriginalFunc()
end

function CS.Input.ToggleMouseLock()
    if CS.Input.isMouseLocked then
        CS.Input.UnlockMouse()
    else
        CS.Input.LockMouse()
    end
end