AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= ""
ENT.PrintName		= ""
ENT.Author			= "Mee"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable		= false

InfMap.planet_uv_scale = 5

/**************** CLIENT *****************/

local function planet_mountains(x, y)
    local x, y = x / 10000, y / 10000
    return InfMap.simplex.Noise2D(x, y) * 1000 + InfMap.simplex.Noise3D(x, y, 10)^2 * InfMap.simplex.Noise3D(x * 10, y * 10, 0) * 10000
end

local function inside_planet(x, y, size)
    return x * x + y * y < size * size
end

/****************** SERVER *********************/
 
function ENT:BuildCollision(heightFunction, size)
    local chunk = self.CHUNK_OFFSET
    local final_mesh = {}
    local chunk_resolution = 64
    for y = 0, chunk_resolution - 1 do
        for x = 0, chunk_resolution - 1 do
            // chunk offset in world space
            local chunkoffsetx = chunk[1]
            local chunkoffsety = chunk[2]

            local x1 = (x    ) / chunk_resolution
            local y1 = (y    ) / chunk_resolution
            local x2 = (x + 1) / chunk_resolution
            local y2 = (y + 1) / chunk_resolution
            local min_pos_x = -size + x1 * size * 2
            local min_pos_y = -size + y1 * size * 2
            local max_pos_x = -size + x2 * size * 2
            local max_pos_y = -size + y2 * size * 2

            local in_a = inside_planet(min_pos_x, min_pos_y, size)
            local in_b = inside_planet(min_pos_x, max_pos_y, size)
            local in_c = inside_planet(max_pos_x, min_pos_y, size)
            local in_d = inside_planet(max_pos_x, max_pos_y, size)

            // all 4 points are outside of the sphere, cut this quad off.
            if !(in_a or in_b or in_c or in_d) then
                continue
            end

            // vertex positions in local space
            local vertexPos1 = Vector(min_pos_x, min_pos_y, heightFunction(min_pos_x, min_pos_y))
            local vertexPos2 = Vector(min_pos_x, max_pos_y, heightFunction(min_pos_x, max_pos_y))
            local vertexPos3 = Vector(max_pos_x, min_pos_y, heightFunction(max_pos_x, min_pos_y))
            local vertexPos4 = Vector(max_pos_x, max_pos_y, heightFunction(max_pos_x, max_pos_y))

            // round positions to a circle if they are cut off
            if !in_a then
                vertexPos1 = vertexPos1:GetNormalized() * size
                vertexPos1[3] = heightFunction(vertexPos1[1], vertexPos1[2])
            end

            if !in_b then
                vertexPos2 = vertexPos2:GetNormalized() * size
                vertexPos2[3] = heightFunction(vertexPos2[1], vertexPos2[2])
            end

            if !in_c then
                vertexPos3 = vertexPos3:GetNormalized() * size
                vertexPos3[3] = heightFunction(vertexPos3[1], vertexPos3[2])
            end

            if !in_d then
                vertexPos4 = vertexPos4:GetNormalized() * size
                vertexPos4[3] = heightFunction(vertexPos4[1], vertexPos4[2])
            end


            table.Add(final_mesh, {
                {pos = vertexPos1},
                {pos = vertexPos2},
                {pos = vertexPos3},

                {pos = vertexPos2},
                {pos = vertexPos3},
                {pos = vertexPos4}
            })
        end
    end

    self:PhysicsDestroy()
	self:PhysicsFromMesh(final_mesh)
end


function ENT:Initialize()
    if CLIENT then 
        if !self.CHUNK_OFFSET then return end
        self:GenerateMesh(planet_mountains, self.CHUNK_OFFSET, InfMap.chunk_size)
        self:GenerateTrees(planet_mountains, InfMap.chunk_size)
    end

    self:BuildCollision(planet_mountains, InfMap.chunk_size)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:EnableCustomCollisions(true)
    self:DrawShadow(false)
    self:AddSolidFlags(FSOLID_FORCE_WORLD_ALIGNED)
    self:AddFlags(FL_STATICPROP)
    //self:AddFlags(FL_DONTTOUCH)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:SetMass(50000)  // max weight should help a bit with the physics solver
        phys:AddGameFlag(FVPHYSICS_CONSTRAINT_STATIC)
        phys:AddGameFlag(FVPHYSICS_NO_SELF_COLLISIONS)
    end
end

