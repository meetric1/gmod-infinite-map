if game.GetMap() != "gm_infinite" then return end

AddCSLuaFile()

InfMap = InfMap or {}

if SERVER then return end

// this has to be forced in order for render overrides to work
hook.Add("InitPostEntity", "inf_init", function()
	LocalPlayer():ConCommand("cl_drawspawneffect 0")
	LocalPlayer().CHUNK_OFFSET = Vector()
end)

// detour render bounds of entities in other chunks
// needs to be updated every tick since the offset is not local to the prop
// which entities should be checked per frame
local all_ents = {}
local function update_ents(all)
	all_ents = ents.GetAll()
	if all then return end
	for i = #all_ents, 1, -1 do	// iterate downward
		// if invalid is true, then the entity should be removed from the table calculated per frame
		local ent = all_ents[i]
		local invalid = !ent.CHUNK_OFFSET
		invalid = invalid or InfMap.filter_entities(ent)
		//invalid = invalid or ent:GetVelocity() + LocalPlayer():GetVelocity() == Vector()
		invalid = invalid or !ent.RenderOverride
		
		if invalid then
			table.remove(all_ents, i)	// remove invalid entity
		end
	end
end

local update_all = 0
timer.Create("infinite_chunkmove_update", 0.1, 0, function()
	update_all = (update_all + 1) % 10
	update_ents(update_all == 0)
end)
hook.Add("RenderScene", "infinite_update_visbounds", function(eyePos, eyeAngles)
	local chunk_size = Vector(1, 1, 1) * InfMap.chunk_size
	local lp_chunk_offset = LocalPlayer().CHUNK_OFFSET
	for _, ent in ipairs(all_ents) do	// I feel bad for doing this
		if !ent or !ent:IsValid() then continue end
		if !ent.RenderOverride then continue end

		// when bounding box is outside of world bounds the object isn't rendered even though IT SHOULD BE
		// just throw the bounding box right infront of the players eyes, whats the worst that could happen?
		local world_chunk_offset = (ent.CHUNK_OFFSET or Vector()) - lp_chunk_offset
		if world_chunk_offset == Vector() then return end

		local chunk_offset = world_chunk_offset * InfMap.chunk_size * 2
		local prop_dir = (chunk_offset + ent:GetPos() - eyePos)
		if prop_dir:LengthSqr() > 5397 * 5397 then 	// if render bounds is outside normal source bounds it does not render
			prop_dir = prop_dir:GetNormalized() * 5397 // normal source bounds = 2^13
		end

		// grab render bounds in case its been edited (prop resizer compatability)
		if !ent.RENDER_BOUNDS then 
			local min, max = ent:GetRenderBounds() 
			ent.RENDER_BOUNDS = {min, max}
		end

		if world_chunk_offset:LengthSqr() > 2.5 and ent:GetClass() != "infinite_chunk_terrain" then
			ent:SetRenderBoundsWS(eyePos + prop_dir, eyePos + prop_dir)
		else
			ent:SetRenderBoundsWS(eyePos + prop_dir + ent.RENDER_BOUNDS[1], eyePos + prop_dir + ent.RENDER_BOUNDS[2])
		end
	end
end)

// players just.. dont want to render? force rendering..
hook.Add("PostDrawOpaqueRenderables", "infinite_player_render", function()
	local chunk_offset = (LocalPlayer().CHUNK_OFFSET or Vector())
	for k, v in ipairs(player.GetAll()) do
		if v.CHUNK_OFFSET != chunk_offset then
			v:DrawModel()
		end
	end

	// debug lines
	local cs = Vector(1, 1, 1) * InfMap.chunk_size

	//debugoverlay.Sphere(Vector(), 100, 0, Color(255, 0, 0, 0))
	//debugoverlay.Box(Vector(), -cs, cs, 0, Color(0, 0, 0, 0))
	
	local co =  (LocalPlayer().CHUNK_OFFSET or Vector()) * InfMap.chunk_size * 2
	//debugoverlay.Box(Vector(), -cs - co, cs - co, 0, Color(0, 0, 0, 0))
	debugoverlay.Box(Vector(), -cs * 3 - co, cs * 3 - co, 0, Color(0, 0, 255, 0))
	
end)

