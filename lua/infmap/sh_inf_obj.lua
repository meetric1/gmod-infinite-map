// obj parser
local yield_quota = 2500
InfMap.parsed_collision_data = InfMap.parsed_collision_data or {}
InfMap.parsed_objects = InfMap.parsed_objects or {}

// creates collisions for chunk .objs (defined later)
local build_object_collision

// finds & returns path to a file with a given name
local function find_path(path, file_name)
	local files, dir = file.Find(path .. "/*", "GAME")
	for _, name in ipairs(files) do
		if string.Split(name, ".")[1] == file_name then
			return path
		end
	end

	for _, name in ipairs(dir) do
		local found = find_path(path .. "/" .. name, file_name)
		if found then 
			return found
		end
	end
end

// client generates meshes & materials from obj data
local function parse_client_data(object_path, object_name)
	// parse mtl file for materials
	InfMap.parsed_data.mtl_data = {}
	local mtl = file.Read(object_path .. "/" .. object_name .. ".mtl", "GAME")
	if mtl then
		local mtl_split = string.Split(mtl, "\n")
		local material
		for i = 1, #mtl_split do
			local data = string.Split(mtl_split[i], " ")
			local first = table.remove(data, 1)

			if first == "newmtl" then 
				material = string.Trim(data[1])
			end

			if first == "map_Kd" then
				local material_path = object_path .. "/" .. string.Trim(data[1])
				InfMap.parsed_data.mtl_data[material] = Material(material_path, "vertexlitgeneric mips smooth noclamp")	// alphatest
			end
		end
	else
		print("Couldn't find .mtl file when parsing " .. object_name .. "!")
	end

	// build meshes & materials
	for i = 1, #InfMap.parsed_data.faces do
		local face_mesh = Mesh()
		face_mesh:BuildFromTriangles(InfMap.parsed_data.faces[i])
		table.insert(InfMap.parsed_objects, {
			mesh = face_mesh,
			material = InfMap.parsed_data.mtl_data[InfMap.parsed_data.materials[i]]
		})

		coroutine.yield()	// looks cool
	end
end


