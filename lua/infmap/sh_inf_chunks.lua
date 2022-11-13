hook.Add("ShouldCollide", "infinite_shouldcollide", function(ent1, ent2)
	if ent1.CHUNK_OFFSET != ent2.CHUNK_OFFSET then return false end
end)

if CLIENT then return end

// TO THE MAX
hook.Add("InitPostEntity", "infmap_physenv_setup", function()
	local mach_25 = 337598	// mach 25 in hammer units
	physenv.SetPerformanceSettings({MaxVelocity = mach_25, MaxAngularVelocity = mach_25 / 2})
	RunConsoleCommand("sv_maxvelocity", tostring(mach_25))

	// SCARY 
	RunConsoleCommand("sv_crazyphysics_remove", "0")
	RunConsoleCommand("sv_crazyphysics_defuse", "0")
end)

