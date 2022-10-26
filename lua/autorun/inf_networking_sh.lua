if game.GetMap() != "gm_infinite" then return end

AddCSLuaFile()

if SERVER then
	util.AddNetworkString("INF_PROP_UPDATE")
	util.AddNetworkString("INF_FLASHLIGHT_OFF")

	local function send_data(ent, chunk)
		net.Start("INF_PROP_UPDATE")
		net.WriteUInt(ent:EntIndex(), 16)
		net.WriteInt(chunk[1], 32)
		net.WriteInt(chunk[2], 32)
		net.WriteInt(chunk[3], 32)
		net.Broadcast()
	end

	hook.Add("PropUpdateChunk", "server", function(ent, chunk)
		print(ent, "passed in chunk", chunk)
		ent.CHUNK_OFFSET = chunk
		ent:SetCustomCollisionCheck(true)	// required for ShouldCollide hook

		// make sure to teleport things in chairs too
		pcall(function()	// vehicles when initialized arent actually initialized and dont actually have their datatables set up
			if ent.GetDriver and ent:GetDriver():IsValid() then
				hook.Run("PropUpdateChunk", ent:GetDriver(), chunk)
			end
		end)

		// dont network bad ents to client, they may not even be able to see them
		if (InfMap.filter_entities(ent) or ent:GetNoDraw()) and ent:GetClass() != "infmap_clone" then return end	

		send_data(ent, chunk)

		// network weapons from players always
		if ent:IsPlayer() or ent:IsNPC() then
			//print(ent, "weapons passed in chunk", chunk)
			for _, weapon in ipairs(ent:GetWeapons()) do
				ent.CHUNK_OFFSET = chunk
				ent:SetCustomCollisionCheck(true)
				send_data(weapon, chunk)
			end
		end
	end)

	// it exists!
	net.Receive("INF_PROP_UPDATE", function(len, ply)
		print("Sending chunk/prop data to", ply)
		for _, ent in ipairs(ents.GetAll()) do
			if (InfMap.filter_entities(ent) or ent:GetNoDraw()) and ent:GetClass() != "infmap_clone" then continue end
			if ent.CHUNK_OFFSET then
				local chunk = ent.CHUNK_OFFSET
				send_data(ent, ent.CHUNK_OFFSET)
			end
		end
	end)

	// when flashlight is turned on network it to players
	hook.Add("PlayerSwitchFlashlight", "infinite_flashlight_detour", function(ply, enabled)
		if !enabled then return end
		for _, v in ipairs(player.GetAll()) do
			if ply.CHUNK_OFFSET != v.CHUNK_OFFSET then
				net.Start("INF_FLASHLIGHT_OFF")
				net.WriteInt(ply:EntIndex(), 16)
				net.Send(v)
			end
		end
	end)
else
	local function update_prop(ent_index, chunk)
		local ent = Entity(ent_index)
		hook.Run("PropUpdateChunk", Entity(ent_index), chunk)
	end

	// turn player flashlight off
	net.Receive("INF_FLASHLIGHT_OFF", function()
		local ply_idx = net.ReadInt(16)
		timer.Create("inf_flashlight_antigay"..ply_idx, 0.01, 100, function()	//flashlight has a random delay for some reason
			local ply = Entity(ply_idx)
			if ply:IsValid() and ply:FlashlightIsOn() then
				ply:RemoveEffects(EF_DIMLIGHT)
				timer.Remove("inf_flashlight_antigay"..ply_idx)
			end
		end)
	end)

	net.Receive("INF_PROP_UPDATE", function()
		local ent_index = net.ReadUInt(16)
		local chunk = Vector(net.ReadInt(32), net.ReadInt(32), net.ReadInt(32))

		if Entity(ent_index):IsValid() then
			update_prop(ent_index, chunk)
		else
			timer.Create("TryPropUpdateChunk" .. ent_index, 0.01, 100, function()
				if Entity(ent_index):IsValid() then
					update_prop(ent_index, chunk)
					timer.Remove("TryPropUpdateChunk" .. ent_index)
				else
					//print("Cant find entity "..ent_index)
				end
			end)
		end
	end)

	// I exist!
	local function resetAll()
		net.Start("INF_PROP_UPDATE")
		net.SendToServer()
	end
	hook.Add("InitPostEntity", "infinitemap_request", resetAll)
	hook.Add("PostCleanupMap", "infmap_cleanup", resetAll)
end