// Client stuff from now on
if SERVER then return end

 // ripped from my terrain addon
 local function smoothedNormal(heightFunction, vertexPos, size)
    local smoothedNormal = Vector()
    for cornery = 0, 1 do
        for cornerx = 0, 1 do
            // get 4 corners in a for loop ranging from -1 to 1
            local cornerx = (cornerx - 0.5) * 2
            local cornery = (cornery - 0.5) * 2

            // get the height of the 0x triangle
            local cornerWorldx = vertexPos[1]
            local cornerWorldy = vertexPos[2] + cornery * size
            local cornerHeight = heightFunction(cornerWorldx, cornerWorldy) * 2
            local middleXPosition = Vector(cornerWorldx, cornerWorldy, cornerHeight)

            // get the height of the 0y triangle
            local cornerWorldx = vertexPos[1] + cornerx * size
            local cornerWorldy = vertexPos[2]
            local cornerHeight = heightFunction(cornerWorldx, cornerWorldy) * 2
            local middleYPosition = Vector(cornerWorldx, cornerWorldy, cornerHeight)

            // we now have 3 points, construct a triangle from this and add the normal to the average normal
            local triNormal = (middleYPosition - vertexPos):Cross(middleXPosition - vertexPos) * cornerx * cornery
            smoothedNormal = smoothedNormal + triNormal
        end
    end

    return smoothedNormal
end

function ENT:GenerateTrees(heightFunction, size)
    self.TreeMatrices = {}
    self.TreeModels = {}
    self.TreeColors = {}

    local randomIndex = 0
    local chunkIndex = tostring(self.CHUNK_OFFSET[1]) .. tostring(self.CHUNK_OFFSET[2])
    local chunk_resolution = 32
    for y = 0, chunk_resolution - 1 do
        for x = 0, chunk_resolution - 1 do
            randomIndex = randomIndex + 1
            local m = Matrix()

            // generate seeded random position for tree
            local randseedx = util.SharedRandom("TerrainSeedX" .. chunkIndex, 0, 1, randomIndex)
            local randseedy = util.SharedRandom("TerrainSeedY" .. chunkIndex, 0, 1, randomIndex)
            local randPos = Vector(x + randseedx - chunk_resolution * 0.5, y + randseedy - chunk_resolution * 0.5) * (size / chunk_resolution) * 2

            // tree is not in planet, bail
            if !inside_planet(randPos[1], randPos[2], size - 250) then continue end

            local finalPos = Vector(randPos[1], randPos[2], heightFunction(randPos[1], randPos[2]) - 45)
            m:SetTranslation(finalPos)
            m:SetAngles(Angle(0, randseedx * 3600, 0))//smoothedNormal:Angle() + Angle(90, 0, 0) Angle(0, randseedx * 3600, 0)
            m:SetScale(Vector(2, 2, 2))
            table.insert(self.TreeMatrices, m)
            //table.insert(self.TreeModels, 1)  // 4.1 means 1/50 chance for a rock to generate instead of a tree
            table.insert(self.TreeColors, Vector(1, 1, 1))
        end
    end
end

