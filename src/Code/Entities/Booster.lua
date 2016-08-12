--[[PublicProperties
force number 10
/PublicProperties]]

function Behavior:Awake()
    self.triggerGO = self.gameObject:GetChild("Trigger")
    self.directionGO = self.gameObject:GetChild("Direction")

    
end

function Behavior:Start()
    local direction = self.directionGO.transform.position - self.gameObject.transform.position
    
    --local orientation = self.gameObject.transform.orientation
    --print( orientation,  Vector3(31,0,0):Rotate( orientation ) )
    local anglesNormalized = direction:Normalized()
    local force = anglesNormalized * 5000
    force.z = force.z * 2
    self.triggerGO.OnTriggerEnter = function( characterGO )
        print("booster trigger enter", force)

        characterGO.physics:ApplyImpulse( force )
    end
end
