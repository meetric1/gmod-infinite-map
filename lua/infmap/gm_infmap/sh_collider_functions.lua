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
	Material("infmap_planets/mercury"),
	Material("infmap_planets/venus"),
	Material("infmap_planets/earth"),
	Material("infmap_planets/mars"),
	Material("infmap_planets/jupiter"),
	Material("infmap_planets/saturn"),
	Material("infmap_planets/uranus"),
	Material("infmap_planets/neptune"),
	Material("infmap_planets/moon"),
}
InfMap.planet_inside_materials = {
	Material("infmap_planets/mercury_inside"),
	Material("infmap_planets/venus_inside"),
	Material("infmap/flatgrass"),
	Material("infmap_planets/mars_inside"),
	Material("infmap_planets/jupiter_inside"),
	Material("infmap_planets/saturn_inside"),
	Material("infmap_planets/uranus_inside"),
	Material("infmap_planets/neptune_inside"),
	Material("infmap_planets/moon_inside"),
}
InfMap.planet_data = {
	[2] = { // venus
		Atmosphere = {
			Vector(0.9, 0.75, 0.4),
			0.25
		},
		Clouds = {
			Material("infmap_planets/venus_clouds"),
			1
		},
	},
	[3] = { // earth
		Atmosphere = {
			Vector(0.66, 0.86, 0.95),
			0.25
		},
		Clouds = {
			Material("infmap_planets/earth_clouds"),
			1
		},
	},
	[4] = { // mars
		Atmosphere = {
			Vector(0.9, 0.65, 0.55),
			0.5
		},
	},
	[5] = { // jupiter
		Atmosphere = {
			Vector(0.9, 0.9, 0.8),
			0.6
		},
	},
	[6] = { // saturn
		Atmosphere = {
			Vector(0.9, 0.85, 0.7),
			0.6
		},
	},
	[7] = { // uranus
		Atmosphere = {
			Vector(0.5, 0.65, 0.7),
			0.8
		},
	},
	[8] = { // neptune
		Atmosphere = {
			Vector(0.2, 0.25, 0.5),
			0.8
		},
	},
}

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
	local planet_type = math.Round(util.SharedRandom("Type" .. x .. y, 1, #InfMap.planet_outside_materials-1))

	return planet_pos, planet_radius, planet_type
end

if CLIENT then return end

// TO THE MAX
hook.Add("InitPostEntity", "infmap_physenv_setup", function()
	local mach = 270079	// mach 20 in hammer units
	physenv.SetPerformanceSettings({MaxVelocity = mach, MaxAngularVelocity = mach})
	RunConsoleCommand("sv_maxvelocity", tostring(mach))
end)
