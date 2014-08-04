--[[PublicProperties
lifeTime number 120
/PublicProperties]]

function Behavior:Awake()
    self.gameObject.s = self
end

function Behavior:Start()
    self.frameCount = 0
    local intensity = Vector3(10)
    
    if self.normal ~= nil then
        
        self.gameObject.physics:ApplyImpulse( self.normal * intensity ) 
    else
        print("no normal")
        --table.print( self.gameObject.s )
    end
end

function Behavior:Update()
    self.frameCount = self.frameCount + 1
    if self.frameCount > self.lifeTime then
        self.gameObject:Destroy()
    end
end
