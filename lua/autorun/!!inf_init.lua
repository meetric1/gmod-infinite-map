if string.Explode("_", string.lower(game.GetMap()))[2] != "infmap" then return end	// initialize infinite map code on maps with 'infmap' as the second word

AddCSLuaFile()

InfMap = InfMap or {}
InfMap.chunk_size = 10000

// Add required files for clients
if SERVER then
	// Load the files
	local function loadfolder(dir)
		local files, dirs = file.Find(dir .. "*","LUA")

		// reoccur in directory
		if dirs then
			for _, d in ipairs(dirs) do
				// only open lua that client or the map name (infmap lua loading during map load)
				local low_d = string.lower(d)
				if low_d == "client" or low_d == string.lower(game.GetMap()) then
					loadfolder(dir .. d .. "/")
				end
			end
		end

		// load files
		if files then
			for _, f in ipairs(files) do
				local prefix = string.lower(string.sub(f, 1, 2))
				if prefix != "sv" then
					AddCSLuaFile(dir .. f)
					print("Loaded ", f)
				end
			end
		end
	end

	loadfolder("infmap/")
end

// Load the files
local function openfolder(dir)
	local files, dirs = file.Find(dir .. "*","LUA")

	// initialize files
	if files then
		for _, f in ipairs(files) do
			local prefix = string.lower(string.sub(f, 1, 2))
			local valid = 		   (CLIENT and prefix != "sv")
			local valid = valid or (SERVER and prefix != "cl")
			if valid then
				include(dir .. f)
				print("Initialized ", f)
			end
		end
	end

	// reoccur in directory
	if dirs then
		for _, d in ipairs(dirs) do
			// only open lua that is server, client or the map name (infmap lua loading during map load)
			local low_d = string.lower(d)
			if low_d == "server" or low_d == "client" or low_d == string.lower(game.GetMap()) then
				openfolder(dir .. d .. "/")
			end
		end
	end
end

openfolder("infmap/")
