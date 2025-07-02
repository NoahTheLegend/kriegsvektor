const Vec2f DEFAULT_TILE_SIZE = Vec2f(32, 32); // tilted isometry
const Vec2f DEFAULT_MAP_SIZE = Vec2f(10, 10); // default grid map size

void onInit(CRules@ this)
{
    onRestart(this);
}

void onRestart(CRules@ this)
{
    CreateGridMap(this, DEFAULT_MAP_SIZE);

    int index = this.exists("render_index") ? this.get_s32("render_index") : Render::addScript(Render::layer_tiles, "GridMap.as", "RenderGridMap", 0.0f);
    this.set_s32("render_index", index);
}

void onReload(CRules@ this)
{
    this.set("grid_map", null);
    onRestart(this);
}

void CreateGridMap(CRules@ this, Vec2f size)
{
    GridMap gridMap(size);
    this.set("grid_map", @gridMap);
}

void RenderGridMap(int id)
{
    CRules@ this = getRules();
    GridMap@ gridMap;
    
    if (!this.get("grid_map", @gridMap))
    {
        warn("GridMap: Could not find grid map");
        return;
    }

    for (int i = 0; i < gridMap.tiles.length; i++)
    {
        GridTile@ tile = gridMap.tiles[i];
        if (tile is null) continue;

        tile.render();
    }   
}

class GridMap
{
    Vec2f size;
    GridTile@[] tiles;

    GridMap(Vec2f _size)
    {
        size = _size;

        CMap@ map = getMap();
        if (map is null)
        {
            warn("GridMap: Could not find map");
            return;
        }
        
        Vec2f half_grid_height = Vec2f(0, DEFAULT_TILE_SIZE.y * DEFAULT_MAP_SIZE.y / 2);
        Vec2f center = Vec2f(map.tilemapwidth * map.tilesize / 2, map.tilemapheight * map.tilesize / 2);
        
        for (int x = 0; x < size.x; x++)
        {
            for (int y = 0; y < size.y; y++)
            {
                f32 offset_x = -x * DEFAULT_TILE_SIZE.x / 2 + y * DEFAULT_TILE_SIZE.y / 2;
                f32 offset_y = (x + y) * DEFAULT_TILE_SIZE.x / 4;
                Vec2f position = Vec2f(offset_x, offset_y) + center - half_grid_height;

                GridTile tile(position);
                tiles.push_back(@tile);
            }
        }
    }
};

class GridTile
{
    Vec2f position;
    Vec2f size;
    bool isOccupied;
    u16 occupiedId;

    GridTile(Vec2f pos, Vec2f _size = DEFAULT_TILE_SIZE)
    {
        size = _size;
        position = pos;

        isOccupied = false;
        occupiedId = 0;
    }

    void setOccupied(bool occupied, u16 id = 0)
    {
        isOccupied = occupied;
        occupiedId = id;
    }

    void render()
    {
        const Vec2f texture_size = Vec2f(32, 32); // default tile size
        string texture = "DefaultTile.png";

        f32 z = 0.0f;

        Vertex[] v_raw;
        v_raw.push_back(Vertex(position + Vec2f(-texture_size.x / 2, -texture_size.y / 2), z, Vec2f(0, 0), SColor(255, 255, 255, 255)));
        v_raw.push_back(Vertex(position + Vec2f( texture_size.x / 2, -texture_size.y / 2), z, Vec2f(1, 0), SColor(255, 255, 255, 255)));
        v_raw.push_back(Vertex(position + Vec2f( texture_size.x / 2,  texture_size.y / 2), z, Vec2f(1, 1), SColor(255, 255, 255, 255)));
        v_raw.push_back(Vertex(position + Vec2f(-texture_size.x / 2,  texture_size.y / 2), z, Vec2f(0, 1), SColor(255, 255, 255, 255)));
        
        Render::SetTransformWorldspace();
        Render::RawQuads(texture, v_raw);
    }
};