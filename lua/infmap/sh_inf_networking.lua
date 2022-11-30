if SERVER then
	function InfMap.prop_update_chunk(ent, chunk)
		print(ent, "passed in chunk", chunk)

		local prev_chunk = ent.CHUNK_OFFSET
		InfMap.update_track(ent,chunk)
		ent.CHUNK_OFFSET = chunk
		ent:SetCustomCollisionCheck(true)	// required for ShouldCollide hook

		hook.Run("PropUpdateChunk", ent, chunk, prev_chunk)

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
			for _, weapon in ipairs(ent:GetWeapons()) do
				hook.Run("PropUpdateChunk", weapon, chunk, weapon.CHUNK_OFFSET)
				weapon.CHUNK_OFFSET = chunk
				weapon:SetCustomCollisionCheck(true)
				weapon:SetNW2Vector("CHUNK_OFFSET", chunk)
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
else
	hook.Add("EntityNetworkedVarChanged", "infmap_networkchanged", function(ent, name, oldval, newval)
		if name != "CHUNK_OFFSET" then return end	// not our variable, ignore
		print(ent, " passed in chunk ", newval) 
		InfMap.prop_update_chunk(ent, newval)
	end)

	// initialize client after prop chunks have been networked
	hook.Add("InitPostEntity", "infmap_initialize", function()
		InfMap.prop_update_chunk(LocalPlayer(), LocalPlayer():GetNW2Vector("CHUNK_OFFSET"))
	end)
end