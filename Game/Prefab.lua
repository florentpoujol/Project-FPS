--[[PublicProperties
Prefab string ""
Multiply boolean False
/PublicProperties]]
--[[
Replace the current gameObject by the specified prefab

The PrefabNameOrScenePath property may be a scene path or an alias as defined below.
The alias value may be a scene path or a table that will be mass-set on a newly created gameObject
The scenes must be composed only of a single game object.
    

When the Multiply property is true, the prefab is actually added at the location of all children of the game object
using the first child's euler angles ans scale as model
]]


Prefabs = {
    -- alias = "scenepath"
    -- alias = table
    
    spawn1 = { tags = "spawn,team2,dm,tdm,ctf" }
}


function Behavior:Awake()
    if self.Prefab ~= "" then
        local sourceGO = self.gameObject        
        local children = self.gameObject:GetChildren()
        local positions = { self.gameObject.transform:GetPosition() }

        if self.Multiply then
            sourceGO = children[1]
            if sourceGO == nil then
                return
            end
            positions = {}
            for i, child in pairs( children ) do
                table.insert( positions, child.transform:GetPosition() )
            end
        end
        
        local eulerAngles = sourceGO.transform:GetEulerAngles()
        local localScale = sourceGO.transform:GetLocalScale()
        

        local path = self.Prefab
        if Prefabs[ path ] ~= nil then
            path = Prefabs[ path ]
        end
        
        local scene = nil
        if type( path ) == "string" then
            scene = CS.FindAsset( path, "Scene" )
            
            if scene == nil then
                print("Prefab:Awake() : Could not find scene with path '"..path.."'.")
                return
            end
        end   
        
        
        for i, position in pairs( positions ) do
            local prefab = nil
            if scene ~= nil then
                prefab = CS.AppendScene( scene )
            else
                prefab = GameObject.New( "Prefab", path )
            end
            
            if prefab ~= nil then
                if prefab.physics ~= nil then
                    -- what if the object is static ? can't check for BodyType
                    prefab.physics:WarpPosition( position )
                    prefab.physics:WarpEulerAngles( eulerAngles )
                else
                    prefab.transform:SetPosition( position )
                    prefab.transform:SetEulerAngles( eulerAngles )
                    
                end
                prefab.transform:SetLocalScale( localScale )
            end
        end
    end
end

function Behavior:Start()
    --CS.Destroy( self.gameObject )
    -- throw exception : Unhandled Exception: System.NullReferenceException: Object reference not set to an instance of an object.
end