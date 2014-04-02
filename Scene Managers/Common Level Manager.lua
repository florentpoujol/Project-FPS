--[[PublicProperties
removeGizmos boolean True
/PublicProperties]]

function Behavior:Awake()
    local mapGO = GameObject.Get( "Map" )
    Level.mapGO = mapGO
    
    local map = mapGO.mapRenderer.map
    if map.levelBuilderBlocks ~= nil then
        map:UpdateBlockIDs( map.levelBuilderBlocks )
    end
    
    -- set physics now that the map has been modified
    mapGO:CreateComponent( "Physics" )
    mapGO.physics:SetupAsMap( map )
    mapGO.physics:SetBodyType( Physics.BodyType.Static )

    
    -- spawn HUD
    GameObject.New( "In-Game/HUD" )
end


function Behavior:Start()
    -- remove gizmos
    if self.removeGizmos then
        for i, gameObject in pairs( GameObject.GetWithTag( "gizmo" ) ) do
            if gameObject.modelRenderer ~= nil then
                gameObject.modelRenderer:Destroy()
            end
        end
    end
    
    local server = GetServer()
    Gametype.Init( server.game.gametype )
    
    if Client.isConnected then
        Client.player.isReady = true -- set to false in Server:LoadLevel()
        --ServerGO.networkSync:SendMessageToServer( "MarkPlayerReady" ) -- now that the scene is fully loaded set ready to begin receiving game status update
    end
end

