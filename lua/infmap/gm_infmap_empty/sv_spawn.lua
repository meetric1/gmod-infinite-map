local function resetAll()
	local e = ents.Create("prop_physics")
	e:InfMap_SetPos(Vector(0, 0, -10))
	e:SetModel("models/hunter/blocks/cube8x8x025.mdl")
	e:SetMaterial("models/combine_scanner/scanner_eye")
	e:Spawn()
	e:GetPhysicsObject():EnableMotion(false)
	e:SetMoveType(MOVETYPE_NONE)
	InfMap.prop_update_chunk(e, Vector())
end

hook.Add("InitPostEntity", "infmap_terrain_init", resetAll)
hook.Add("PostCleanupMap", "infmap_cleanup", resetAll)