// --- Configuration ---
// These constants control the entire grid and chunk system.
const Vec2f DEFAULT_MAP_SIZE = Vec2f(10, 10); // The total size of the grid in tiles.
const Vec2f CHUNK_SIZE = Vec2f(2, 2);      // The size of each chunk in tiles.
const u8    EDGE_HEIGHT = 5;                  // How many decorative edge tiles to draw below the grid.
const Vec2f DEFAULT_TILE_SIZE = Vec2f(32, 32);  // The visual size of a single tile.

// --- Global State ---
// Variables that manage the state of the grid across the script.
GridMap@ g_gridMap;         // A global handle to our main grid map object.
int      selected_id = -1;  // The ID of the currently selected tile.
f32      delta_factor = 0;  // A time-scaling factor for smooth animations.

// --- Active Animation System ---
// These lists track only the tiles that are currently animating to avoid unnecessary updates.
GridTile@[] active_tiles;
int[]       active_tiles_idxs;

// --- Rendering & Asset Constants ---
const Vec2f  texture_size = Vec2f(32.1f, 32.1f); // Hacked with 0.1f to avoid texture ripping artifacts.
const string texture_tile = "DefaultTile.png";
const string texture_edge = "DefaultTileGround.png";

// =================================================================================
//  CORE DATA STRUCTURES
//  These classes define the structure of our grid, from the smallest tile
//  to the chunks and the main grid map that manages them all.
// =================================================================================

/**
 * GridTile
 * Represents a single tile in the grid. It holds its own state but does not
 * manage its own rendering vertices; that is handled by its parent chunk.
 */
class GridTile
{
    int   id;
    Vec2f position;
    Vec2f offset;
    bool  selected;
    bool  keep_updating;

    GridTile(int _id, Vec2f pos)
    {
        id = _id;
        position = pos;
        selected = false;
        keep_updating = false;
        offset = Vec2f_zero;
    }

    // Recalculates the tile's vertex data into a provided vertex array.
    void render(Vertex[] &inout v_array)
    {
        f32 lf = delta_factor * 0.5f;
        offset = selected ? Vec2f_lerp(offset, Vec2f(0, -4), lf) : Vec2f_lerp(offset, Vec2f(0, 0), lf);
        offset.x = Maths::Round(offset.x * 100.0f) / 100.0f;
        offset.y = Maths::Round(offset.y * 100.0f) / 100.0f;
        keep_updating = offset.x != 0.0f || offset.y != 0.0f;

        Vec2f vert_pos = position + offset;
        int idx = (id - 1) % (CHUNK_SIZE.x * CHUNK_SIZE.y) * 4;
        f32 z = 0.0f;

        v_array[idx+0] = Vertex(vert_pos + Vec2f(-texture_size.x / 2, -texture_size.y / 2), z, Vec2f(0, 0), SColor(255, 255, 255, 255));
        v_array[idx+1] = Vertex(vert_pos + Vec2f( texture_size.x / 2, -texture_size.y / 2), z, Vec2f(1, 0), SColor(255, 255, 255, 255));
        v_array[idx+2] = Vertex(vert_pos + Vec2f( texture_size.x / 2,  texture_size.y / 2), z, Vec2f(1, 1), SColor(255, 255, 255, 255));
        v_array[idx+3] = Vertex(vert_pos + Vec2f(-texture_size.x / 2,  texture_size.y / 2), z, Vec2f(0, 1), SColor(255, 255, 255, 255));
    }
}

/**
 * GridChunk
 * Represents a segment of the larger grid. It is responsible for loading,
 * holding, and rendering its own set of tiles and decorative edges.
 */
class GridChunk
{
    Vec2f       chunkGridPos; // The (X,Y) position of this chunk in the overall grid of chunks.
    GridTile@[]  tiles;        // The tiles contained within this chunk.
    Vertex[]    v_tiles;      // The vertex array for rendering this chunk's tiles.
    Vertex[]    v_edge;       // The vertex array for this chunk's decorative edges.
    bool        isLoaded;
    bool        needsRedraw;
    bool        needsEdgeRedraw;

    GridChunk(Vec2f _chunkGridPos)
    {
        chunkGridPos = _chunkGridPos;
        isLoaded = false;
        needsRedraw = true;
        needsEdgeRedraw = true;
    }

