--[[PublicProperties
functionName string ""
/PublicProperties]]

function Behavior:Awake()
    if self.functionName == "" then
        return
    end
    
    local mapInfo = _G[self.functionName]()
    

    if mapInfo.blocks == nil then
        mapInfo.blocks = {}
    end
    
    -- cubes
    if mapInfo.cubes ~= nil then
        
            
        for i, cube in ipairs( mapInfo.cubes ) do
            if cube.blockId == nil then cube.blockId = 0 end
            
            cube.blockOrientation = Map.BlockOrientation[ cube.blockOrientation ]
            if cube.blockOrientation == nil then
                cube.blockOrientation = Map.BlockOrientation.North
            end
            
            local xs, ys, zs = {}, {}, {}
            
            for j, corner in ipairs( cube.corners ) do
                table.insert( xs, corner.x )
                table.insert( ys, corner.y )
                table.insert( zs, corner.z )
            end
            
            local min = { 
                x = math.min( unpack( xs ) ),
                y = math.min( unpack( ys ) ),
                z = math.min( unpack( zs ) )
            }
            
            local max = { 
                x = math.max( unpack( xs ) ),
                y = math.max( unpack( ys ) ),
                z = math.max( unpack( zs ) )
            }
            
            local x, y, z = min.x, min.y, min.z
            
            for x = min.x, max.x do
                for y = min.y, max.y do
                    for z = min.z, max.z do
                        table.insert( mapInfo.blocks, {
                            blockId = cube.blockId,
                            blockOrientation = cube.blockOrientation,
                            x = x, y = y, z = z
                        } )
                    end
                end
            end
            
        end
    end   
    
    -- lines
    if type(mapInfo.lines) == "table" then
        for i, line in ipairs(mapInfo.lines) do
            if line.blockId == nil then line.blockId = 0 end
            
            line.blockOrientation = Map.BlockOrientation[line.blockOrientation]
            if line.blockOrientation == nil then
                line.blockOrientation = Map.BlockOrientation.North
            end
            
            if type(line.from.x) ~= "number" then line.from.x = 0 end
            if type(line.from.y) ~= "number" then line.from.y = 0 end
            if type(line.from.z) ~= "number" then line.from.z = 0 end
            if type(line.to.x) ~= "number" then line.to.x = line.from.x end
            if type(line.to.y) ~= "number" then line.to.y = line.from.y end
            if type(line.to.z) ~= "number" then line.to.z = line.from.z end
            
            --
            local component = "x"
            local start = line.from.x
            local _end = line.to.x
            
            if type(line.to.y) == "number" then 
                component = "y"
                start = line.from.y
                _end = line.to.y
            elseif type(line.to.z) == "number" then 
                component = "z"
                start = line.from.z
                _end = line.to.z
            end
            
            for i = start, _end do
                table.insert(mapInfo.blocks, {
                    --x = 
                
                })
            end
        end
    end
    
    -----
    
    local newMap = self.gameObject.mapRenderer:GetMap()
    --local path = Map.GetPathInPackage( map )
    --local newMap = Map.LoadFromPackage( path )
    --print("MapGenerator: new map id: ", newMap.id, #mapInfo.blocks )
    --self.gameObject.mapRenderer:SetMap( newMap ) -- replace the current map by a dynamically loaded one
    
    -- tileset
    if mapInfo.tileSet ~= nil then
        local tileSet = mapInfo.tileSet
        if type( tileSet ) == "string" then
            tileSet = CS.FindAsset( tileSet, "TileSet" )
        end
        
        if tileSet ~= nil then
            self.gameObject.mapRenderer:SetTileSet( tileSet )
        end
    end
    
    -- blocks
    for i, block in pairs( mapInfo.blocks ) do
    
        if block.x == nil then block.x = 0 end
        if block.y == nil then block.y = 0 end
        if block.z == nil then block.z = 0 end
        if block.blockId == nil then block.blockId = 0 end
        block.blockOrientation = Map.BlockOrientation[block.blockOrientation]
        if block.blockOrientation == nil then
            block.blockOrientation = Map.BlockOrientation.North
        end

        newMap:SetBlockAt(block.x, block.y, block.z, block.blockId, block.blockOrientation)
    end
end

--[[
--tileSet = "Tile Set 1",
       
        blocks = {
            { x = 0 },
            { y = 1, blockId = 1, blockOrientation = "South" },
            { y = 2, blockId = 2 },
            { y = 3, blockId = 3 },
        },
        
        
        -- simple line
        
        lines = {
            {
                blockOrientation = "North",
                blockId = 0,
                
                from = {
                    x = 0, y = 0, z = 0,
                },
    
                to = {
                    y = 10
                },
            },
        },
        
        
        cubes = {
            {
                blockId = 4,
                corners = {
                    { x = -30, y = 0, z = -30 },
                    { x = 30, y = 0, z = 30 },
                }
                
                
            },
        },
    
    
        -- 3D rectangle
        blocks = {
    
        },
        ]]