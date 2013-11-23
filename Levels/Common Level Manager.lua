--[[PublicProperties
removeGizmos boolean True
/PublicProperties]]

function Behavior:Awake()
    -- remove gizmos
    if self.removeGizmos then
        for i, gameObject in pairs( GameObject.GetWithTag( "gizmo" ) ) do
            local modelRndr = gameObject.modelRenderer
            if modelRndr ~= nil then
                modelRndr.model = nil
            end
        end
    end
    
    -- spawn HUD
    local hud = GameObject.New( "Menus/HUD" )
    hud.transform.position = Vector3( 999, 999, -999 )
end


function Behavior:Start()
    InitGameType( Client.gametype )
end

