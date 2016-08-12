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

    -- spawn UI (player HUD, menu, scoreboard)
    GameObject.New( "In-Game/UI" )
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
    
    Gametype.StartRound()
    
    if Client.isConnected then
        Client.player.isReady = true -- set to false in Server:LoadLevel()
        ServerGO.networkSync:SendMessageToServer("MarkPlayerReady")
    else
        -- local offline
        
    
    end
end

