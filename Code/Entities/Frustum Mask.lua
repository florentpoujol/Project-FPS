
function Behavior:Awake()
    local camera = self.gameObject.parent.camera
    local screenSize = Vector3( CS.Screen.GetSize(), 1 )
    
    if camera.projectionMode == Camera.ProjectionMode.Orthographic then
        self.gameObject.transform.localScale = screenSize * camera.pixelsTounits
        self.gameObject.transform.localPosition = Vector3(0)
    else -- perspective
        -- object size = object distance / BaseDist * screen size / SSS
        -- At baseDistance : object scale = screen size / SSS
        
        local smallestSideSize = screenSize.y
        if screenSize.x < screenSize.y then
            smallestSideSize = screenSize.x
        end
        self.gameObject.transform.localScale = screenSize / smallestSideSize
        self.gameObject.transform.localPosition = Vector3(0, 0, -camera.baseDistance)
    end
end
