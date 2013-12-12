
-- the input manager contextualize input based on the existance of some tags (that describe the context)

-- ie :
-- pressing T while playing and tchat input is not focused : focus the tchat input
-- the player can not moves when the tchat input is focuses
-- pressing escape while the thcat input is focused unfocus it but do not bring up the menu


-- list of tags
-- tchatfocused : tchat input is focused



InputManager = {
    gameObject = nil, -- use a game object just to be able to use tags but a custom tag system that just stores some strings will have better performance
    --[[OntextEntered = function( char )
        local charNumber = string.byte( char )
    
        if charNumber == 8 then -- Backspace
    
        elseif charNumber == 13 then -- Enter
        
        -- Any character between 32 and 127 is regular printable ASCII
        elseif charNumber >= 32 and charNumber <= 127 then
            
        end
    end]]
}


if CS.DaneelModules == nil then
    CS.DaneelModules = {}
end  
CS.DaneelModules[ "InputManager" ] = InputManager

-------------

function InputManager.Awake()
    InputManager.gameObject = GameObject.New( "InputManager" )
end


function InputManager.Update()
end

-------------

function InputManager.AddTag( tag )
    InputManager.gameObject:AddTag( tag )
end

function InputManager.RemoveTag( tag )
    InputManager.gameObject:RemoveTag( tag )
end

function InputManager.GetTags()
    return InputManager.gameObject:GetTags()
end

function InputManager.HasTag( tag, atLeastOneTag )
    return InputManager.gameObject:HasTag( tag, atLeastOneTag )
end

---------

local OriginalWasPressed = CS.Input.WasButtonJustPressed
function CS.Input.WasButtonJustPressed( button, tag, hasTag )
    if tag == nil then
        return OriginalWasPressed( button )
    else
        -- Daneel.Utilities.ButtonExists() uses calls CS.Input.WasButtonJustPressed()
        return InputManager.WasButtonJustPressed( button, tag, hasTag )
    end
end

local OriginalWasReleased = CS.Input.WasButtonJustReleased
function CS.Input.WasButtonJustReleased( button, tag, hasTag )
    if tag == nil then
        return OriginalWasReleased( button )
    else
        return InputManager.WasButtonJustReleased( button, tag, hasTag )
    end
end

local OriginalIsDown = CS.Input.IsButtonDown
function CS.Input.IsButtonDown( button, tag, hasTag )
    if tag == nil then
        return OriginalIsDown( button )
    else
        return InputManager.IsButtonDown( button, tag, hasTag )        
    end
end

local OriginalGetAxisValue = CS.Input.GetAxisValue
function CS.Input.GetAxisValue( button, tag, hasTag )
    if tag == nil then
        return OriginalGetAxisValue( button )
    else
        return InputManager.GetAxisValue( button, tag, hasTag )        
    end
end

--------------
-- idea : tag argument could also be a function that return true/false for more complex conditions

function InputManager.WasButtonJustPressed( button, tag, hasTag, atLeastOneTag ) -- will I need multiple tags ?
    -- hasTag tells wheter the InputManager must have the provided tag or not
    if hasTag == nil then
        hasTag = true
    end
    if atLeastOneTag == nil then
        atLeastOneTag = true
    end

    if (InputManager.HasTag( tag, atLeastOneTag ) == hasTag) and OriginalWasPressed( button ) then -- true passe to HasTag means "at least one tag"
        return true
    end
    return false
end

function InputManager.IsButtonDown( button, tag, hasTag, atLeastOneTag )
    if hasTag == nil then
        hasTag = true
    end
    if atLeastOneTag == nil then
        atLeastOneTag = true
    end
    if (InputManager.HasTag( tag, atLeastOneTag ) == hasTag) and OriginalIsDown( button ) then
        return true
    end
    return false
end

function InputManager.WasButtonJustReleased( button, tag, hasTag, atLeastOneTag )
    if hasTag == nil then
        hasTag = true
    end
    if atLeastOneTag == nil then
        atLeastOneTag = true
    end
    if (InputManager.HasTag( tag, atLeastOneTag ) == hasTag) and OriginalWasReleased( button ) then
        return true    
    end
    return false
end

function InputManager.GetAxisValue( button, tag, hasTag, atLeastOneTag )
    if hasTag == nil then
        hasTag = true
    end
    if atLeastOneTag == nil then
        atLeastOneTag = true
    end
    if (InputManager.HasTag( tag, atLeastOneTag ) == hasTag) then
        return OriginalGetAxisValue( button )
    end
    return 0
end
