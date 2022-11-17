hook.Add("ShouldCollide", "infinite_shouldcollide", function(ent1, ent2)
	if ent1.CHUNK_OFFSET != ent2.CHUNK_OFFSET then return false end
end)

if CLIENT then return end

// TO THE MAX
hook.Add("InitPostEntity", "infmap_physenv_setup", function()
	local mach = 270079	// mach 20 in hammer units
	physenv.SetPerformanceSettings({MaxVelocity = mach, MaxAngularVelocity = mach})
	RunConsoleCommand("sv_maxvelocity", tostring(mach))
end)

