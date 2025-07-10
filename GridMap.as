const Vec2f DEFAULT_TILE_SIZE = Vec2f(32, 32); // tilted isometry
const Vec2f DEFAULT_MAP_SIZE = Vec2f(10, 10); // default grid map size

Vec2f local_mouse_pos = Vec2f_zero;
int selected_id = -1;
Vec2f start_point = Vec2f_zero;

void onInit(CRules@ this)
{
    onRestart(this);
}

void onRestart(CRules@ this)
{
    v_raw.resize(DEFAULT_MAP_SIZE.x * DEFAULT_MAP_SIZE.y * 4 + 4);
    CreateGridMap(this, DEFAULT_MAP_SIZE);

    if (!isClient()) return;
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

void onTick(CRules@ this)
{
    if (!isClient()) return;
    CControls@ controls = getControls();

    bool a1 = controls.isKeyJustPressed(KEY_LBUTTON);
    bool a2 = controls.isKeyJustPressed(KEY_RBUTTON);

    if (a1 || a2)
    {

    }
    else
    {
        // hover state
        selected_id = getSelectedTile(local_mouse_pos - start_point + Vec2f(0, DEFAULT_TILE_SIZE.y / 2));
    }
}

int getSelectedTile(Vec2f mouse_pos)
{
    CRules@ this = getRules();
    GridMap@ gridMap;
    
    if (!this.get("grid_map", @gridMap) || gridMap is null)
    {
        // Don't warn, it might not be created yet.
        return -1;
    }

    // We must calculate the grid's origin point exactly as we did when we created it.
    CMap@ map = getMap();
    if (map is null) return -1;
    
    Vec2f center = Vec2f(map.tilemapwidth * map.tilesize / 2, map.tilemapheight * map.tilesize / 2);
    Vec2f half_grid_height = Vec2f(0, DEFAULT_TILE_SIZE.y * DEFAULT_MAP_SIZE.y / 2);
    Vec2f gridOrigin = center - half_grid_height;

    // 1. Make the mouse position relative to the grid's origin (0,0) point
    Vec2f relativeMouse = mouse_pos - gridOrigin;

    // These are the inverse formulas of the ones used to create the tile positions.
    // They convert a screen offset back into a logical grid coordinate.
    const float iso_tile_width = DEFAULT_TILE_SIZE.x;
    const float iso_tile_height = DEFAULT_TILE_SIZE.x / 2.0f; // In our projection, height is half of width

    // 2. Apply the inverse transformation
    float grid_x_float = (relativeMouse.y / iso_tile_height) + (relativeMouse.x / iso_tile_width);
    float grid_y_float = (relativeMouse.y / iso_tile_height) - (relativeMouse.x / iso_tile_width);
    
    // The formulas from your constructor were:
    // screen_x = (y - x) * (iso_tile_width / 2)
    // screen_y = (x + y) * (iso_tile_height / 2)
    // The above is the algebraic inverse of that system.

    // 3. Convert the floating point result to an integer grid index
    int grid_x = Maths::Floor(grid_x_float);
    int grid_y = Maths::Floor(grid_y_float);

    // 4. Check if the calculated coordinate is within the map's bounds
    if (grid_x >= 0 && grid_x < gridMap.size.x && grid_y >= 0 && grid_y < gridMap.size.y)
    {
        // 5. If it's valid, calculate the tile's ID. Your ID is 1-based (index + 1).
        int tile_index = grid_y * gridMap.size.x + grid_x;
        return gridMap.tiles[tile_index].id;
    }
    
    return -1; // No valid tile selected
}

const Vec2f texture_size = Vec2f(32, 32); // default tile size
const string texture = "DefaultTile.png";
Vertex[] v_raw;

void RenderGridMap(int id)
{
    local_mouse_pos = getDriver().getWorldPosFromScreenPos(getControls().getInterpMouseScreenPos()) + start_point;

    CRules@ this = getRules();
    GridMap@ gridMap;
    
    if (!this.get("grid_map", @gridMap))
    {
        warn("GridMap: Could not find grid map");
        return;
    }

    for (int i = gridMap.tiles.length - 1; i >= 0; i--)
    {
        GridTile@ tile = gridMap.tiles[i];
        if (tile is null) continue;
                
        tile.selected = tile.id == selected_id;
        tile.render();
    }

    Render::SetTransformWorldspace();
    Render::RawQuads(texture, v_raw);
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
        
        int count = 0;
        for (int x = 0; x < size.x; x++)
        {
            for (int y = 0; y < size.y; y++)
            {
                count++;

                f32 offset_x = -x * DEFAULT_TILE_SIZE.x / 2 + y * DEFAULT_TILE_SIZE.y / 2;
                f32 offset_y = (x + y) * DEFAULT_TILE_SIZE.x / 4;

                Vec2f position = Vec2f(offset_x, offset_y) + center - half_grid_height;
                if (x == 0 && y == 0) start_point = position;

                GridTile tile(count, position);
                tiles.push_back(@tile);
            }
        }
    }
};

class GridTile
{
    int id;
    Vec2f position;
    Vec2f size;
    bool isOccupied;
    u16 occupiedId;
    bool selected;

    GridTile(int _id, Vec2f pos, Vec2f _size = DEFAULT_TILE_SIZE)
    {
        id = _id;
        size = _size;
        position = pos;

        isOccupied = false;
        occupiedId = 0;
        selected = false;
    }

    void setOccupied(bool occupied, u16 id = 0)
    {
        isOccupied = occupied;
        occupiedId = id;
    }

    void render()
    {
        f32 z = 0.0f;
        Vec2f offset = selected ? Vec2f(0, -4) : Vec2f(0, 0);
        
        //u32 gt = getGameTime();
        //offset = Vec2f(0, Maths::Sin(gt * (id/DEFAULT_MAP_SIZE.y+1) * 0.01f) * 2);

        Vec2f vert_pos = position + offset;
        int idx = id * 4;
        v_raw[idx+0] = Vertex(vert_pos + Vec2f(-texture_size.x / 2, -texture_size.y / 2), z, Vec2f(0, 0), SColor(255, 255, 255, 255));
        v_raw[idx+1] = Vertex(vert_pos + Vec2f( texture_size.x / 2, -texture_size.y / 2), z, Vec2f(1, 0), SColor(255, 255, 255, 255));
        v_raw[idx+2] = Vertex(vert_pos + Vec2f( texture_size.x / 2,  texture_size.y / 2), z, Vec2f(1, 1), SColor(255, 255, 255, 255));
        v_raw[idx+3] = Vertex(vert_pos + Vec2f(-texture_size.x / 2,  texture_size.y / 2), z, Vec2f(0, 1), SColor(255, 255, 255, 255));
    }
};