

function SetEntityTeam( script, team )
    if team == nil or team < 1 then 
        team = 1
    end
    
    local gameObject = script.gameObject
    
    if team == nil then
        team = script.team
    end
    if team == nil then
        team = 1
    end
    
    local oTeam = 2
    if team == 2 then oTeam = 1 end
    
    script.team = team
    script.otherTeam = oTeam
    script.teamTag = "team"..team
    script.otherTeamTag = "team"..oTeam
    
    gameObject:RemoveTag( script.otherTeamTag )
    gameObject:AddTag( script.teamTag )
end
