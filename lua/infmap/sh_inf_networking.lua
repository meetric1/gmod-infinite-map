if SERVER then
	util.AddNetworkString("INF_PROP_UPDATE")

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

		ent:SetNW2Vector("CHUNK_OFFSET", chunk)

		// network weapons from players always
		if ent:IsPlayer() or ent:IsNPC() then
			//print(ent, "weapons passed in chunk", chunk)
			for _, weapon in ipairs(ent:GetWeapons()) do
				hook.Run("PropUpdateChunk", weapon, chunk, weapon.CHUNK_OFFSET)
				ent.CHUNK_OFFSET = chunk
				ent:SetCustomCollisionCheck(true)
				ent:SetNW2Vector("CHUNK_OFFSET", chunk)
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

	//net.Receive("INF_PROP_UPDATE", function(len, ply)
	//	print("Sending chunk/prop data to", ply)
	//	for _, ent in ipairs(ents.GetAll()) do
	//		if ent:IsConstraint() or ent:GetNoDraw() then continue end
	//		if ent.CHUNK_OFFSET then
	//			net.Start("INF_PROP_UPDATE")
	//			net.WriteEntity(ent)
	//			net.WriteInt(ent.CHUNK_OFFSET[1], 32)
	//			net.WriteInt(ent.CHUNK_OFFSET[2], 32)
	//			net.WriteInt(ent.CHUNK_OFFSET[3], 32)
	//			net.Broadcast()
	//		end
	//	end
	//end)
else
	// I exist!
	hook.Add("InitPostEntity", "infmap_start", function()
		InfMap.prop_update_chunk(LocalPlayer(), LocalPlayer():GetNW2Vector("CHUNK_OFFSET"))
	end)

	//net.Receive("INF_PROP_UPDATE", function(len)
	//	local ent = net.ReadEntity()
	//	if IsValid(ent) then
	//		local chunk = Vector(net.ReadInt(32), net.ReadInt(32), net.ReadInt(32))
	//		print(ent, " passed in chunk ", chunk)
	//		InfMap.prop_update_chunk(ent, chunk)
	//	end
	//end)

	hook.Add("EntityNetworkedVarChanged", "infmap_networkchanged", function(ent, name, oldval, newval)
		print(ent, " passed in chunk ", newval) 
		InfMap.prop_update_chunk(ent, newval)
	end)
end