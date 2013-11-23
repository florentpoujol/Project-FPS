
CS.Screen.SetSize( 1000, 680 )
--CS.Screen.SetResizable( false )

CS.Physics.SetGravity( Vector3:New( 0, -100, 0 ) )


function DaneelUserConfig()
    LoadGUIConsole() -- console script
    
    return {
        textRenderer = {
            font = "Calibri"
        },
        
        debug = {
            enableDebug = true,
            enableStackTrace = false,
        }
    }
end


--- Level Builder
CS.FindAsset( "Tile Set 1", "TileSet" ).entitiesByBlockID = {
    [248] = "", -- CTF spawn team 1
    [249] = "", -- CTF spawn team 2
    [250] = "", -- CTF flag team 1
    [251] = "", -- CTF flag team 2
    
    [252] = "", -- TDM spawn team 1
    [253] = "", -- TDM spawn team 2
    
    --[254] = "Entities/DM Spawn",
}

CS.FindAsset( "Test Map", "Map" ).levelBuilderBlocks = {
    {
        blockID = 4,
        min = { x = -20, y = 0, z = -20 },
        max = { x = 20, y = 0, z = 20 },
    }   
}



Game = {}


GameTypes = {
    -- short = full
    dm = "Death Match",
    tdm = "Team Death Match",
    ctf = "Capture The Flag",
    cq = "Conquest",
    pl = "Payload",
}

