hook.Add("ShouldCollide", "infinite_shouldcollide", function(ent1, ent2)
	if ent1.CHUNK_OFFSET != ent2.CHUNK_OFFSET then return false end
end)

if CLIENT then return end

// TO THE MAX
hook.Add("InitPostEntity", "infmap_physenv_setup", function()
	local mach_10 = 135039	// mach 10 in hammer units
	physenv.SetPerformanceSettings({MaxVelocity = mach_10, MaxAngularVelocity = mach_10})
	RunConsoleCommand("sv_maxvelocity", tostring(mach_10))

	// SCARY 
	RunConsoleCommand("sv_crazyphysics_remove", "0")
	RunConsoleCommand("sv_crazyphysics_defuse", "0")
end)

local source_max_map_bounds_times_2 = 2^14 * 2
local function is_nan(pos)
	return (pos[1] != pos[1] or pos[2] != pos[2] or pos[3] != pos[3]) or (pos[1] == math.huge or pos[2] == math.huge or pos[3] == math.huge)
end
hook.Add("OnCrazyPhysics", "infmap_crazyphysics", function(ent, phys)
	local pos = phys:InfMap_GetPos()
	if is_nan(pos) or is_nan(phys:GetVelocity()) or is_nan(phys:GetAngleVelocity()) then	// check if the position is nan
		ent:Remove()
	end
	if !InfMap.in_chunk(pos, source_max_map_bounds_times_2) then	// if its farther than it should be
		ent:Remove()
	end
end)

