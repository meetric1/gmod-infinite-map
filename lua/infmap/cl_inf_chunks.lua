// this has to be forced in order for render overrides to work
hook.Add("InitPostEntity", "inf_init", function()
	LocalPlayer():ConCommand("cl_drawspawneffect 0")
end)

local too_far = 100 * 100	// how far away before you just stop rendering entirely ^2
local empty_function = function() end

// detour render bounds of entities in other chunks
// needs to be updated every tick since the offset is not local to the prop
// which entities should be checked per frame
InfMap.all_ents = {}
local function update_ents(all)
	InfMap.all_ents = ents.GetAll()
	if all then return end

	local lpco = LocalPlayer().CHUNK_OFFSET
	for i = #InfMap.all_ents, 1, -1 do	// iterate downward
		// if invalid is true, then the entity should be removed from the table calculated per frame
		local ent = InfMap.all_ents[i]
		local invalid = !ent.CHUNK_OFFSET or !lpco
		invalid = invalid or InfMap.filter_entities(ent)
		invalid = invalid or (!ent.RenderOverride or ent.RenderOverride == empty_function)
		invalid = invalid or ent:GetNoDraw()
		invalid = invalid or (ent.CHUNK_OFFSET - lpco):LengthSqr() > too_far
		invalid = invalid or (ent:GetPos() - EyePos()):Dot(EyeAngles():Forward()) < 0	// behind player
		
		if invalid then
			table.remove(InfMap.all_ents, i)	// remove invalid entity
		end
	end
end

local update_all = false
timer.Create("infinite_chunkmove_update", 0.5, 0, function()
	update_ents(true)
	update_all = true
end)


hook.Add("RenderScene", "!infinite_update_visbounds", function(eyePos, eyeAngles)
	//eyePos = LocalPlayer():GetShootPos()
	local sub_size = (InfMap.source_bounds[1] - InfMap.chunk_size) * 0.5	// how far out render bounds can be before outside of the map
	local lp_chunk_offset = LocalPlayer().CHUNK_OFFSET
	if !lp_chunk_offset then return end
	for _, ent in ipairs(InfMap.all_ents) do	// I feel bad for doing this
		if !IsValid(ent) then continue end
		if !ent.RenderOverride then continue end
		if !ent.CHUNK_OFFSET then continue end

		// when bounding box is outside of world bounds the object isn't rendered
		// to combat this we locally "shrink" the bounds so they are right infront of the players eyes
		local world_chunk_offset = ent.CHUNK_OFFSET - lp_chunk_offset
		if world_chunk_offset == vector_origin then continue end
		if world_chunk_offset:LengthSqr() > too_far then continue end	// too far, dont render

		local prop_dir = (InfMap.unlocalize_vector(ent:InfMap_GetPos(), world_chunk_offset) - eyePos)

		//local shrunk = !far_lod and 0.02 or sub_size / prop_dir:Length()
		local shrunk = sub_size / prop_dir:Length()	// how much you locally shrink render bounds [in reality should be chunksize / prop_dir:Length()]
		prop_dir = prop_dir * shrunk

		// grab render bounds in case its been edited (prop resizer compatability)
		if !ent.RENDER_BOUNDS then 
			local min, max = ent:GetRenderBounds() 
			ent.RENDER_BOUNDS = {min, max}
		end

		if world_chunk_offset:LengthSqr() > 16 then
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

// debug cache
local debug_enabled = CreateClientConVar("infmap_debug", "0", true, false)
local maxsize = InfMap.source_bounds
local black = Color(0, 0, 0, 0)
local red = Color(255, 0, 0, 255)
local blue = Color(0, 0, 255, 255)

// players just.. dont want to render? force rendering..
hook.Add("PostDrawOpaqueRenderables", "infinite_player_render", function()
	if !LocalPlayer().CHUNK_OFFSET then return end
	local chunk_offset = LocalPlayer().CHUNK_OFFSET
	for k, v in ipairs(player.GetAll()) do
		if v.CHUNK_OFFSET != chunk_offset and v:Alive() then
			v:RemoveEffects(EF_DIMLIGHT)	// force flashlight off if in another chunk
		end
	end

	// debug lines
	if !debug_enabled:GetBool() then return end

	local cs = Vector(1, 1, 1) * InfMap.chunk_size
	local co =  chunk_offset * InfMap.chunk_size * 2
	
	render.DrawWireframeSphere(Vector(), 10, 10, 10, red, true)
	render.DrawWireframeBox(Vector(), Angle(), -cs, cs, black, true)
	
	render.DrawWireframeBox(Vector(), Angle(), -cs - co, cs - co, black, true)
	render.DrawWireframeBox(Vector(), Angle(), -maxsize - co, maxsize - co, blue, true)
end)

// server tells clients when a prop has entered another chunk
// detour rendering of entities in other chunks
function InfMap.prop_update_chunk(ent, chunk)
	local prev_chunk = ent.CHUNK_OFFSET
	ent.CHUNK_OFFSET = chunk

	// addons may error when calling this
	local err, str = pcall(function() hook.Run("PropUpdateChunk", ent, chunk, prev_chunk) end)
	if !err then ErrorNoHalt(str) end
	
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
	local is_player = ent:IsPlayer()
	if len > 100 and !is_player then	// make players have no lod so u can see your friends far away :)
		// object is so small and so far away why even bother rendering it
		if ent:BoundingRadius() < 10 or ent:IsWeapon() or len > too_far then // too small or too far, dont bother rendering
			ent.RenderOverride = empty_function
			return 
		end

		local render_DrawBox = render.DrawBox
		local render_SetMaterial = render.SetMaterial

		local mat = Material("models/wireframe")
		local mat_str = ent:GetMaterial()
		if mat_str == "" then mat_str = ent:GetMaterials()[1] end

		if mat_str then mat = Material(mat_str) end
		ent.RenderOverride = function(self)	// high lod
			render_SetMaterial(mat)
			render_DrawBox(self:InfMap_GetPos() + visual_offset, self:GetAngles(), self:OBBMins(), self:OBBMaxs())
		end
	else
		if len > too_far and is_player then ent.RenderOverride = empty_function end

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