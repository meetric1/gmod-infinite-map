// this has to be forced in order for render overrides to work
hook.Add("InitPostEntity", "inf_init", function()
	LocalPlayer():ConCommand("cl_drawspawneffect 0")
end)

// detour render bounds of entities in other chunks
// needs to be updated every tick since the offset is not local to the prop
// which entities should be checked per frame
InfMap.all_ents = {}
local function update_ents(all)
	InfMap.all_ents = ents.GetAll()
	if all then return end
	for i = #InfMap.all_ents, 1, -1 do	// iterate downward
		// if invalid is true, then the entity should be removed from the table calculated per frame
		local ent = InfMap.all_ents[i]
		local invalid = !ent.CHUNK_OFFSET
		invalid = invalid or InfMap.filter_entities(ent)
		//invalid = invalid or ent:GetVelocity() + LocalPlayer():GetVelocity() == Vector()
		invalid = invalid or !ent.RenderOverride
		invalid = invalid or ent:GetNoDraw()
		
		if invalid then
			table.remove(InfMap.all_ents, i)	// remove invalid entity
		end
	end
end

local update_all = false
timer.Create("infinite_chunkmove_update", 1, 0, function()
	update_ents(true)
	update_all = true
end)

hook.Add("RenderScene", "!infinite_update_visbounds", function(eyePos, eyeAngles)
	//eyePos = LocalPlayer():GetShootPos()
	local sub_size = 2^14 - InfMap.chunk_size - 64	// how far out render bounds can be before outside of the map
	local sub_size_sqr = sub_size * sub_size
	local lp_chunk_offset = LocalPlayer().CHUNK_OFFSET
	if !lp_chunk_offset then return end
	for _, ent in ipairs(InfMap.all_ents) do	// I feel bad for doing this
		if !IsValid(ent) then continue end
		if !ent.RenderOverride then continue end
		if !ent.CHUNK_OFFSET then continue end

		// when bounding box is outside of world bounds the object isn't rendered
		// to combat this we locally "shrink" the bounds so they are right infront of the players eyes
		local world_chunk_offset = ent.CHUNK_OFFSET - lp_chunk_offset
		if world_chunk_offset == Vector() then continue end

		local prop_dir = (InfMap.unlocalize_vector(ent:InfMap_GetPos(), world_chunk_offset) - eyePos)

		//local shrunk = !far_lod and 0.02 or sub_size / prop_dir:Length()
		local shrunk = 0.02	// how much you locally shrink render bounds [in reality should be chunksize / prop_dir:Length()]
		if prop_dir:LengthSqr() < sub_size_sqr then
			shrunk = 1
		end

		prop_dir = prop_dir * shrunk

		// grab render bounds in case its been edited (prop resizer compatability)
		if !ent.RENDER_BOUNDS then 
			local min, max = ent:GetRenderBounds() 
			ent.RENDER_BOUNDS = {min, max}
		end

		if world_chunk_offset:LengthSqr() > 16 then
			if prop_dir:LengthSqr() > 100000000 then
				prop_dir = prop_dir * 0.01
			end
			ent:SetRenderBoundsWS(eyePos + prop_dir, eyePos + prop_dir)
		else
			// if entity angle is perfectly 0,0,0 GetRotatedAABB returns Vector(),Vector() for some reason
			local min, max
			if ent:GetAngles() != Angle() then	
				min, max = ent:GetRotatedAABB(ent.RENDER_BOUNDS[1], ent.RENDER_BOUNDS[2])
			else
				min, max = ent.RENDER_BOUNDS[1], ent.RENDER_BOUNDS[2]
			end

			min = min * shrunk
			max = max * shrunk
			ent:SetRenderBoundsWS(eyePos + prop_dir + min, eyePos + prop_dir + max)
			//debugoverlay.Box(eyePos + prop_dir, min, max, 0, Color(0, 0, 255, 0))
		end
	end

	if update_all then 
		update_ents()
		update_all = false
	end
end)

// players just.. dont want to render? force rendering..
hook.Add("PostDrawOpaqueRenderables", "infinite_player_render", function()
	local chunk_offset = (LocalPlayer().CHUNK_OFFSET or Vector())
	for k, v in ipairs(player.GetAll()) do
		if v.CHUNK_OFFSET != chunk_offset and v:Alive() then
			v:DrawModel()
			v:RemoveEffects(EF_DIMLIGHT)	// force flashlight off if in another chunk
		end
	end

	// debug lines
	local cs = Vector(1, 1, 1) * InfMap.chunk_size

	debugoverlay.Sphere(Vector(), 100, 0, Color(255, 0, 0, 0))
	debugoverlay.Box(Vector(), -cs, cs, 0, Color(0, 0, 0, 0))
	
	local co =  chunk_offset * InfMap.chunk_size * 2
	debugoverlay.Box(Vector(), -cs - co, cs - co, 0, Color(0, 0, 0, 0))
	debugoverlay.Box(Vector(), -Vector(2^14, 2^14, 2^14) - co, Vector(2^14, 2^14, 2^14) - co, 0, Color(0, 0, 255, 0))
	
end)

