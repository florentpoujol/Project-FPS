
_ = {}

if CS.DaneelModules == nil then
    CS.DaneelModules = {}
end
CS.DaneelModules[ "Web" ] = _

function _.Load()
    Daneel.Web = {}
    
    function Daneel.Web.Get( address, callback, responseType )
        if responseType == nil then
            responsType = CS.Web.ResponseType.JSON
        end
        
        if callback == nil then
            callback = function() end
        end
        CS.Web.Get( address, nil, responseType, callback )    
    end
    
    function Daneel.Web.Post( address, data, callback, responseType )
        if responseType == nil then
            responsType = CS.Web.ResponseType.JSON
        end
        
        if callback == nil then
            callback = function() end
        end
        CS.Web.Post( address, data, responseType, callback )    
    end

end