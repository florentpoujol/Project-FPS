--[[PublicProperties
updateRate number 4
/PublicProperties]]
-- from : http://answers.unity3d.com/questions/64331/accurate-frames-per-second-count.html

function Behavior:Awake()    
    self.frameCount = 0
    self.dt = 0 -- delta time
    self.fps = 0    
    self.time = os.clock() -- seconds
    
    -- Properties
    --self.updateRate = 4 -- updates per sec.
end


function Behavior:Update()
    if self.updateRate > 0 then
        local currentTime = os.clock()
        local deltaTime = currentTime - self.time
        self.time = currentTime
    
        self.frameCount = self.frameCount + 1
        self.dt = self.dt + deltaTime
        
        if self.dt > 1 / self.updateRate then
            self.fps = self.frameCount / self.dt
            
            self.gameObject.textRenderer.text = math.round( self.fps, 1 )
            
            self.frameCount = 0
            self.dt = self.dt - 1/self.updateRate
        end
    end
end
