hook.Add("ShouldCollide", "infinite_shouldcollide", function(ent1, ent2)
	if ent1.CHUNK_OFFSET != ent2.CHUNK_OFFSET then return false end
end)

if CLIENT then return end

// TO THE MAX
hook.Add("InitPostEntity", "infmap_physenv_setup", function()
	physenv.SetPerformanceSettings({MaxVelocity = 405120, MaxAngularVelocity = 40512}) // mach 30
	RunConsoleCommand("sv_maxvelocity", "405120")
end)