    // Loads the chunk's data into memory and generates its tiles.
    void Load(GridMap@ gridMap)
    {
        if (isLoaded) return;

        int tilesPerChunk = CHUNK_SIZE.x * CHUNK_SIZE.y;
        tiles.resize(tilesPerChunk);
        v_tiles.resize(tilesPerChunk * 4);

        Vec2f startTilePos = Vec2f(chunkGridPos.x * CHUNK_SIZE.x, chunkGridPos.y * CHUNK_SIZE.y);

        for (int y = 0; y < CHUNK_SIZE.y; y++)
        {
            for (int x = 0; x < CHUNK_SIZE.x; x++)
            {
                int globalTileX = startTilePos.x + x;
                int globalTileY = startTilePos.y + y;
                
                int tileIndex = y * CHUNK_SIZE.x + x;
                int tileId = (globalTileY * DEFAULT_MAP_SIZE.x + globalTileX) + 1;

                Vec2f position = gridMap.GridToWorld(Vec2f(globalTileY, globalTileX));
                
                GridTile tile(tileId, position);
                @tiles[tileIndex] = @tile;
            }
        }

        isLoaded = true;
        BuildVertexArray();
    }
    
    // Builds the entire vertex array for this chunk's tiles. Called once on load.
    void BuildVertexArray()
    {
        for (uint i = 0; i < tiles.length(); ++i)
        {
            tiles[i].render(v_tiles);
        }

        needsRedraw = false;
    }

    void RenderDebugBoundaries(GridMap@ gridMap)
    {
        if (!getControls().isKeyPressed(KEY_LSHIFT)) return;
        Vertex[] debug_v;

        Vec2f _0 = Vec2f(v_tiles[0].x, v_tiles[0].y) + Vec2f(DEFAULT_TILE_SIZE.x / 2, 0);
        Vec2f _1 = _0 + Vec2f(DEFAULT_TILE_SIZE.x / 2 * CHUNK_SIZE.x, DEFAULT_TILE_SIZE.y / 4 * CHUNK_SIZE.y);
        Vec2f _2 = _0 + Vec2f(0, DEFAULT_TILE_SIZE.y / 4 * CHUNK_SIZE.y * 2);
        Vec2f _3 = _0 + Vec2f(-DEFAULT_TILE_SIZE.x / 2 * CHUNK_SIZE.x, DEFAULT_TILE_SIZE.y / 4 * CHUNK_SIZE.y);

        debug_v.push_back(Vertex(_0, 0.0f, Vec2f(0, 0), SColor(255, 255, 0, 0)));
        debug_v.push_back(Vertex(_1, 0.0f, Vec2f(1, 0), SColor(255, 0, 255, 0)));
        debug_v.push_back(Vertex(_2, 0.0f, Vec2f(1, 1), SColor(255, 0, 0, 255)));
        debug_v.push_back(Vertex(_3, 0.0f, Vec2f(0, 1), SColor(255, 255, 255, 0)));

        Render::RawQuads("pixel", debug_v);
    }
}

/**
 * GridMap
 * The main controller class. It manages the entire collection of chunks,
 * handles coordinate conversions, and serves as the primary interface for the grid.
 */
class GridMap
{
    Vec2f       mapSizeInTiles;
    Vec2f       mapSizeInChunks;
    GridChunk@[][] chunks;
    Vec2f       gridOrigin; // The world coordinate of tile (0,0).

    GridMap(Vec2f _size)
    {
        mapSizeInTiles = _size;
        mapSizeInChunks = Vec2f(Maths::Ceil(mapSizeInTiles.x / CHUNK_SIZE.x), Maths::Ceil(mapSizeInTiles.y / CHUNK_SIZE.y));
        
        CMap@ map = getMap();
        Vec2f center = Vec2f(map.tilemapwidth * map.tilesize / 2, map.tilemapheight * map.tilesize / 2);
        Vec2f half_grid_height = Vec2f(0, DEFAULT_TILE_SIZE.y * mapSizeInTiles.y / 2);
        gridOrigin = center - half_grid_height;

        chunks.resize(mapSizeInChunks.x);
        for (int i = 0; i < mapSizeInChunks.x; i++)
        {
            chunks[i].resize(mapSizeInChunks.y);
            for (int j = 0; j < mapSizeInChunks.y; j++)
            {
                GridChunk chunk(Vec2f(i, j));
                @chunks[i][j] = @chunk;
            }
        }
    }

