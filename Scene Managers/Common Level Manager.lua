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
    GameObject.New( "In-Game/HUD" )
end


function Behavior:Start()
    InitGameType( Client.gametype )
end

