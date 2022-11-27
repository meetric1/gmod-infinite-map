InfMap.simplex = include("simplex.lua")
InfMap.chunk_resolution = 3
InfMap.planet_spacing = 50
InfMap.filter["infmap_terrain_collider"] = true	// dont pass in chunks
InfMap.filter["infmap_planet"] = true
InfMap.disable_pickup["infmap_terrain_collider"] = true	// no pickup
InfMap.disable_pickup["infmap_planet"] = true

local max = 2^28
local offset = 23.05
function InfMap.height_function(x, y) 
	//x = x + offset
    //local final = (InfMap.simplex.Noise3D(x / 15, y / 15, 0) * 150) * math.min(InfMap.simplex.Noise3D(x / 75, y / 75, 0) * 7500, 0) // small mountains
	//final = final + (InfMap.simplex.Noise3D(x / 75 + 1, y / 75, 150)) * 350000	// big mountains
	//x = x - offset
	local final = ((InfMap.simplex.Noise2D(x / 25 + 1, y / 25)) * 20) ^ 4
	if (x >= 0) and (y > -0.5 and y < 0.5) then final = -15 end
	return math.Clamp(final, -max, 1000000)
end