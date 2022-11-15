hook.Add("ShouldCollide", "infinite_shouldcollide", function(ent1, ent2)
	if ent1.CHUNK_OFFSET != ent2.CHUNK_OFFSET then return false end
end)

if CLIENT then return end

// TO THE MAX
hook.Add("InitPostEntity", "infmap_physenv_setup", function()
	local mach_15 = 202559	// mach 15 in hammer units
	physenv.SetPerformanceSettings({MaxVelocity = mach_15, MaxAngularVelocity = mach_15})
	RunConsoleCommand("sv_maxvelocity", tostring(mach_15))
end)

