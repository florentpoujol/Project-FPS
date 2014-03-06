
CTF = {
    flagGOs = {}

}

function CTF.Init()
    local flagDummy = GameObject.GetWithTag( { "ctf", "flag", "team1" } )
    local flag = GameObject.New("Entities/CTF Flag")
    flag.transform.position = flagDummy.transform.position
    flag.s:SetTeam(1)
    CTF.flagGOs[1] = flag
    flagDummy:Destroy()
    
    flagDummy = GameObject.GetWithTag( { "ctf", "flag", "team2" } )
    flag = GameObject.New("Entities/CTF Flag")
    flag.transform.position = flagDummy.transform.position
    flag.s:SetTeam(2)
    CTF.flagGOs[2] = flag
    flagDummy:Destroy()
end
