--[[PublicProperties
UpdateMapBlockIDs boolean False
ReplaceEntityBlocks boolean False
/PublicProperties]]
--[[PublicProperties
UpdateMapBlockIDs boolean false
ReplaceEntityBlocks boolean false
PrefabPath string ""
/PublicProperties]]

--[[
Level builder

- Modifiy a map asset by changing the block id at some specified coordinates
The system can actually fill the space between two min and max coordinates.
This allow for instance to create big chunks of map with a minimum amount of work

- Placing prefabs at the location of some specific map blocks ("entities blocks") that are removed in the process
This allow to place "props", prefabs directly inside the map asset, instead of inside the scene

-------
DATA


]]


function Behavior:Awake()
    local mapRenderer = self.gameObject.mapRenderer
    --print( self.UpdateMapBlockIDs, self.ReplaceEntityBlocks)
    if mapRenderer ~= nil and self.UpdateMapBlockIDs then
        local map = mapRenderer:GetMap()
        if map ~= nil then
            map:UpdateBlockIDs()
        end
    end

    if mapRenderer ~= nil and self.ReplaceEntityBlocks then
        mapRenderer:ReplaceEntityBlocks()
    end
end

-- Modifiy a map asset by changing the block id at some specified coordinates
-- this allow to create big chunks of map easily
-- @param mapRenderer (MapRenderer) The mapRenderer with the map to modify
-- @param data (table)
function Map.UpdateBlockIDs( map, data )
    if data == nil then
        data = map.levelBuilderBlocks
    end
    if data == nil then
        print("Map.UpdateBlockIDs() : No data to use.", map )
        return
    end

    local blocks = {}

    for i, block in pairs( data ) do
        if block.min ~= nil and block.max ~= nil then -- parallelepipoid
            for x = block.min.x, block.max.x do
                for y = block.min.y, block.max.y do
                    for z = block.min.z, block.max.z do
                        table.insert( blocks, {
                            blockID = block.blockID,
                            blockOrientation = block.blockOrientation,
                            x = x, y = y, z = z
                        } )
                    end 
                end
            end
        else
            table.insert( blocks, block )
        end
    end
    
    for i, block in pairs( blocks ) do
        if block.blockID == nil then 
            block.blockID = 0 
        end

        if type( block.blockOrientation ) == "string" then
            block.blockOrientation = Map.BlockOrientation[ block.blockOrientation ]
        end
        if block.blockOrientation == nil then
            block.blockOrientation = Map.BlockOrientation.North
        end

        map:SetBlockAt( block.x, block.y, block.z, block.blockID, block.blockOrientation )
    end
end


-- scan the map for some block ids and replace them with the specified prefab
-- as set in the 'entitiesByBlockID' property on the map's tileset
function MapRenderer.ReplaceEntityBlocks( mapRenderer, min, max )
    local map = mapRenderer:GetMap()
    local tileSet = mapRenderer:GetTileSet()
    
    if tileSet.entitiesByBlockID == nil then
        print( "MapRenderer.ReplaceEntityBlocks() : No 'entytiesByBlockID' property found on tile set", Map.GetPathInPackage( tileSet ), tileSet )
        return
    end

    if min == nil then
        min = { x = -40, y = -10, z = -40 }
    end
    if max == nil then
        max = { x = 40, y = 20, z = 40 }
    end
    -- default is a chunk of 1 million squared blocks, centered on the origin

    local tileSetSize = tileSet:GetTileSize()
    local mapRendererPosition = mapRenderer.gameObject.transform:GetPosition()
    local mapRendererScale = mapRenderer.gameObject.transform:GetLocalScale()

    for x = min.x, max.x do
        for y = min.y, max.y do
            for z = min.z, max.z do
                local ID = map:GetBlockIDAt( x, y, z )
                local entity = tileSet.entitiesByBlockID[ ID ]
                if entity ~= nil then
                    -- entity can be a scene asset, a scene path or a function. if the function returns false, the block is not removed 
                    local t = type( entity )
                    local mapPosition = Vector3:New( x, y, z )
                    local scenePosition = mapPosition * tileSetSize/16 + mapRendererPosition * mapRendererScale
                    local removeBlock = nil

                    if t == "function" then
                        entity( scenePosition, mapRenderer )
                    elseif t == "string" then
                        entity = CS.FindAsset( entity, "Scene" )
                    end

                    if type( entity ) == "table" and getmetatable( entity ) == Scene then
                        local prefab = CS.AppendScene( entity )
                        if prefab.physics ~= nil then
                            -- what if the object is static ? can't check for BodyType
                            prefab.physics:WarpPosition( scenePosition )
                        else
                            prefab.transform:SetPosition( scenePosition )
                        end
                        --print("LevelBuilder : set entity '"..ID.."' at", scenePosition, mapPosition )
                    end

                    map:SetBlockAt( x, y, z, Map.EmptyBlockID, Map.BlockOrientation.North ) -- remove the block
                end
            end
        end
    end
end
