InfMap.simplex = include("simplex.lua")
InfMap.chunk_resolution = 3

InfMap.filter["infmap_terrain_collider"] = true	// dont pass in chunks
InfMap.filter["infmap_planet"] = true
InfMap.disable_pickup["infmap_terrain_collider"] = true	// no pickup
InfMap.disable_pickup["infmap_planet"] = true

InfMap.planet_render_distance = 3
InfMap.planet_spacing = 50
InfMap.planet_uv_scale = 10
InfMap.planet_resolution = 32
InfMap.planet_tree_resolution = 32
InfMap.planet_outside_materials = {
	Material("shadertest/seamless2"),
	Material("shadertest/seamless3"),
	Material("shadertest/seamless4"),
	Material("shadertest/seamless5"),
	Material("shadertest/seamless6"),
	Material("shadertest/seamless7"),
	Material("shadertest/seamless8"),
}
InfMap.planet_inside_materials = {
	Material("shadertest/seamless2"),
	Material("shadertest/seamless3"),
	Material("shadertest/seamless4"),
	Material("shadertest/seamless5"),
	Material("shadertest/seamless6"),
	Material("phoenix_storms/ps_grass"),
	Material("shadertest/seamless8"),
}

local max = 2^28
function InfMap.height_function(x, y) 
	//x = x + 23.05
    //local final = (InfMap.simplex.Noise3D(x / 15, y / 15, 0) * 150) * math.min(InfMap.simplex.Noise3D(x / 75, y / 75, 0) * 7500, 0) // small mountains
	//final = final + (InfMap.simplex.Noise3D(x / 75 + 1, y / 75, 150)) * 350000	// big mountains

	if (x > -0.5 and x < 0.5) or (y > -0.5 and y < 0.5) then return -15 end

	x = x - 3

	local final = (InfMap.simplex.Noise2D(x / 25, y / 25 + 100000)) * 75000
	final = final / math.max((InfMap.simplex.Noise2D(x / 100, y / 100) * 15) ^ 3, 1)

	return math.Clamp(final, -max, 1000000)
end

function InfMap.planet_height_function(x, y)
	return InfMap.simplex.Noise2D(x / 10000, y / 10000) * 1000
end

// returns local position of planet inside megachunk
function InfMap.planet_info(x, y)
	local spacing = InfMap.planet_spacing / 2 - 1
	local random_x = math.floor(util.SharedRandom("X" .. x .. y, -spacing, spacing))
	local random_y = math.floor(util.SharedRandom("Y" .. x .. y, -spacing, spacing))
	local random_z = math.floor(util.SharedRandom("Z" .. x .. y, 0, 100))
	
	local planet_pos = Vector(x * InfMap.planet_spacing + random_x, y * InfMap.planet_spacing + random_y, random_z + 125)
	local planet_radius = math.floor(util.SharedRandom("Radius" .. x .. y, InfMap.chunk_size / 10, InfMap.chunk_size))
	local planet_type = math.Round(util.SharedRandom("Type" .. x .. y, 1, 7))

	return planet_pos, planet_radius, planet_type
end

if CLIENT then return end

// TO THE MAX
hook.Add("InitPostEntity", "infmap_physenv_setup", function()
	local mach = 270079	// mach 20 in hammer units
	physenv.SetPerformanceSettings({MaxVelocity = mach, MaxAngularVelocity = mach})
	RunConsoleCommand("sv_maxvelocity", tostring(mach))
end)