local default_mat = Material("phoenix_storms/ps_grass")
function ENT:GenerateMesh(heightFunction, chunk, size)
    // planet is a bit cursed since they are spherical, we need to cut off and round the edges of the chunk
	local triangles = {}
    local chunk_resolution = 64
    for y = 0, chunk_resolution - 1 do
        for x = 0, chunk_resolution - 1 do
            // chunk offset in world space
            local chunkoffsetx = chunk[1]
            local chunkoffsety = chunk[2]

            local x1 = (x    ) / chunk_resolution
            local y1 = (y    ) / chunk_resolution
            local x2 = (x + 1) / chunk_resolution
            local y2 = (y + 1) / chunk_resolution
            local min_pos_x = -size + x1 * size * 2
            local min_pos_y = -size + y1 * size * 2
            local max_pos_x = -size + x2 * size * 2
            local max_pos_y = -size + y2 * size * 2

            local in_a = inside_planet(min_pos_x, min_pos_y, size)
            local in_b = inside_planet(min_pos_x, max_pos_y, size)
            local in_c = inside_planet(max_pos_x, min_pos_y, size)
            local in_d = inside_planet(max_pos_x, max_pos_y, size)

            // all 4 points are outside of the sphere, cut this quad off.
            if !(in_a or in_b or in_c or in_d) then
                continue
            end

            // vertex positions in local space
            local vertexPos1 = Vector(min_pos_x, min_pos_y, heightFunction(min_pos_x, min_pos_y))
            local vertexPos2 = Vector(min_pos_x, max_pos_y, heightFunction(min_pos_x, max_pos_y))
            local vertexPos3 = Vector(max_pos_x, min_pos_y, heightFunction(max_pos_x, min_pos_y))
            local vertexPos4 = Vector(max_pos_x, max_pos_y, heightFunction(max_pos_x, max_pos_y))

            // round positions to a circle if they are cut off
            if !in_a then
                vertexPos1 = vertexPos1:GetNormalized() * size
                vertexPos1[3] = heightFunction(vertexPos1[1], vertexPos1[2])
            end

            if !in_b then
                vertexPos2 = vertexPos2:GetNormalized() * size
                vertexPos2[3] = heightFunction(vertexPos2[1], vertexPos2[2])
            end

            if !in_c then
                vertexPos3 = vertexPos3:GetNormalized() * size
                vertexPos3[3] = heightFunction(vertexPos3[1], vertexPos3[2])
            end

            if !in_d then
                vertexPos4 = vertexPos4:GetNormalized() * size
                vertexPos4[3] = heightFunction(vertexPos4[1], vertexPos4[2])
            end

            local normal_size = size / chunk_resolution
            local normal1 = smoothedNormal(heightFunction, vertexPos1, normal_size)
            local normal2 = smoothedNormal(heightFunction, vertexPos2, normal_size)
            local normal3 = smoothedNormal(heightFunction, vertexPos3, normal_size)
            local normal4 = smoothedNormal(heightFunction, vertexPos4, normal_size)

            table.Add(triangles, {
                {vertexPos1, 0, 			         0,	  		 	         normal1},
                {vertexPos2, InfMap.planet_uv_scale, 0,    			         normal2},
                {vertexPos3, 0,	  		             InfMap.planet_uv_scale, normal3},

                {vertexPos3, 0, 	    	         InfMap.planet_uv_scale, normal3},
                {vertexPos2, InfMap.planet_uv_scale, 0,  	           	     normal2},
                {vertexPos4, InfMap.planet_uv_scale, InfMap.planet_uv_scale, normal4}
            })
        end
    end

    self.RENDER_MESH = {Mesh = Mesh(default_mat), Material = default_mat}
    local mesh = mesh
    mesh.Begin(self.RENDER_MESH.Mesh, MATERIAL_TRIANGLES, math.min(#triangles / 3, 2^13))
        for _, tri in ipairs(triangles) do
            mesh.Position(tri[1])
            mesh.TexCoord(0, tri[2], tri[3])
            mesh.Normal(tri[4])
            mesh.UserData(1, 1, 1, 1)
            mesh.AdvanceVertex()
        end
    mesh.End()

    self:SetRenderBounds(-Vector(1, 1, 1) * size, Vector(1, 1, 1) * size)
end

function ENT:Think()
    if !IsValid(self:GetPhysicsObject()) and self.CHUNK_OFFSET then
        print("Rebuilding Collisions for chunk ", self.CHUNK_OFFSET)
        self:Initialize()
    end
end
    
// cache ALL of these for faster lookup
local render_SetLightmapTexture = render.SetLightmapTexture
local render_SetMaterial = render.SetMaterial
local render_SetModelLighting = render.SetModelLighting
local render_SetLocalModelLights = render.SetLocalModelLights
local cam_PushModelMatrix = cam.PushModelMatrix
local cam_PopModelMatrix = cam.PopModelMatrix
local math_DistanceSqr = math.DistanceSqr
local tree_material = Material("models/props_foliage/arbre01")
local tree_mesh = Mesh()
tree_mesh:BuildFromTriangles(util.GetModelMeshes("models/props_foliage/tree_pine_large.mdl", 8)[1].triangles)

// this MUST be optimized as much as possible, it is called multiple times every frame
function ENT:GetRenderMesh()
    local self = self
    if !self.RENDER_MESH then return end

    // get local vars
    local models = self.TreeModels
    local color = self.TreeColors
    local matrices = self.TreeMatrices
    local flashlightOn = LocalPlayer():FlashlightIsOn()

    // reset lighting
    render_SetLocalModelLights()
    render_SetModelLighting(1, 0.1, 0.1, 0.1)
    render_SetModelLighting(3, 0.1, 0.1, 0.1)
    render_SetModelLighting(5, 0.1, 0.1, 0.1)

    render.SetMaterial(Material("models/XQM/WoodPlankTexture"))
    render.DrawSphere(self:InfMap_GetPos(), InfMap.chunk_size, 100, 100)
    //render.DrawSphere(self:InfMap_GetPos(), -InfMap.chunk_size, 100, 100)

    if EyePos():DistToSqr(self:GetPos()) > InfMap.chunk_size * InfMap.chunk_size then return end

    render_SetMaterial(tree_material)

    // render foliage
    local lastlight
    for i = 1, #matrices do
        local matrix = matrices[i]
        local modelID = models[i]
           
        // give the tree its shading
        local tree_color = color[i]
        if tree_color != lastlight then
            local color_shade = tree_color * 0.45
            render_SetModelLighting(0, color_shade[1], color_shade[2], color_shade[3])
            render_SetModelLighting(2, tree_color[1], tree_color[2], tree_color[3])
            render_SetModelLighting(4, tree_color[1], tree_color[2], tree_color[3])
            lastlight = tree_color
        end

        // push custom matrix generated earlier and render the tree
        cam_PushModelMatrix(matrix)
            tree_mesh:Draw()
            if flashlightOn then   // flashlight compatability
                render.PushFlashlightMode(true)
                tree_mesh:Draw()
                render.PopFlashlightMode()
            end
        cam_PopModelMatrix()
    end

    // render the chunk mesh itself
    return self.RENDER_MESH
end