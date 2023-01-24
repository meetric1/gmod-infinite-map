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
		local material = 0
		for i = 1, #mtl_split do
			local data = string.Split(mtl_split[i], " ")
			local first = table.remove(data, 1)

			if first == "newmtl" then 
				material = data[1]
			end

			if first == "map_Kd" then
				local material_path = object_path .. "/" .. string.Trim(data[1])
				mtl_data[material] = Material(material_path, "vertexlitgeneric mips smooth noclamp nocull")
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
local function parse_server_data(vertices, faces)
	// combine and split faces into chunks
	for i, face in ipairs(faces) do
		for i = 1, #face, 3 do
			local face_1 = Vector(face[i    ].pos)
			local face_2 = Vector(face[i + 1].pos)
			local face_3 = Vector(face[i + 2].pos)

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

	local group = 0
	local material = 0
	local vertices = {}
	local uvs = {}
	local normals = {}
	local faces = {}
	local materials = {}

	// stupid obj format
	local function unfuck_negative(v_str, max)
		if !v_str then return 0 end

		local v_num = tonumber(v_str)
		return v_num > 0 and v_num or v_num % max + 1
	end

	// takes in table of 3 data points, if the triangle is valid adds to faces
	local function add_triangle(a, b, c) 
		if !faces[material] then
			print("Material undefined for group " .. group)
			material = material + 1
			faces[material] = {}
		end

		local err, str = pcall(function()
		local max_verts = #vertices[group]
		local max_uvs = #uvs[group]
		local max_normals = #normals[group]

		local vertex1 = string.Split(a, "/")
		local vertex1_pos = vertices[group][unfuck_negative(vertex1[1], max_verts)]
		
		local vertex2 = string.Split(b, "/")
		local vertex2_pos = vertices[group][unfuck_negative(vertex2[1], max_verts)]
		
		local vertex3 = string.Split(c, "/")
		local vertex3_pos = vertices[group][unfuck_negative(vertex3[1], max_verts)]

		// degenerate triangle check
		if (vertex1_pos - vertex2_pos):Cross(vertex1_pos - vertex3_pos):LengthSqr() < 0.0001 then return end

		local vertex1_uv = uvs[group][unfuck_negative(vertex1[2], max_uvs)] or {0, 0}
		local vertex1_normal = normals[group][unfuck_negative(vertex1[3], max_normals)]
		local vertex2_uv = uvs[group][unfuck_negative(vertex2[2], max_uvs)] or {0, 0}
		local vertex2_normal = normals[group][unfuck_negative(vertex2[3], max_normals)]
		local vertex3_uv = uvs[group][unfuck_negative(vertex3[2], max_uvs)] or {0, 0}
		local vertex3_normal = normals[group][unfuck_negative(vertex3[3], max_normals)]

		table.insert(faces[material], {
			pos = vertex1_pos,
			u = vertex1_uv[1],
			v = -vertex1_uv[2],	// flip v since we flip y axis in obj to account for source having Z as up
			normal = vertex1_normal,
		})

		table.insert(faces[material], {
			pos = vertex2_pos,
			u = vertex2_uv[1],
			v = -vertex2_uv[2],	
			normal = vertex2_normal,
		})

		table.insert(faces[material], {
			pos = vertex3_pos,
			u = vertex3_uv[1],
			v = -vertex3_uv[2],	
			normal = vertex3_normal,
		})
		end)
		if !err then print(str) end
	end

	// time to parse
	local coro = coroutine.create(function()
		// sort the data
		local split_obj = string.Split(obj, "\n")
		for i, newline_data in ipairs(split_obj) do
			// get data from line
			local line_data = string.Split(newline_data, " ")
			local first = table.remove(line_data, 1)

			// vertex processing
			if first == "v" then
				table.insert(vertices[group], Vector(-tonumber(line_data[1]), tonumber(line_data[3]), tonumber(line_data[2])) * scale)
			end

			if first == "vt" then
				table.insert(uvs[group], Vector(tonumber(line_data[1]), tonumber(line_data[2])))
			end

			if first == "vn" then
				table.insert(normals[group], Vector(-tonumber(line_data[1]), tonumber(line_data[3]), tonumber(line_data[2])))
			end

			// face processing
			if first == "f" then
				local total_data = #line_data
				// n gon support
				for i = 3, total_data do
					add_triangle(line_data[i - 1], line_data[1], line_data[i])
				end
			end

			// material
			if first == "usemtl" then
				material = material + 1
				faces[material] = {}
				materials[material] = line_data[1]
			end

			// increment groups of tris
			if first == "g" or first == "o" then
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
			parse_server_data(vertices, faces)
		end

		// free memory
		// pretty sure these are all freed automatically because of local variables, but lets just be safe
		table.Empty(vertices) vertices = nil
		table.Empty(uvs) uvs = nil
		table.Empty(normals) normals = nil
		table.Empty(materials) materials = nil
		table.Empty(faces) faces = nil
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
	local ambient = render.GetLightColor(Vector()) * 0.5
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
	local chunk_data = InfMap.parsed_collision_data[chunk_coord]
	if !chunk_data then return end

	

	local collider
	if SERVER then
		collider = ents.Create("infmap_obj_collider")
		collider:SetModel("models/props_junk/CinderBlock01a.mdl")
		collider:Spawn()
		InfMap.prop_update_chunk(collider, chunk)
		print("Spawning collider in chunk " .. chunk_coord)
	else
		// try to find a collider in our chunk
		for _, col in ipairs(ents.FindByClass("infmap_obj_collider")) do
			if col.CHUNK_OFFSET != chunk or !col.UpdateCollision then continue end
			collider = col
			break
		end
	end

	if !collider or IsValid(collider:GetPhysicsObject()) then return end

	print("Updating collider in " .. chunk_coord)
	collider:UpdateCollision(chunk_data)
	table.Empty(InfMap.parsed_collision_data[chunk_coord]) InfMap.parsed_collision_data[chunk_coord] = nil	// bgone memory
end

hook.Add("PropUpdateChunk", "infmap_obj_spawn", build_object_collision)
