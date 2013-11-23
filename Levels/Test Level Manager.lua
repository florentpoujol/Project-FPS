function Behavior:Awake()
    local mapGO = GameObject.Get( "Map" )
    
    -- level builder
    mapGO.mapRenderer:ReplaceEntityBlocks( {x=-20,y=-5,z=-20},  {x=20,y=10,z=20} )
    local map = mapGO.mapRenderer.map
    map:UpdateBlockIDs()
    
    mapGO:AddComponent( "Physics" )
    mapGO.physics:SetBodyType( Physics.BodyType.Static )
    mapGO.physics:SetupAsMap( map )
end


function Behavior:Start()
    
    
    
    local hudGO = GameObject.Get( "HUD Camera" )
    -- replace the HUD camera component so that it is renderer after the player camera
    -- and the hud element appears over what is rendered by the player camera 
    local orthoScale = hudGO.camera.orthographicScale
    hudGO.camera:Destroy()
    hudGO:AddComponent( "Camera" , { 
        projectionMode = "orthographic",
        orthographicScale = orthoScale
    })
end


function Behavior:Update()

    
    if CS.Input.WasButtonJustPressed( "Escape" ) then
        CS.Exit()
    end
end
