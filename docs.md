# How to create an infinite map
* I apologize in advance for the shitty documentation, ive never written any before
* Feel free to contact me on the [Discord](https://discord.gg/cmQvg2AHgP) if you need help or have any questions implementing this API



# How to Create an Infinite Map
1. Install the infmap base
2. Create a map using hammer
	- Note: If you create a world brush it will loop infinitely in all directions
	- See the [Explanation video](https://youtu.be/NPsxeRELlNY) to see why this occurs
	- I suggest just using an empty map with a skybox and adding your own LUA terrain
3. Once your map is created, rename it so it has "infmap" as the second word in your map. This allows the api to distinguish whether to initialize or not
	- Examples: gm_infmap_backrooms; gm_infmap_void; sb_infmap_planets, etc.
4. Your map is now infinite!



# Properly Initializing Custom Map LUA
### Custom LUA in infmaps are handled slightly differently because the LUA runs before every other addon for maximum compatibility. In order to have your map LUA intitialize correctly, follow these steps.
1. Start by creating a new addon
2. Put your map in `addons/myaddon/maps`
3. Create this file structure: `addons/myaddon/lua/infmap/yourmapname/..`
	- Note: Make sure everything is lowercase for linux!
4. Make sure the LUA you are creating is inside of `addons/myaddon/lua/infmap/yourmapname/..` 
	- Note: The LUA inside of `addons/myaddon/lua/infmap` is ran on *EVERY* infinite map, DO NOT put your LUA in here.
5. Add your custom lua, files that start with 'cl_' and 'sh_' are automatically AddCSluaFile'd
	- Note: The `InfMap` table and its functions are already initialized when your file is run
	- Note: The lua ran here initializes before any other addon can initialize



# Main API
* Most functions are detoured, functions such as SetPos and GetPos should just work and feel like a normal map
* If you want to call the original non detoured function, put InfMap_ before calling it (Entity:InfMap_SetPos, InfMap.TraceLine)
* in order to avoid rounding errors at high distances I would suggest setting the position with Entity:InfMap_SetPos and setting the chunk it is in


## Functions
`InfMap.prop_update_chunk(Entity ent, Vector chunkpos)->[]`
* Description
	- Updates an entities chunk, does not *physically* move it
* Arguments
	- Entity ent: The entity to have chunk changed
	- Vector chunkpos: The new chunk it will be in
* Returns
	- None


`InfMap.localize_vector(Vector pos, Number chunksize or nil)->[Vector wrappedpos, Vector deltachunk]`
* Description
	- Changes a world vector to a local vector
	- Kind of like modulo, but for position
* Arguments
	- Vector pos: The position
	- Number chunksize: The size of the chunk that the position will be "wrapped" (Default = 10,000)
* Returns
	- Vector wrappedpos: The moduloed position
	- Vector deltachunk: How many chunks the position "crossed"


`InfMap.unlocalize_vector(Vector localpos, Vector chunkoffset)->[Vector newpos]`
* Description
	- Changes a local vector to world vector
	- (Takes a local position and offsets it by the size of however many chunks)
	- Opposite of `InfMap.localize_vector`
* Arguments
	- Vector localpos: The local position
	- Vector chunkoffset: How many chunks to offset, (can be nil, if it is, the local position is returned)
* Returns
	- Vector newpos: New world position


`InfMap.intersect_box(Vector box1min, Vector box1max, Vector box2min, Vector box2max)->[Boolean intersecting]`
* Description
	- Does a basic intersection of 2 boxes and returns if they are "colliding"
* Arguments
	- Vector box1min: Min size for the first box
	- Vector box1max: Max size for the first box
	- Vector box2min: Min size for the second box
	- Vector box2max: Max size for the second box
* Returns
	- Boolean intersecting: True if the boxes are intersecting, false if not


`InfMap.filter_entities(Entity ent)->[Boolean isfiltered]`
* Description
	- Returns true if the entity will be ignored during chunk teleportation, cross chunk collision, and other factors
	- Constraints and the world are automatically filtered
* Arguments
	- Entity ent: The entity to check
* Returns
	- Boolean intersecting: True if entity will be ignored, false if not


`InfMap.get_all_constrained(Entity ent)->[Table constrainedents]`
* Description
	- Returns a table of all physically constrained entities (not including parents)
* Arguments
	- Entity ent: The entity to check
* Returns
	- Table constrainedents: The table of constrained entities


`InfMap.get_all_parents(Entity ent)->[Table parentedents]`
* Description
	- Returns a table of all parents connected to an entity
* Arguments
	- Entity ent: The entity to check
* Returns
	- Table parentedents: The table of parented entities


`InfMap.in_chunk(Vector pos, Number chunksize or nil)->[Boolean isinsidechunk]`
* Description
	- Returns if a local position is inside of a chunk
	- Can also be considered a point box intersection function
* Arguments
	- Vector pos: Local position
	- Number chunksize: Optional custom size for the box, extends from -x to x
* Returns
	- Boolean isinsidechunk: Is the position inside a chunk


`InfMap.find_in_chunk(Vector chunk)->[Table entities]`
* Description
	- Returns all the entities in a specified chunk
	- This is faster than any find function because it uses table lookups
* Arguments
	- Vector chunk: The chunk to check
* Returns
	- Table entities: The entities in the chunk


`InfMap.constrained_status(Entity ent)->[Boolean isparent]`
* Description
	- Returns wheather the entity is the main parent entity to be teleported
	- Used internally
* Arguments
	- Entity ent: The entity to check
* Returns
	- Boolean: isparent



## Variables
`InfMap.filter`
* A table with all the useless entity classes (strings) in source
* Entity classes in this table are ignored and will not be wrapped in chunks


`InfMap.disable_pickup`
* A table with entity classes (strings) that are ignored by physgun
* Classes in this table are not picked up by physgun or gravgun
* Classes in this table are not saved in gmod "saves"


`InfMap.chunk_size`
* Size of each chunk, default is 10,000 but can be edited per map by just setting the variable



## Custom Hooks
`PropUpdateChunk [Entity ent, Vector chunk, Vector oldchunk]`
* Description
	- Runs when an entity passes through a chunk
	- Note: On client this function is called for every entity when the local player passes through a chunk
	- Note: Using Entity:InfMap_GetPos may give different results depending on if it was before or after the initial SetPos teleport
* Returns
	- Entity ent: The entity that passed through the chunk
	- Vector chunk: The current chunk the entity is now in
	- Vector oldchunk: The previous chunk the entity was in (can be nil if the entity was just spawned in!)