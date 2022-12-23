if SERVER then
	util.AddNetworkString("infmap_particle")
	function InfMap.prop_update_chunk(ent, chunk)
		local prev_chunk = ent.CHUNK_OFFSET
		InfMap.update_track(ent,chunk)
		ent.CHUNK_OFFSET = chunk
		ent:SetCustomCollisionCheck(true)	// required for ShouldCollide hook
		
		// addons may error when calling this
		local err, str = pcall(function() hook.Run("PropUpdateChunk", ent, chunk, prev_chunk) end)
		if !err then ErrorNoHalt(str) end

		// make sure to teleport things in chairs too
		pcall(function()	// IsValid returns true even when the vehicle isnt actually valid, unsure how to properly check this
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
		if ent:IsEFlagSet(EFL_SERVER_ONLY) or ent:IsConstraint() then return end

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
			end
		end
	end
else
	hook.Add("EntityNetworkedVarChanged", "infmap_networkchanged", function(ent, name, oldval, newval)
		if name != "CHUNK_OFFSET" then return end	// not our variable, ignore
		InfMap.prop_update_chunk(ent, newval)
	end)

	// initialize client after prop chunks have been networked
	hook.Add("InitPostEntity", "infmap_initialize", function()
		InfMap.prop_update_chunk(LocalPlayer(), LocalPlayer():GetNW2Vector("CHUNK_OFFSET"))
	end)
end