    // Converts grid tile coordinates (e.g., 15, 25) to world space coordinates.
    Vec2f GridToWorld(Vec2f gridPos)
    {
        f32 offset_x = -gridPos.x * DEFAULT_TILE_SIZE.x / 2 + gridPos.y * DEFAULT_TILE_SIZE.y / 2;
        f32 offset_y = (gridPos.x + gridPos.y) * DEFAULT_TILE_SIZE.x / 4;
        return Vec2f(offset_x, offset_y) + gridOrigin;
    }

    // Converts world space coordinates back to grid tile coordinates.
    Vec2f WorldToGrid(Vec2f worldPos)
    {
        Vec2f relativeMouse = worldPos - gridOrigin;
        const float iso_tile_width = DEFAULT_TILE_SIZE.x;
        const float iso_tile_height = DEFAULT_TILE_SIZE.x / 2.0f;

        float grid_x_float = (relativeMouse.y / iso_tile_height) + (relativeMouse.x / iso_tile_width) + 1;
        float grid_y_float = (relativeMouse.y / iso_tile_height) - (relativeMouse.x / iso_tile_width) + 1;

        return Vec2f(Maths::Floor(grid_x_float), Maths::Floor(grid_y_float));
    }

    // Gets a tile object from anywhere on the map using its global tile coordinates.
    GridTile@ getTile(int globalX, int globalY)
    {
        if (globalX < 0 || globalX >= mapSizeInTiles.x || globalY < 0 || globalY >= mapSizeInTiles.y) return null;
        
        int chunkX = globalX / CHUNK_SIZE.x;
        int chunkY = globalY / CHUNK_SIZE.y;

        GridChunk@ chunk = chunks[chunkX][chunkY];
        if (chunk is null || !chunk.isLoaded) return null;

        int localX = globalX % CHUNK_SIZE.x;
        int localY = globalY % CHUNK_SIZE.y;
        int tileIndex = localY * CHUNK_SIZE.x + localX;

        return chunk.tiles[tileIndex];
    }
    
    // Gets a chunk object from the grid of chunks.
    GridChunk@ getChunk(int chunkX, int chunkY)
    {
        if (chunkX < 0 || chunkX >= mapSizeInChunks.x || chunkY < 0 || chunkY >= mapSizeInChunks.y) return null;
        return chunks[chunkX][chunkY];
    }
}


// =================================================================================
//  LOGIC & HELPER FUNCTIONS
//  These functions manage the game logic, rendering, and interactions.
// =================================================================================

/**
 * AddToActiveList
 * Adds a tile to the list of currently animating tiles, ensuring no duplicates.
 */
void AddToActiveList(GridTile@ tile)
{
    if (tile is null) return;
    if (active_tiles_idxs.find(tile.id) == -1)
    {
        active_tiles.push_back(tile);
        active_tiles_idxs.push_back(tile.id);
    }
}

/**
 * getSelectedTileId
 * Calculates which tile is under the mouse cursor.
 */
int getSelectedTileId(Vec2f mouse_pos)
{
    if (g_gridMap is null) return -1;

    Vec2f gridPos = g_gridMap.WorldToGrid(mouse_pos);
    
    if (gridPos.x >= 0 && gridPos.x < g_gridMap.mapSizeInTiles.x && gridPos.y >= 0 && gridPos.y < g_gridMap.mapSizeInTiles.y)
    {
        return (gridPos.y * g_gridMap.mapSizeInTiles.x + gridPos.x) + 1;
    }
    
    return -1;
}

/**
 * SetChunkDecorative
 * Builds the vertex array for a single chunk's decorative edges, accounting for neighbors.
 */