// server tells clients when a prop has entered another chunk
// detour rendering of entities in other chunks
hook.Add("PropUpdateChunk", "infinite_clientrecev", function(ent, chunk)
	// loop through all ents, offset them relative to player since player has moved
	if ent == LocalPlayer() then 
		for k, v in ipairs(ents.GetAll()) do 
			local min_bound, max_bound = v:GetModelRenderBounds()
			if !min_bound or !max_bound then continue end
			if v == LocalPlayer() or InfMap.filter_entities(v) then continue end
			if v:GetClass() == "infinite_chunk_clone" then continue end

			hook.Run("PropUpdateChunk", v, (v.CHUNK_OFFSET or Vector()))
		end
		timer.Simple(0, function() update_ents(true) end)	// let clients position update
		return 
	end

	// offset single prop relative to player, only the prop has moved
	local chunk_offset = chunk - (LocalPlayer().CHUNK_OFFSET or Vector())

	// if in same chunk, ignore
	// set render bounds back to the value it was at when first stored, if it doesnt exist set it to the model renderbounds
	if chunk_offset == Vector() or ent:GetOwner() == LocalPlayer() then 
		ent.RenderOverride = nil
		
		local min, max
		if ent.RENDER_BOUNDS then min, max = ent.RENDER_BOUNDS[1], ent.RENDER_BOUNDS[2] end
		if min and max then ent:SetRenderBounds(min, max) end
		ent.RENDER_BOUNDS = nil
		if ent.ORIGINAL_PHYSGUN_COLOR then
			ent:SetWeaponColor(ent.ORIGINAL_PHYSGUN_COLOR)
			ent.ORIGINAL_PHYSGUN_COLOR = nil
		end
		return 
	end
	
	print("Detouring rendering of entity:", ent)

	// physgun glow and beam can be seen from any chunk
	// turn physgun off by setting its color to negative infinity if its not in our chunk
	if ent:GetClass() == "player" then
		ent.ORIGINAL_PHYSGUN_COLOR = ent.ORIGINAL_PHYSGUN_COLOR or ent:GetWeaponColor()
		ent:SetWeaponColor(Vector(-math.huge, -math.huge, -math.huge))
	end

	local visual_offset = Vector(1, 1, 1) * (chunk_offset * InfMap.chunk_size * 2)
	if chunk_offset:LengthSqr() > 100 and ent:GetClass() != "infinite_chunk_terrain" then	// lod test
		local render_DrawBox = render.DrawBox
		local render_SetMaterial = render.SetMaterial
		local render_ResetModelLighting = render.ResetModelLighting

		local mat_str = ent:GetMaterial()
		if mat_str == "" then mat_str = ent:GetMaterials()[1] end
		local mat = Material(mat_str)
		ent.RenderOverride = function(self)	// high lod
			render_ResetModelLighting(1, 1, 1)
			render_SetMaterial(mat)
			render_DrawBox(self:GetPos() + visual_offset, self:GetAngles(), self:OBBMins(), self:OBBMaxs())
		end
	else
		local cam_Start3D = cam.Start3D
		local cam_End3D = cam.End3D
		local eyePos = EyePos
		ent.RenderOverride = function(self)	// low lod
			cam_Start3D(eyePos() - visual_offset)
				self:DrawModel()
			cam_End3D()
		end
		
		// THIS IS FOR YOU PROP2MESH
		//if ent.Draw then
			//ent.InfMap_GetWorldTransformMatrix = ent.InfMap_GetWorldTransformMatrix or ent.GetWorldTransformMatrix
			
			//function ent:GetWorldTransformMatrix()
			//	local mat = ent:InfMap_GetWorldTransformMatrix()
			//	mat:SetTranslation(InfMap.unlocalize_vector(mat:GetTranslation(), self.CHUNK_OFFSET))
			//	print("maon gus")
			//	return mat
			//end
		//end
	end
end)
