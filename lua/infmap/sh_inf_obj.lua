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
local function parse_client_data(object_path, object_name, faces, materials)
	// parse mtl file for materials
	local mtl_data = {}
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
				mtl_data[material] = Material(material_path, "vertexlitgeneric mips smooth noclamp alphatest")
			end
		end
	else
		print("Couldn't find .mtl file when parsing " .. object_name .. "!")
	end

	// build meshes & materials
	for i = 1, #faces do
		local face_mesh = Mesh()
		face_mesh:BuildFromTriangles(faces[i])
		table.insert(InfMap.parsed_objects, {
			mesh = face_mesh,
			material = mtl_data[materials[i]]
		})

		coroutine.yield()	// looks cool
	end

	table.Empty(mtl_data) mtl_data = nil
end


// server generates physmesh data from obj file
local function parse_server_data(faces)
	// combine and split faces into chunks
	for i, face in ipairs(faces) do
		for i = 1, #face, 3 do
			local face_1 = face[i    ].pos
			local face_2 = face[i + 1].pos
			local face_3 = face[i + 2].pos

			local _, chunk_1 = InfMap.localize_vector(face_1)
			local _, chunk_2 = InfMap.localize_vector(face_2)
			local _, chunk_3 = InfMap.localize_vector(face_3)

			local face_1_offset = -InfMap.unlocalize_vector(Vector(), chunk_1)
			local face_2_offset = -InfMap.unlocalize_vector(Vector(), chunk_2)
			local face_3_offset = -InfMap.unlocalize_vector(Vector(), chunk_3)

			local chunk_1_str = InfMap.ezcoord(chunk_1)
			local chunk_2_str = InfMap.ezcoord(chunk_2)
			local chunk_3_str = InfMap.ezcoord(chunk_3)

			InfMap.parsed_collision_data[chunk_1_str] = InfMap.parsed_collision_data[chunk_1_str] or {}
			InfMap.parsed_collision_data[chunk_2_str] = InfMap.parsed_collision_data[chunk_2_str] or {}
			InfMap.parsed_collision_data[chunk_3_str] = InfMap.parsed_collision_data[chunk_3_str] or {}

			local len = #InfMap.parsed_collision_data[chunk_1_str]
			InfMap.parsed_collision_data[chunk_1_str][len + 1] = {pos = face_1 + face_1_offset}
			InfMap.parsed_collision_data[chunk_1_str][len + 2] = {pos = face_2 + face_1_offset}
			InfMap.parsed_collision_data[chunk_1_str][len + 3] = {pos = face_3 + face_1_offset}

			if chunk_2 != chunk_1 then
				local len = #InfMap.parsed_collision_data[chunk_2_str]
				InfMap.parsed_collision_data[chunk_2_str][len + 1] = {pos = face_1 + face_2_offset}
				InfMap.parsed_collision_data[chunk_2_str][len + 2] = {pos = face_2 + face_2_offset}
				InfMap.parsed_collision_data[chunk_2_str][len + 3] = {pos = face_3 + face_2_offset}
			end

			if chunk_3 != chunk_2 and chunk_3 != chunk_1 then
				local len = #InfMap.parsed_collision_data[chunk_3_str]
				InfMap.parsed_collision_data[chunk_3_str][len + 1] = {pos = face_1 + face_3_offset}
				InfMap.parsed_collision_data[chunk_3_str][len + 2] = {pos = face_2 + face_3_offset}
				InfMap.parsed_collision_data[chunk_3_str][len + 3] = {pos = face_3 + face_3_offset}
			end
		end

		print("Finished parsing face " .. i .. "/" .. #faces)
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
	if !v_str then return 0 end

	local v_num = tonumber(v_str)
	return v_num > 0 and v_num or v_num % max + 1
end

// Main parsing function
function InfMap.parse_obj(object_name, scale, client_only, world_offset)
	if SERVER and client_only then return end
	if not world_offset then world_offset = Vector(0, 0, 0) end

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
		local group = 0
		local material = 0
		local vertices = {}
		local uvs = {}
		local normals = {}
		local materials = {}
		local faces = {}

		// sort the data
		local split_obj = string.Split(obj, "\n")
		for i, newline_data in ipairs(split_obj) do
			// get data from line
			local line_data = string.Split(newline_data, " ")
			local first = table.remove(line_data, 1)

			// vertex processing
			if first == "v" then
				vertices[group][#vertices[group] + 1] = Vector(-tonumber(line_data[1]), tonumber(line_data[3]), tonumber(line_data[2])) * scale
			elseif first == "vt" then
				uvs[group][#uvs[group] + 1] = Vector(tonumber(line_data[1]), tonumber(line_data[2]))
			elseif first == "vn" then
				normals[group][#normals[group] + 1] = Vector(-tonumber(line_data[1]), tonumber(line_data[3]), tonumber(line_data[2]))
			elseif first == "f" then // face processing
				local total_data = #line_data
				if !faces[material] then
					print("Material undefined for group " .. group)
					material = material + 1
					faces[material] = {}
				end

				// n gon support
				for i = 3, total_data do
					// who tf uses negative indexes?!??
					// why am I adding support for this!?
					local max_verts = #vertices[group]
					local max_uvs = #uvs[group]
					local max_normals = #normals[group]
				
					// get our vertex indices data
					local vertex1 = string.Split(line_data[i - 1], "/")
					local vertex2 = string.Split(line_data[1], "/")
					local vertex3 = string.Split(line_data[i], "/")

					local vertex1_pos = vertices[group][unfuck_negative(vertex1[1], max_verts)] + world_offset
					local vertex2_pos = vertices[group][unfuck_negative(vertex2[1], max_verts)] + world_offset
					local vertex3_pos = vertices[group][unfuck_negative(vertex3[1], max_verts)] + world_offset

					// degenerate triangle check
					if (vertex1_pos - vertex2_pos):Cross(vertex1_pos - vertex3_pos):LengthSqr() < 0.0001 then continue end

					local face_len = #faces[material]
					local uv = uvs[group][unfuck_negative(vertex1[2], max_uvs)]
					faces[material][face_len + 1] = {
						pos = vertex1_pos,
						u = vertex1[2] and uv[1],
						v = vertex1[2] and -uv[2],
						normal = normals[group][unfuck_negative(vertex1[3], max_normals)] + world_offset
					}

					uv = uvs[group][unfuck_negative(vertex2[2], max_uvs)]
					faces[material][face_len + 2] = {
						pos = vertex2_pos,
						u = vertex2[2] and uv[1],
						v = vertex2[2] and -uv[2],
						normal = normals[group][unfuck_negative(vertex2[3], max_normals)] + world_offset
					}

					uv = uvs[group][unfuck_negative(vertex3[2], max_uvs)]
					faces[material][face_len + 3] = {
						pos = vertex3_pos,
						u = vertex3[2] and uv[1],
						v = vertex3[2] and -uv[2],
						normal = normals[group][unfuck_negative(vertex3[3], max_normals)] + world_offset
					}
				end
			elseif first == "usemtl" then // material
				material = material + 1
				faces[material] = {}
				materials[material] = line_data[1]
			elseif first == "g" or first == "o" then	// increment groups of tris
				if first == "o" and group != 0 then 
					continue 
				end

				group = group + 1
				vertices[group] = {}
				uvs[group] = {}
				normals[group] = {}
			end

			if i % yield_quota == 0 then
				print(object_name .. " " .. math.floor((i / #split_obj) * 100) .. "%")
				coroutine.yield()
			end
		end

		if CLIENT then
			parse_client_data(object_path, object_name, faces, materials)
		end

		if !client_only then
			parse_server_data(faces)
		end

		// free data (memory leak moment)
		table.Empty(vertices) vertices = nil
		table.Empty(uvs) uvs = nil
		table.Empty(normals) normals = nil
		table.Empty(materials) materials = nil
		table.Empty(faces) faces = nil
		world_offset = nil
		print("Finished parsing " .. object_name)
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
	if CLIENT and !(ent == LocalPlayer() or ent:GetClass() == "infmap_obj_collider") then return end

	local chunk_coord = InfMap.ezcoord(chunk)
	if InfMap.parsed_objects[chunk_coord] then return end
	local chunk_data = InfMap.parsed_collision_data[chunk_coord]
	if !chunk_data then return end

	if SERVER then
		local collider = ents.Create("infmap_obj_collider")
		collider:SetModel("models/props_junk/CinderBlock01a.mdl")
		collider:Spawn()
		collider:UpdateCollision(chunk_data)
		InfMap.prop_update_chunk(collider, chunk)
		print("Spawning collider in chunk " .. chunk_coord)
		InfMap.parsed_objects[chunk_coord] = collider
	else
		// try to find a collider in our chunk
		for _, collider in ipairs(ents.FindByClass("infmap_obj_collider")) do
			if collider.CHUNK_OFFSET != LocalPlayer().CHUNK_OFFSET then continue end
			if IsValid(collider:GetPhysicsObject()) then continue end

			print("Updating collider in " .. chunk_coord)

			// weird hack to prevent null physobjs on client
			if !collider.UpdateCollision then
				collider.RENDER_MESH = chunk_data
			else
				collider:UpdateCollision(chunk_data)
			end

			// we found our collider, stop looking
			break
		end
	end
end

hook.Add("PropUpdateChunk", "infmap_obj_spawn", build_object_collision)
