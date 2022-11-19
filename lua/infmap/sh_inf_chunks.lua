hook.Add("ShouldCollide", "infinite_shouldcollide", function(ent1, ent2)
	local co1, co2 = ent1.CHUNK_OFFSET, ent2.CHUNK_OFFSET
	if co1 and co2 and co1 != co2 then return false end
end)

if CLIENT then return end

// TO THE MAX
hook.Add("InitPostEntity", "infmap_physenv_setup", function()
	local mach = 270079	// mach 20 in hammer units
	physenv.SetPerformanceSettings({MaxVelocity = mach, MaxAngularVelocity = mach})
	RunConsoleCommand("sv_maxvelocity", tostring(mach))
end)

