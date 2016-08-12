--[[PublicProperties
Prefab string ""
Multiply boolean False
/PublicProperties]]
--[[
Replace the current gameObject by the specified prefab

The Prefab property may be a scene path or an alias in the Prefabs object as defined below.
    The alias value may be a scene path or a table that will be mass-set on the game object.
The scenes must be composed only of a single game object.
    

When the Multiply property is true, the prefab is actually added at the location of all children of the game object
using the first child's euler angles ans scale as model
]]


Prefabs = {
    -- alias = "scenepath"
    -- or
    -- alias = table
    
    spawn1 = { 
        name = "spawn team1 dm tdm ctf",
        tags = { "spawn", "team1", "dm", "tdm", "ctf", "gizmo" }
    },
    spawn2 = { 
        name = "spawn team2 dm tdm ctf",
        tags = { "spawn", "team2", "dm", "tdm", "ctf", "gizmo" }
    }
}


function Behavior:Awake()
    if self.Prefab ~= "" then
        local sourceGO = self.gameObject        
        local children = self.gameObject:GetChildren()
        local gameObjects = { self.gameObject }

        if self.Multiply then
            sourceGO = children[1]
            if sourceGO == nil then
                return
            end
            gameObjects = children
        end
        
        local eulerAngles = sourceGO.transform:GetEulerAngles()
        local localScale = sourceGO.transform:GetLocalScale()
        
        local path = Prefabs[ self.Prefab ] or self.Prefab
        local scene = nil
        if type( path ) == "string" then
            scene = CS.FindAsset( path, "Scene" )
            
            if scene == nil then
                print("Prefab:Awake() : Could not find scene with path '"..path.."'.")
                return
            end
        end   
        
        for i, gameObject in pairs( gameObjects ) do
            local position = gameObject.transform:GetPosition()
            
            if scene ~= nil then
                gameObject:Destroy()
                gameObject = CS.AppendScene( scene )
            else
                gameObject:Set( path )
            end
            
            if gameObject ~= nil then
                if gameObject.physics ~= nil then
                    -- what if the object is static ? can't check for BodyType
                    gameObject.physics:WarpPosition( position )
                    gameObject.physics:WarpEulerAngles( eulerAngles )
                else
                    gameObject.transform:SetPosition( position )
                    if self.Prefab == "spawn2" then
                        --print( "set euler angles", eulerAngles )
                    end
                    gameObject.transform:SetEulerAngles( eulerAngles )
                    
                end
                gameObject.transform:SetLocalScale( localScale )
            end
        end
    end
end

function Behavior:Start()
    --CS.Destroy( self.gameObject )
    -- throw exception : Unhandled Exception: System.NullReferenceException: Object reference not set to an instance of an object.
end