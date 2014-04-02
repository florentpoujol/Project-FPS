--[[PublicProperties
pilarsDistanceInterval string "2,5"
pilarsHeight string "1,5"
/PublicProperties]]

local pilarsBlockId = { 0, 1, 2, 3, 5 }
RandomMapData = {} -- list of all the generated blocks

function Behavior:Awake()
    self.gameObject.networkSync:Setup( 3 )
    
    self.map = self.mapRenderer.map
    
    if IsClient then
        self.gameObject.networkSync:SendMessageToServer( "SendMapDataToPlayer" )
        return
    end
    
    self:GenerateMapData()
    self:BuildMap()
end


function Behavior:GenerateMapData()
    local originGO = self.gameObject:GetChild("Random Map Origin")
    local sideGO = originGO:GetChild("Random Map Side")
    local mapWidth = Vector3.Distance( originGO.position, sideGO.position ) * 2
    
    
    
end

-- build the map with the data
function Behavior:BuildMap( mapData )
    if mapData == nil then
        mapData = RandomMapData
    end
    
    Map.LoadFromPackage( self.gameObject.map.path, function( map )
        for i, block in pairs( mapData ) do
            map:SetBlockAt( block.x, block.y, block.z, block.ID )
        end
        
        self.gameObject.map = map
    end )
end


-- Called y the client to ask to be sent the map data
function Behavior:SendMapDataToPlayer( playerId )
    self.gameObject.networkSync:SendMessageToPlayers( "ReceiveMapData", mapData, { playerId } )
end
CS.Network.RegisterMessageHandler( Behavior.SendMapDataToPlayer, CS.Network.MessageSide.Server )


function Behavior:ReceiveMapData( mapData )
    RandomMapData = mapData
    self:BuildMap( mapData )
end
CS.Network.RegisterMessageHandler( Behavior.ReceiveMapData, CS.Network.MessageSide.Players )


