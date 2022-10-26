// I cannot believe this file even exists

if game.GetMap() != "gm_infinite" then return end

// TO THE MAX
hook.Add("InitPostEntity", "infmap_physenv_setup", function()
	physenv.SetPerformanceSettings({MaxVelocity = 405120, MaxAngularVelocity = 405120}) // mach 30
	RunConsoleCommand("sv_maxvelocity", "405120")
end)