void SetChunkDecorative(GridChunk@ chunk)
{
    if (!chunk.needsEdgeRedraw) return;

    Vec2f[] positions;
    int tilesChecked = 0;
    
    int startX = chunk.chunkGridPos.x * CHUNK_SIZE.x;
    int startY = chunk.chunkGridPos.y * CHUNK_SIZE.y;

    GridChunk@ rightNeighbor = g_gridMap.getChunk(chunk.chunkGridPos.x + 1, chunk.chunkGridPos.y);
    GridChunk@ bottomNeighbor = g_gridMap.getChunk(chunk.chunkGridPos.x, chunk.chunkGridPos.y + 1);

    bool hasRight = rightNeighbor !is null && rightNeighbor.isLoaded;
    bool hasBottom = bottomNeighbor !is null && bottomNeighbor.isLoaded;

    for (int y = 0; y < CHUNK_SIZE.y; y++)
    {
        for (int x = 0; x < CHUNK_SIZE.x; x++)
        {
            bool isBottomEdge = (y == CHUNK_SIZE.y - 1 && !hasBottom);
            bool isRightEdge = (x == CHUNK_SIZE.x - 1 && !hasRight);
            
            if (isBottomEdge || isRightEdge)
            {
                GridTile@ tile = chunk.tiles[y * CHUNK_SIZE.x + x];
                if (tile !is null)
                {
                    positions.push_back(tile.position + Vec2f(0, DEFAULT_TILE_SIZE.y / 2));
                }
            }
        }
    }
    
    chunk.v_edge.resize(positions.length() * EDGE_HEIGHT * 4);
    int v_edge_len = chunk.v_edge.length();

    for (int i = positions.length() - 1; i >= 0; i--)
    {
        for (int j = EDGE_HEIGHT - 1; j >= 0; j--)
        {
            Vec2f offset = Vec2f(0, (EDGE_HEIGHT - j) * texture_size.y / 2 - texture_size.y / 2);
            Vec2f pos = positions[i] + offset;

            int idx = (i * EDGE_HEIGHT + j) * 4;
            if (idx + 3 >= v_edge_len) break;
            
            f32 z = 0.0f;
            chunk.v_edge[idx+0] = Vertex(pos + Vec2f(-texture_size.x / 2, -texture_size.y / 2), z, Vec2f(0, 0), SColor(255, 255, 255, 255));
            chunk.v_edge[idx+1] = Vertex(pos + Vec2f( texture_size.x / 2, -texture_size.y / 2), z, Vec2f(1, 0), SColor(255, 255, 255, 255));
            chunk.v_edge[idx+2] = Vertex(pos + Vec2f( texture_size.x / 2,  texture_size.y / 2), z, Vec2f(1, 1), SColor(255, 255, 255, 255));
            chunk.v_edge[idx+3] = Vertex(pos + Vec2f(-texture_size.x / 2,  texture_size.y / 2), z, Vec2f(0, 1), SColor(255, 255, 255, 255));
        }
    }
    chunk.needsEdgeRedraw = false;
}

// =================================================================================
//  KAG HOOKS & MAIN LOOP
//  These are the primary entry points called by the game engine.
// =================================================================================

/**
 * onInit
 * Called once when the game mode starts.
 */
void onInit(CRules@ this)
{
    onRestart(this);
}

void onReload(CRules@ this)
{
    onRestart(this);
}

/**
 * onRestart
 * Called when the game restarts, responsible for setting up the entire grid system.
 */
void onRestart(CRules@ this)
{
    GridMap gridMap(DEFAULT_MAP_SIZE);
    @g_gridMap = @gridMap;
    
    warn("========================================================================");
    warn("GridMap initialized with size: " + g_gridMap.mapSizeInTiles.x + "x" + g_gridMap.mapSizeInTiles.y + " tiles, " +
          g_gridMap.mapSizeInChunks.x + "x" + g_gridMap.mapSizeInChunks.y + " chunks.");
    warn("========================================================================");

    // For now, load all chunks. A more advanced system would load chunks around the camera.
    for (int i = 0; i < g_gridMap.mapSizeInChunks.x; i++)
    {
        for (int j = 0; j < g_gridMap.mapSizeInChunks.y; j++)
        {
            g_gridMap.chunks[i][j].Load(g_gridMap);
        }
    }

    this.set("grid_map", @g_gridMap);

    if (!isClient()) return;
    int index = this.exists("render_index") ? this.get_s32("render_index") : Render::addScript(Render::layer_tiles, "GridMap.as", "SetGridMap", 0.0f);
    this.set_s32("render_index", index);
}

/**
 * onTick
 * Called every game tick for handling game logic like player input.
 */
/**
 * onTick
 * Called every game tick for handling game logic like player input.
 */
