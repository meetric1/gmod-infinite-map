// obj parser
local yield_quota = 2500
InfMap.parsed_collision_data = InfMap.parsed_collision_data or {}
InfMap.parsed_objects = InfMap.parsed_objects or {}

// creates collisions for chunk .objs
local build_object_collision
if SERVER then
	build_object_collision = function(ent, chunk)
		if InfMap.filter_entities(ent) then return end

		local chunk_coord = InfMap.ezcoord(chunk)
		local chunk_data = InfMap.parsed_collision_data[chunk_coord]
		if !chunk_data then return end

		print("Spawning in chunk " .. chunk_coord)
		local collider = ents.Create("infmap_obj")
		collider:SetModel("models/props_junk/CinderBlock01a.mdl")
		collider:InfMap_SetPos(Vector())
		collider:SetAngles(Angle())
		collider:Spawn()
		collider:UpdateCollision(chunk_data)
		InfMap.prop_update_chunk(collider, chunk)
		table.Empty(InfMap.parsed_collision_data[chunk_coord]) InfMap.parsed_collision_data[chunk_coord] = nil	// bgone memory
	end
else
	build_object_collision = function(ent, chunk)
		timer.Simple(0, function() // ugh, have do this because of race condition
			if ent != LocalPlayer() then return end

			local chunk_coord = InfMap.ezcoord(chunk)
			local chunk_data = InfMap.parsed_collision_data[chunk_coord]
			if !chunk_data then return end

			// find object to parent collisions to
			for _, collider in ipairs(ents.FindByClass("infmap_obj")) do
				if collider.CHUNK_OFFSET != chunk then continue end
				if !collider.UpdateCollision then continue end
				
				print("Spawning in chunk " .. chunk_coord)
				collider:UpdateCollision(chunk_data)
				InfMap.prop_update_chunk(collider, chunk)
				table.Empty(InfMap.parsed_collision_data[chunk_coord]) InfMap.parsed_collision_data[chunk_coord] = nil	// bgone memory
				break
			end
		end)
	end
end

local function find_path(path, file_name)
	local files, dir = file.Find(path .. "/*", "GAME")
	for _, name in ipairs(files) do
		if string.Split(name, ".")[1] == file_name then
			return dir
		end
	end

	for _, name in ipairs(dir) do
		local found = find_path(path .. "/" .. name, file_name)
		if found then 
			return path .. "/" .. name
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
			material = mtl_data[materials[i]], 
			mesh = face_mesh
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
			local face_1 = face[i    ]
			local face_2 = face[i + 1]
			local face_3 = face[i + 2]

			local _, chunk_1 = InfMap.localize_vector(face_1.pos)
			local _, chunk_2 = InfMap.localize_vector(face_2.pos)
			local _, chunk_3 = InfMap.localize_vector(face_3.pos)

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
			InfMap.parsed_collision_data[chunk_1_str][len + 1] = {pos = face_1.pos + face_1_offset}
			InfMap.parsed_collision_data[chunk_1_str][len + 2] = {pos = face_2.pos + face_1_offset}
			InfMap.parsed_collision_data[chunk_1_str][len + 3] = {pos = face_3.pos + face_1_offset}

			if chunk_2 != chunk_1 then
				local len = #InfMap.parsed_collision_data[chunk_2_str]
				InfMap.parsed_collision_data[chunk_2_str][len + 1] = {pos = face_1.pos + face_2_offset}
				InfMap.parsed_collision_data[chunk_2_str][len + 2] = {pos = face_2.pos + face_2_offset}
				InfMap.parsed_collision_data[chunk_2_str][len + 3] = {pos = face_3.pos + face_2_offset}
			end

			if chunk_3 != chunk_2 and chunk_3 != chunk_1 then
				local len = #InfMap.parsed_collision_data[chunk_3_str]
				InfMap.parsed_collision_data[chunk_3_str][len + 1] = {pos = face_1.pos + face_3_offset}
				InfMap.parsed_collision_data[chunk_3_str][len + 2] = {pos = face_2.pos + face_3_offset}
				InfMap.parsed_collision_data[chunk_3_str][len + 3] = {pos = face_3.pos + face_3_offset}
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

	// find location of obj name
	local object_path = find_path("models/infmap", object_name)
	local obj = file.Read(object_path .. "/" .. object_name .. ".obj", "GAME")

	// obj file doesnt exist, bail
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

	// takes in table of 3 data points, if the triangle is valid adds to faces
	local function add_triangle(abc) 
		if !faces[material] then
			print("Material undefined for group " .. group)
			material = material + 1
			faces[material] = {}
		end

		local triangle = {}
		for i = 1, 3 do
			local vertex = string.Split(abc[i], "/")
			local vert = tonumber(vertex[1])
			local uv = tonumber(vertex[2])
			local normal = tonumber(vertex[3])
			
			triangle[i] = {
				pos = vert and vertices[group][vert > 0 and vert or vert % #vertices[group] + 1],
				u = uv and  uvs[group][uv > 0 and uv or uv % #uvs[group] + 1][1],
				v = uv and -uvs[group][uv > 0 and uv or uv % #uvs[group] + 1][2],
				normal = normal and normals[group][normal > 0 and normal or normal % #normals[group] + 1]
			}
		end

		// degenerate triangle check (infinitely thin)
		if (triangle[1].pos - triangle[2].pos):Cross(triangle[1].pos - triangle[3].pos):LengthSqr() > 0.0001 then
			table.Add(faces[material], triangle)
		end

		table.Empty(triangle) triangle = nil
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
					add_triangle({line_data[i - 1], line_data[1], line_data[i]})
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
	local default_material = Material("hunter/myplastic")
	local ambient = render.GetLightColor(Vector()) * 0.5
	local model_lights = {{ 
		type = MATERIAL_LIGHT_DIRECTIONAL,
		color = Vector(2, 2, 2),
	}}
	hook.Add("PostDrawOpaqueRenderables", "infmap_obj_render", function()
		model_lights[1].dir = -(util.GetSunInfo().direction or Vector(0.7, 0.7, 0.7))
		render.SetLocalModelLights(model_lights) // no lighting
		render.ResetModelLighting(ambient[1], ambient[2], ambient[3])

		default_material:SetFloat("$alpha", 1)
		cam.Start3D(InfMap.unlocalize_vector(EyePos(), LocalPlayer().CHUNK_OFFSET))
		for _, object in ipairs(InfMap.parsed_objects) do
			render.SetMaterial(object.material or default_material)
			object.mesh:Draw()
		end
		cam.End3D()
	end)
end

hook.Add("PropUpdateChunk", "infmap_obj_spawn", build_object_collision)
