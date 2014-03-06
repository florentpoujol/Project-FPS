

function SetEntityTeam( script, team )
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
    script.teamTag = "team"..team
    script.otherTeamTag = "team"..oTeam
        
    gameObject:RemoveTag( script.otherTeamTag )
    gameObject:AddTag( script.teamTag )
end