void onTick(CRules@ this)
{
    if (!isClient() || g_gridMap is null) return;
    
    delta_factor = getRenderDeltaTime() * 60;
    Vec2f mpos = getDriver().getWorldPosFromScreenPos(getControls().getInterpMouseScreenPos());
    
    Vec2f selection_pos = mpos;
    int old_selected_id = selected_id;
    selected_id = getSelectedTileId(selection_pos);
    
    if (selected_id != old_selected_id)
    {
        if (old_selected_id != -1)
        {
            // This logic correctly finds the old tile's global coordinates from its ID.
            int globalX = (old_selected_id - 1) % uint(g_gridMap.mapSizeInTiles.x);
            int globalY = (old_selected_id - 1) / uint(g_gridMap.mapSizeInTiles.x);
            AddToActiveList(g_gridMap.getTile(globalX, globalY));
        }
        if (selected_id != -1)
        {
            Vec2f newGridPos = g_gridMap.WorldToGrid(selection_pos);
            AddToActiveList(g_gridMap.getTile(newGridPos.x, newGridPos.y));
        }
    }
}

/**
 * SetGridMap
 * The main rendering function, called every frame by the engine.
 */
void SetGridMap(int id)
{
    if (g_gridMap is null) return;
    
    Render::SetTransformWorldspace();

    // --- DEBUG: Initialize counters ---
    int loadedChunks = 0;

    // Render all loaded chunks
    for (uint i = 0; i < g_gridMap.chunks.length(); ++i)
    {
        for (uint j = 0; j < g_gridMap.chunks[i].length(); ++j)
        {
            GridChunk@ chunk = g_gridMap.chunks[i][j];
            if (chunk is null || !chunk.isLoaded) continue;

            // --- DEBUG: Increment counter ---
            loadedChunks++;

            // Render tiles
            if (chunk.needsRedraw) chunk.BuildVertexArray();
            Render::RawQuads(texture_tile, chunk.v_tiles);
            
            // Render edges
            SetChunkDecorative(chunk);
            Render::RawQuads(texture_edge, chunk.v_edge);

            GridMap@ gridMap;
            getRules().get("grid_map", @gridMap);
            if (gridMap is null) continue;
            chunk.RenderDebugBoundaries(gridMap);
        }
    }

    // Process only the tiles that are currently animating
    for (int i = active_tiles.length - 1; i >= 0; i--)
    {
        GridTile@ tile = active_tiles[i];
        if (tile is null)
        {
            active_tiles.removeAt(i);
            active_tiles_idxs.removeAt(i);
            continue;
        }

        tile.selected = tile.id == selected_id;
        
        // Find the tile's parent chunk to update its vertex array
        int globalX = (tile.id - 1) % uint(g_gridMap.mapSizeInTiles.x);
        int globalY = (tile.id - 1) / uint(g_gridMap.mapSizeInTiles.x);
        int chunkX = globalX / CHUNK_SIZE.x;
        int chunkY = globalY / CHUNK_SIZE.y;
        GridChunk@ chunk = g_gridMap.chunks[chunkX][chunkY];

        if (chunk !is null)
        {
            tile.render(chunk.v_tiles);
        }

        if (!tile.keep_updating && !tile.selected)
        {
            active_tiles.removeAt(i);
            active_tiles_idxs.removeAt(i);
        }
    }

    // --- DEBUG: Draw On-Screen Text ---
    if (isClient())
    {
        CControls@ controls = getControls();
        Vec2f mpos = getDriver().getWorldPosFromScreenPos(controls.getInterpMouseScreenPos());
        Vec2f gridPos = g_gridMap.WorldToGrid(mpos);

        GUI::SetFont("menu");
        string debug_text = "GridMap Debug\n" +
                            "----------------------------------\n" +
                            "Map Size: " + g_gridMap.mapSizeInTiles.x + "x" + g_gridMap.mapSizeInTiles.y + "\n" +
                            "Chunk Grid: " + g_gridMap.mapSizeInChunks.x + "x" + g_gridMap.mapSizeInChunks.y + "\n" +
                            "Loaded Chunks: " + loadedChunks + "\n" +
                            "Animating Tiles: " + active_tiles.length() + "\n" +
                            "----------------------------------\n" +
                            "Mouse World: " + (Maths::Round(mpos.x)) + ", " + (Maths::Round(mpos.y)) + "\n" +
                            "Calculated Grid: " + gridPos.x + ", " + gridPos.y + "\n" +
                            "Selected Tile ID: " + selected_id + "\n";
        
        GUI::DrawText(debug_text, Vec2f(20, 40), SColor(255, 255, 255, 255));
    }
}