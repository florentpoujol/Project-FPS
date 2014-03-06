function Behavior:Awake()
    self.gameObject.s = self
    
    self.team = 1
    self.teamTag = "team1"
    self.otherTeamTag = "team2"
    
    self.isPickedUp = false
    self:SetBase()
    
    self.modelGO = self.gameObject:GetChild("Model")
    
    self.triggerGO = self.gameObject:GetChild("Trigger")
    
    self.triggerGO.OnTriggerEnter = function( characterModelGO )
        if characterModelGO:HasTag( self.otherTeamTag ) and not self.isPickedUp then
            -- player pickup enemy flag
            self:IsPickedUp( characterModelGO )
        
        elseif characterModelGO:HasTag( self.teamTag ) and not self.isPickedUp and not self.isAtBase then --
            -- player touch its team's flag when dropped not at the base
            self:MoveToBase()
        
        elseif characterModelGO:HasTag( self.teamTag ) and not self.isPickedUp and self.isAtBase then --
            
            local enemyFlag = characterModelGO.parent:GetChild("CTF Flag")
            if enemyFlag ~= nil then
                -- player touch its team's flag when cariying enemy flag
                
                -- score point
                --characterModelGO.parent.s:UpdateScore( GetServer().game.ctf.flagSecureScore )
                enemyFlag.s:MoveToBase()
                if IsServer() then
                    self.gameObject.networkSync:SendMessageToPlayers( "MoveTobase", nil, Server.playerIds ) 
                end
                -- use a FlagSecured function
                --that update position, score and notify players
            end
        end
    end
end


function Behavior:SetTeam( team )
    SetEntityTeam( self, team )
    
    if self.team > 0 then
        self.gameObject.networkSync:Setup( NetworkSyncIds.CTFFlags[self.team] )
        
        if IsServer then
            self.triggerGO.trigger.updateInterval = 5 -- "activate" the trigger
        end
    
        self.modelGO.modelRenderer.model = Team[ team ].models.ctfFlag
    end
end


function Behavior:SetBase()
    self.isAtBase = true
    self.basePosition = self.gameObject.transform.position
end

function Behavior:MoveToBase()
    self.gameObject.parent = nil
    self.gameObject.transform.position = self.basePosition
    self.isAtBase = true
    self.isPickedUp = false
end
CS.Network.RegisterMessageHandler( Behavior.IsPickedUp, CS.Network.MessageSide.Players )

-- called from
-- self.triggerGO.OnTriggerEnter()
-- CharacterControl:Die()
--
-- data can be :
-- a table with the absolute position of the flag (when called from the server)
-- a table with the playerId
-- the character's model game object
-- false when the flag is dropped
function Behavior:IsPickedUp( data )

    if type(data) == "table" then
    
        if data.position then
            self.gameObject.transform.position = Vector3( data.position )
        end
            
        if data.playerId then
            data = GetPlayer( data.playerId ).characterGO.s.modelGO
        end
    
        if getmetatable( data ) == GameObject then -- data is the character's model game object
            self.isPickedUp = true
            self.isAtBase = false
            self.gameObject.parent = data
            self.gameObject.transform.localPosition = Vector3(0)
            
            if IsServer then
                self.gameObject.networkSync:SendMessageToPlayers( "IsPickedUp", { playerId = data.parent.s.playerId }, Server.playerIds )    
            end
        end
     
    elseif data == false then
        -- called from CharacterControl:Die() on all clients
        self.isPickedUp = false
        self.gameObject.parent = nil
        
        if IsServer then
            -- broadcast flag position to make sure it is "dropped" at the same position, no matter what local position as the player when he dies/disconnect
            local position = self.gameObject.transform.position
            self.gameObject.networkSync:SendMessageToPlayers( "IsPickedUp", { position = position }, Server.playerIds )
        end

    end
end
CS.Network.RegisterMessageHandler( Behavior.IsPickedUp, CS.Network.MessageSide.Players )


