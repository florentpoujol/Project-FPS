--[[PublicProperties
gameTypes string ""
/PublicProperties]]

function Behavior:Awake()
    if self.gameObject.modelRenderer ~= nil then
        self.gameObject.modelRenderer:Destroy()
    end
    
    
end
