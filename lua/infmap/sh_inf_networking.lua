if SERVER then
	util.AddNetworkString("INF_PROP_UPDATE")

	local function send_data(ent, chunk)
		net.Start("INF_PROP_UPDATE")
		net.WriteUInt(ent:EntIndex(), 16)
		net.WriteInt(chunk[1], 32)
		net.WriteInt(chunk[2], 32)
		net.WriteInt(chunk[3], 32)
		net.Broadcast()
	end

	function InfMap.prop_update_chunk(ent, chunk)
		hook.Run("PropUpdateChunk", ent, chunk, ent.CHUNK_OFFSET)
		print(ent, "passed in chunk", chunk)
		ent.CHUNK_OFFSET = chunk
		ent:SetCustomCollisionCheck(true)	// required for ShouldCollide hook

		// make sure to teleport things in chairs too
		pcall(function()	// vehicles when initialized arent actually initialized and dont actually have their datatables set up
			if ent.GetDriver and IsValid(ent:GetDriver()) then
				InfMap.prop_update_chunk(ent:GetDriver(), chunk)
			end
		end)

		if SERVER and ent.CHUNK_CLONES then	// remove all clones since it has moved chunks, (so we can rebuild clones)
			for _, e in pairs(ent.CHUNK_CLONES) do	// (ipairs doesnt work since index is sortof random)
				SafeRemoveEntity(e)
			end
			ent.CHUNK_CLONES = nil
		end

		// dont network bad ents to client, they may not even be able to see them
		if ent:GetNoDraw() or ent:IsConstraint() then return end

		send_data(ent, chunk)

		// network weapons from players always
		if ent:IsPlayer() or ent:IsNPC() then
			//print(ent, "weapons passed in chunk", chunk)
			for _, weapon in ipairs(ent:GetWeapons()) do
				hook.Run("PropUpdateChunk", weapon, chunk, weapon.CHUNK_OFFSET)
				ent.CHUNK_OFFSET = chunk
				ent:SetCustomCollisionCheck(true)
				send_data(weapon, chunk)	// force weapons because they are nodraw
			end
		end

		if !IsValid(ent:GetParent()) then
			for _, parent in ipairs(InfMap.get_all_parents(ent)) do
				if parent == ent then continue end
				InfMap.prop_update_chunk(parent, chunk)
				print("parent passed", parent)
			end
		end
	end

	// it exists!
	net.Receive("INF_PROP_UPDATE", function(len, ply)
		print("Sending chunk/prop data to", ply)
		for _, ent in ipairs(ents.GetAll()) do
			if ent:IsConstraint() or ent:GetNoDraw() then continue end
			if ent.CHUNK_OFFSET then
				local chunk = ent.CHUNK_OFFSET
				send_data(ent, ent.CHUNK_OFFSET)
			end
		end
	end)
else
	local function update_prop(ent_index, chunk)
		local ent = Entity(ent_index)
		print(ent, " passed in chunk ", chunk)
		InfMap.prop_update_chunk(Entity(ent_index), chunk)
	end

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