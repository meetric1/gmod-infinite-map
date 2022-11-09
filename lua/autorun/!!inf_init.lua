if game.GetMap() != "gm_infinite" then return end

AddCSLuaFile()

InfMap = InfMap or {}

// Add required files for clients
if SERVER then
	// add shared files
	local shared_files, shared_dirs = file.Find("infmap/*","LUA")
	if shared_files then
		for _, f in ipairs(shared_files) do
			AddCSLuaFile("infmap/" .. f)
			print("Included ".. f)
		end
	end

	// add client files
	if shared_dirs then
		local client_files, client_dirs = file.Find("infmap/client/*","LUA")
		if client_files then
			for _, f in ipairs(client_files) do
				AddCSLuaFile("infmap/client/" .. f)
				print("Included ".. f)
			end
		end
	end
end

// Load the files
local function openfolder(dir)
	local files, dirs = file.Find(dir.."*","LUA")

	// reoccur in directory
	if dirs then
		for _, d in ipairs(dirs) do
			openfolder(dir .. d .. "/")
		end
	end

	// initialize files
	if files then
		for _, f in ipairs(files) do
			local prefix = string.sub(f, 1, 2)
			local valid = 		   (CLIENT and prefix != "sv")
			local valid = valid or (SERVER and prefix != "cl")
			if valid then
				include(dir .. f)
				print("Loaded ", f)
			end
		end
	end
end

openfolder("infmap/")
