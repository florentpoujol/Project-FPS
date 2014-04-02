--[[
This an example of server configuration file that can be accessed as a JSON file through the web API
{
    "maxPlayerCount": 12,
    "name": "Florent's Server",
    "isPrivate": false,
    
    "game": {
        "scenePath": "Levels/Test Level",
        "gametype": "tdm",
        "friendlyFire": false,
 
        "dm": {
            "timeLimit": 600,
            "killScore": 10,
            "deathScore": -5
        },
        
        "tdm": {
            "timeLimit": 600,
            "killScore": 10,
            "deathScore": -5
        },
        
        "ctf": {
            "timeLimit": 600,
            "killScore": 10,
            "deathScore": -5,
            "flagCaptureScore": 20,
            "flagPickupScore": 5,
            "flagReturnHomeScore": 5
        },
        
        "character": {
            "rotationSpeed": 0.1,
            "walkSpeed": 35.0,
            "jumpSpeed": 3000,
            "health": 3,
            
            "weaponDamage": 1,
            "shootRate": 5
        }
    }
}
]]