// server generates physmesh data from obj file
// tris are in the format collisiondata[chunk][mat] = {{pos = Vector}, {pos = Vector}, {pos = Vector}...}
local function parse_server_data()
	local function add_data(chunk, face1, face2, face3)
		local chunk_str = InfMap.ezcoord(chunk)
		InfMap.parsed_collision_data[chunk_str] = InfMap.parsed_collision_data[chunk_str] or {{}}
		local parsed_len = #InfMap.parsed_collision_data[chunk_str]
		local parsed_tri_len = #InfMap.parsed_collision_data[chunk_str][parsed_len]
		if parsed_tri_len > yield_quota * 3 then
			InfMap.parsed_collision_data[chunk_str][parsed_len + 1] = {}
			parsed_tri_len = 0
			parsed_len = parsed_len + 1
		end

		local offset = -InfMap.unlocalize_vector(Vector(), chunk)
		InfMap.parsed_collision_data[chunk_str][parsed_len][parsed_tri_len + 1] = {pos = face1 + offset}
		InfMap.parsed_collision_data[chunk_str][parsed_len][parsed_tri_len + 2] = {pos = face2 + offset}
		InfMap.parsed_collision_data[chunk_str][parsed_len][parsed_tri_len + 3] = {pos = face3 + offset}
	end

	// combine and split faces into chunks
	for mat, face in ipairs(InfMap.parsed_data.faces) do
		for i = 1, #face, 3 do
			local face1 = face[i    ].pos
			local face2 = face[i + 1].pos
			local face3 = face[i + 2].pos

			// too small, dont bother generating collision
			if (face1 - face2):Cross(face1 - face3):LengthSqr() < 100000 then continue end

			local _, chunk1 = InfMap.localize_vector(face1)
			local _, chunk2 = InfMap.localize_vector(face2)
			local _, chunk3 = InfMap.localize_vector(face3)

			add_data(chunk1, face1, face2, face3)

			if chunk2 != chunk1 then
				add_data(chunk2, face1, face2, face3)
			end

			if chunk3 != chunk2 and chunk3 != chunk1 then
				add_data(chunk3, face1, face2, face3)
			end
		end

		print("Finished parsing face " .. mat .. "/" .. #InfMap.parsed_data.faces)
		coroutine.yield()
	end

	print("Finished parsing collision")

	for k, v in ipairs(player.GetAll()) do
		if !v.CHUNK_OFFSET then continue end
		build_object_collision(v, v.CHUNK_OFFSET)
	end
end

// stupid obj format
local function unfuck_negative(v_str, max)
	if !v_str or v_str == "" then return 0 end

	local v_num = tonumber(v_str)
	return v_num > 0 and v_num or v_num % max + 1
end

// Main parsing function
function InfMap.parse_obj(object_name, scale, client_only)
	if SERVER and client_only then return end

	// clear all collision data
	table.Empty(InfMap.parsed_collision_data)

	// find location of obj name
	local object_path = find_path("models/infmap", object_name)
	if !object_path then 
		print("Couldn't find .obj path when parsing " .. object_name .. "! (is the file in models/infmap/ ?)")
		return 
	end

	// actual obj file
	local obj = file.Read(object_path .. "/" .. object_name .. ".obj", "GAME")
	if !obj then 
		print("Couldn't find .obj file when parsing " .. object_name .. "!")
		return 
	end

	// time to parse
	local coro = coroutine.create(function()
		local err, str = pcall(function()
		local group = 0
		local material = 0
		InfMap.parsed_data = {}
		InfMap.parsed_data.vertices = {}
		InfMap.parsed_data.uvs = {}
		InfMap.parsed_data.normals = {}
		InfMap.parsed_data.materials = {}
		InfMap.parsed_data.faces = {}

		// sort the data
		local split_obj = string.Split(obj, "\n")
		local split_obj_len = #split_obj
		for i = 1, split_obj_len do
			// get data from line
			local line_data = string.Split(split_obj[i], " ")
			local first = table.remove(line_data, 1)

			// vertex processing
			if first == "v" then
				table.insert(InfMap.parsed_data.vertices[group], Vector(-tonumber(line_data[1]), tonumber(line_data[3]), tonumber(line_data[2])) * scale)

			// only client uses uvs and normals
			elseif first == "vt" and CLIENT then	
				table.insert(InfMap.parsed_data.uvs[group], Vector(tonumber(line_data[1]), tonumber(line_data[2])))
			elseif first == "vn" and CLIENT then
				table.insert(InfMap.parsed_data.normals[group], Vector(-tonumber(line_data[1]), tonumber(line_data[3]), tonumber(line_data[2])))

			// face processing
			elseif first == "f" then 
				// sometimes a material isnt defined, not sure why.. define empty one
				if !InfMap.parsed_data.faces[material] then
					print("Material undefined for group " .. group)
					material = material + 1
					InfMap.parsed_data.faces[material] = {}
				end
				
				// who tf uses negative indexes?!??
				// why am I adding support for this!?
				local max_verts = #InfMap.parsed_data.vertices[group]
				local max_uvs = #InfMap.parsed_data.uvs[group]
				local max_normals = #InfMap.parsed_data.normals[group]

				// n gon support
				for i = 3, #line_data do
					// get our vertex indices data
					local vertex1 = string.Split(line_data[i - 1], "/")
					local vertex2 = string.Split(line_data[1], "/")
					local vertex3 = string.Split(line_data[i], "/")

					local vertex1_pos = InfMap.parsed_data.vertices[group][unfuck_negative(vertex1[1], max_verts)]
					local vertex2_pos = InfMap.parsed_data.vertices[group][unfuck_negative(vertex2[1], max_verts)]
					local vertex3_pos = InfMap.parsed_data.vertices[group][unfuck_negative(vertex3[1], max_verts)]

					// degenerate triangle check
					if (vertex1_pos - vertex2_pos):Cross(vertex1_pos - vertex3_pos):LengthSqr() < 0.0001 then continue end

					local face_len = #InfMap.parsed_data.faces[material]
					local uv = InfMap.parsed_data.uvs[group][unfuck_negative(vertex1[2], max_uvs)]
					InfMap.parsed_data.faces[material][face_len + 1] = {
						pos = vertex1_pos,
						u = uv and  uv[1],
						v = uv and -uv[2],	// reverse triangle winding
						normal = InfMap.parsed_data.normals[group][unfuck_negative(vertex1[3], max_normals)]
					}

					uv = InfMap.parsed_data.uvs[group][unfuck_negative(vertex2[2], max_uvs)]
					InfMap.parsed_data.faces[material][face_len + 2] = {
						pos = vertex2_pos,
						u = uv and  uv[1],
						v = uv and -uv[2],
						normal = InfMap.parsed_data.normals[group][unfuck_negative(vertex2[3], max_normals)]
					}

					uv = InfMap.parsed_data.uvs[group][unfuck_negative(vertex3[2], max_uvs)]
					InfMap.parsed_data.faces[material][face_len + 3] = {
						pos = vertex3_pos,
						u = uv and  uv[1],
						v = uv and -uv[2],
						normal = InfMap.parsed_data.normals[group][unfuck_negative(vertex3[3], max_normals)]
					}
				end
			elseif first == "usemtl" then // material
				material = material + 1
				InfMap.parsed_data.faces[material] = {}
				InfMap.parsed_data.materials[material] = string.Trim(line_data[1])
			elseif first == "g" or first == "o" then	// increment groups of tris
				if first == "o" and group != 0 then 
					continue 
				end

				group = group + 1
				InfMap.parsed_data.vertices[group] = {}
				InfMap.parsed_data.uvs[group] = {}
				InfMap.parsed_data.normals[group] = {}
			end

			table.Empty(line_data) line_data = nil

			if i % yield_quota == 0 then
				print(object_name .. " " .. math.floor((i / split_obj_len) * 100) .. "%")
				coroutine.yield()
			end
		end

		if CLIENT then
			parse_client_data(object_path, object_name)
		end

		if !client_only then
			parse_server_data()
		end

		// free data
		table.Empty(split_obj) split_obj = nil
		table.Empty(InfMap.parsed_data) InfMap.parsed_data = nil
		print("Finished parsing " .. object_name)
		end)
		if !err then print(str) end
	end)

	hook.Add("Think", "infmap_parse" .. object_name, function() 
		if coroutine.status(coro) == "suspended" then
			coroutine.resume(coro)
		else
			hook.Remove("Think", "infmap_parse" .. object_name)
		end
	end)
end

if CLIENT then
	// render parsed objs
	local ambient = render.GetLightColor(Vector())
	local model_lights = {{ 
		type = MATERIAL_LIGHT_DIRECTIONAL,
		color = Vector(2, 2, 2),
		dir = Vector(1, 1, 1):GetNormalized(),
	}}
	local default_material = CreateMaterial("infmap_objdefault", "VertexLitGeneric", {
		["$basetexture"] = "dev/graygrid", 
		["$model"] = 1, 
		["$nocull"] = 1,
		["$alpha"] = 1
	})
	hook.Add("PostDrawOpaqueRenderables", "infmap_obj_render", function()
		local sun = util.GetSunInfo()
		if sun and sun.direction then
			model_lights[1].dir = -sun.direction
		end
		render.SetLocalModelLights(model_lights) // no lighting
		render.ResetModelLighting(ambient[1], ambient[2], ambient[3])

		cam.Start3D(InfMap.unlocalize_vector(EyePos(), LocalPlayer().CHUNK_OFFSET))
		for _, object in ipairs(InfMap.parsed_objects) do
			render.SetMaterial(object.material or default_material)
			object.mesh:Draw()
		end
		cam.End3D()
	end)
end

build_object_collision = function(ent, chunk)
	if SERVER and InfMap.filter_entities(ent) then return end
	if CLIENT and ent != LocalPlayer() then return end

	local chunk_coord = InfMap.ezcoord(chunk)
	if IsValid(InfMap.parsed_objects[chunk_coord]) then return end

	local chunk_data = InfMap.parsed_collision_data[chunk_coord]
	if !chunk_data then return end

	if SERVER then
		print("Spawning colliders in chunk " .. chunk_coord)
		for i = 1, #chunk_data do
			local collider = ents.Create("infmap_obj_collider")
			collider:SetModel("models/props_junk/CinderBlock01a.mdl")
			collider:Spawn()
			collider:UpdateCollision(chunk_data[i])
			InfMap.prop_update_chunk(collider, chunk)
			InfMap.parsed_objects[chunk_coord] = collider
		end
	else
		timer.Simple(0, function()	// race condition
			print("Updating colliders in chunk " .. chunk_coord)

			// try to find a collider in our chunk
			local collider_len = #chunk_data
			local collider_count = 1
			for _, collider in ipairs(ents.FindByClass("infmap_obj_collider")) do
				if collider.CHUNK_OFFSET != LocalPlayer().CHUNK_OFFSET then continue end
				if collider:GetPhysicsObject():IsValid() then continue end
				
				// weird hack to prevent null physobjs on client
				if !collider.UpdateCollision then
					collider.RENDER_MESH = chunk_data[collider_count]
				else
					collider:UpdateCollision(chunk_data[collider_count])
				end

				collider_count = collider_count + 1

				// we found our colliders, stop looking
				if collider_count > collider_len then
					break
				end
			end
		end)
	end
end

hook.Add("PropUpdateChunk", "infmap_obj_spawn", build_object_collision)
