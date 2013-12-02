function Behavior:Awake()
    local mapGO = GameObject.Get( "Map" )
    
    -- level builder
    --mapGO.mapRenderer:ReplaceEntityBlocks( {x=-20,y=-5,z=-20},  {x=20,y=10,z=20} )
    local map = mapGO.mapRenderer.map
    --map:UpdateBlockIDs()
    
    mapGO:AddComponent( "Physics" )
    mapGO.physics:SetBodyType( Physics.BodyType.Static )
    mapGO.physics:SetupAsMap( map )
end