// server tells clients when a prop has entered another chunk
// detour rendering of entities in other chunks
local empty_function = function() end
function InfMap.prop_update_chunk(ent, chunk)
	local prev_chunk = ent.CHUNK_OFFSET
	ent.CHUNK_OFFSET = chunk

	hook.Run("PropUpdateChunk", ent, chunk, prev_chunk)
	
	// loop through all ents, offset them relative to player since player has moved
	if ent == LocalPlayer() then 
		for k, v in ipairs(ents.GetAll()) do 
			local min_bound, max_bound = v:GetModelRenderBounds()
			if !min_bound or !max_bound then continue end
			if v == ent or InfMap.filter_entities(v) then continue end
			//v.CHUNK_OFFSET = v.CHUNK_OFFSET or prev_chunk	// corpse support
			if !v.CHUNK_OFFSET then continue end

			InfMap.prop_update_chunk(v, v.CHUNK_OFFSET)
		end
		return 
	end

	// clientside models support
	for _, parent in ipairs(ent:GetChildren()) do
		if parent:EntIndex() != -1 then continue end
		InfMap.prop_update_chunk(parent, chunk)	// update renderoverride
	end

	// when first spawning in props will attempt to render offset before client has initialized
	// after prop chunks have been networked to client we initalize them and therefore update all prop rendering
	if !IsValid(LocalPlayer()) or InfMap.filter_entities(ent) then return end

	// offset single prop relative to player, only the prop has moved
	local chunk_offset = chunk - LocalPlayer().CHUNK_OFFSET

	// if in same chunk, ignore
	// set render bounds back to the value it was at when first stored, if it doesnt exist set it to the model renderbounds
	if chunk_offset == Vector() then 
		if ent.ValidRenderOverride != nil then
			ent.RenderOverride = ent.OldRenderOverride
		end
		ent.OldRenderOverride = nil
		ent.ValidRenderOverride = nil
		
		local min, max
		if ent.RENDER_BOUNDS then min, max = ent.RENDER_BOUNDS[1], ent.RENDER_BOUNDS[2] end
		if min and max then 
			ent:SetRenderBounds(min, max) 
		end

		ent.RENDER_BOUNDS = nil
		if ent.ORIGINAL_PHYSGUN_COLOR then
			ent:SetWeaponColor(ent.ORIGINAL_PHYSGUN_COLOR)
			ent.ORIGINAL_PHYSGUN_COLOR = nil
		end
		return 
	end
	
	//print("Detouring rendering of entity:", ent)

	// put ent in table to update renderbounds
	table.insert(InfMap.all_ents, ent)

	// physgun glow and beam can be seen from any chunk
	// turn physgun off by setting its color to negative infinity if its not in our chunk
	if ent:IsPlayer() then
		ent.ORIGINAL_PHYSGUN_COLOR = ent.ORIGINAL_PHYSGUN_COLOR or ent:GetWeaponColor()
		ent:SetWeaponColor(Vector(-math.huge, -math.huge, -math.huge))
	end

	local visual_offset = Vector(1, 1, 1) * (chunk_offset * InfMap.chunk_size * 2)
	if ent.ValidRenderOverride == nil then
		ent.OldRenderOverride = ent.RenderOverride
		ent.ValidRenderOverride = ent.RenderOverride and true or false
	end
	
	// lod test
	local len = chunk_offset:LengthSqr()
	if len > 100 and !ent:IsPlayer() then	// make players have no lod so u can see your friends far away :)
		// object is so small and so far away why even bother rendering it
		if ent:BoundingRadius() < 10 or ent:IsWeapon() or len > 150*150 then // too small or too far, dont bother rendering
			ent.RenderOverride = empty_function
			return 
		end
		local render_DrawBox = render.DrawBox
		local render_SetMaterial = render.SetMaterial
		local render_ResetModelLighting = render.ResetModelLighting

		local mat_str = ent:GetMaterial()
		if mat_str == "" then mat_str = ent:GetMaterials()[1] end
		if !mat_str then mat_str = "models/wireframe" end
		local mat = Material(mat_str)
		ent.RenderOverride = function(self)	// high lod
			render_SetMaterial(mat)
			render_DrawBox(self:InfMap_GetPos() + visual_offset, self:GetAngles(), self:OBBMins(), self:OBBMaxs())
		end
	else
		local cam_Start3D = cam.Start3D
		local cam_End3D = cam.End3D
		local eyePos = EyePos
		if !ent.ValidRenderOverride then
			ent.RenderOverride = function(self)	// low lod
				cam_Start3D(eyePos() - visual_offset)
				self:DrawModel()
				cam_End3D()
			end
		else
			ent.RenderOverride = function(self)	// low lod
				cam_Start3D(eyePos() - visual_offset)
				self:OldRenderOverride()
				cam_End3D()
			end
		end
	end
end
