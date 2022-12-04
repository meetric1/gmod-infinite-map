AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= ""
ENT.PrintName		= ""
ENT.Author			= "Mee"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable		= false

if !InfMap then return end

/****************** ENTITY DATA *********************/

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "PlanetRadius")
end

function ENT:BuildCollision(heightFunction, chunk, size)
    local cox = chunk[1] * InfMap.chunk_size
    local coy = chunk[2] * InfMap.chunk_size

    local final_mesh = {}
    local chunk_resolution = InfMap.planet_resolution
    for y = 0, chunk_resolution - 1 do
        for x = 0, chunk_resolution - 1 do
            local x1 = (x    ) / chunk_resolution
            local y1 = (y    ) / chunk_resolution
            local x2 = (x + 1) / chunk_resolution
            local y2 = (y + 1) / chunk_resolution
            local min_pos_x = -size + x1 * size * 2
            local min_pos_y = -size + y1 * size * 2
            local max_pos_x = -size + x2 * size * 2
            local max_pos_y = -size + y2 * size * 2

            // vertex positions in local space
            local vertexPos1 = Vector(min_pos_x, min_pos_y, heightFunction(min_pos_x + cox, min_pos_y + coy))
            local vertexPos2 = Vector(min_pos_x, max_pos_y, heightFunction(min_pos_x + cox, max_pos_y + coy))
            local vertexPos3 = Vector(max_pos_x, min_pos_y, heightFunction(max_pos_x + cox, min_pos_y + coy))
            local vertexPos4 = Vector(max_pos_x, max_pos_y, heightFunction(max_pos_x + cox, max_pos_y + coy))

            local in_a = vertexPos1:LengthSqr() < size * size
            local in_b = vertexPos2:LengthSqr() < size * size
            local in_c = vertexPos3:LengthSqr() < size * size
            local in_d = vertexPos4:LengthSqr() < size * size

            // all 4 points are outside of the sphere, cut this quad off.
            if !(in_a or in_b or in_c or in_d) then
                continue
            end

            // round positions to a circle if they are cut off
            if !in_a then
                vertexPos1 = vertexPos1:GetNormalized() * size
                vertexPos1[3] = heightFunction(vertexPos1[1] + cox, vertexPos1[2] + coy)
            end

            if !in_b then
                vertexPos2 = vertexPos2:GetNormalized() * size
                vertexPos2[3] = heightFunction(vertexPos2[1] + cox, vertexPos2[2] + coy)
            end

            if !in_c then
                vertexPos3 = vertexPos3:GetNormalized() * size
                vertexPos3[3] = heightFunction(vertexPos3[1] + cox, vertexPos3[2] + coy)
            end

            if !in_d then
                vertexPos4 = vertexPos4:GetNormalized() * size
                vertexPos4[3] = heightFunction(vertexPos4[1] + cox, vertexPos4[2] + coy)
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
        self:GenerateMesh(InfMap.planet_height_function, self.CHUNK_OFFSET, self:GetPlanetRadius())
        // generate trees if it has grass
        if self:GetMaterial() == "infmap/flatgrass" then
            self:GenerateTrees(InfMap.planet_height_function, self.CHUNK_OFFSET, self:GetPlanetRadius())
        end
    end

    self:BuildCollision(InfMap.planet_height_function, self.CHUNK_OFFSET, self:GetPlanetRadius())
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
 local function smoothedNormal(heightFunction, vertexPos, size, cox, coy)
    local smoothedNormal = Vector()
    for cornery = 0, 1 do
        for cornerx = 0, 1 do
            // get 4 corners in a for loop ranging from -1 to 1
            local cornerx = (cornerx - 0.5) * 2
            local cornery = (cornery - 0.5) * 2

            // get the height of the 0x triangle
            local cornerWorldx = vertexPos[1]
            local cornerWorldy = vertexPos[2] + cornery * size
            local cornerHeight = heightFunction(cornerWorldx + cox, cornerWorldy + coy) * 2
            local middleXPosition = Vector(cornerWorldx, cornerWorldy, cornerHeight)

            // get the height of the 0y triangle
            local cornerWorldx = vertexPos[1] + cornerx * size
            local cornerWorldy = vertexPos[2]
            local cornerHeight = heightFunction(cornerWorldx + cox, cornerWorldy + coy) * 2
            local middleYPosition = Vector(cornerWorldx, cornerWorldy, cornerHeight)

            // we now have 3 points, construct a triangle from this and add the normal to the average normal
            local triNormal = (middleYPosition - vertexPos):Cross(middleXPosition - vertexPos) * cornerx * cornery
            smoothedNormal = smoothedNormal + triNormal
        end
    end

    return smoothedNormal
end

// ripped from terrain addon
function ENT:GenerateTrees(heightFunction, chunk, size)
    self.TreeMatrices = {}
    self.TreeModels = {}
    self.TreeColors = {}

    local randomIndex = 0
    local cox = chunk[1] * InfMap.chunk_size
    local coy = chunk[2] * InfMap.chunk_size
    local chunkIndex = tostring(cox) .. tostring(coy)
    local chunk_resolution = InfMap.planet_tree_resolution
    local tree_size = (self:GetPlanetRadius() / InfMap.chunk_size) * 2
    for y = 0, chunk_resolution - 1 do
        for x = 0, chunk_resolution - 1 do
            randomIndex = randomIndex + 1

            // generate seeded random position for tree
            local randseedx = util.SharedRandom("TerrainSeedX" .. chunkIndex, 0, 1, randomIndex)
            local randseedy = util.SharedRandom("TerrainSeedY" .. chunkIndex, 0, 1, randomIndex)
            local randPos = Vector(x + randseedx - chunk_resolution * 0.5, y + randseedy - chunk_resolution * 0.5) * (size / chunk_resolution) * 2
            local finalPos = Vector(randPos[1], randPos[2], heightFunction(randPos[1] + cox, randPos[2] + coy) - 45)

            // tree is not in planet, bail
            if finalPos:LengthSqr() > size * size - 2000 * 2000 then continue end

            local m = Matrix()
            m:SetTranslation(finalPos)
            m:SetAngles(Angle(0, randseedx * 3600, 0))//smoothedNormal:Angle() + Angle(90, 0, 0) Angle(0, randseedx * 3600, 0)
            m:SetScale(Vector(tree_size, tree_size, tree_size))
            table.insert(self.TreeMatrices, m)
            table.insert(self.TreeColors, Vector(1, 1, 1))
            //table.insert(self.TreeModels, 1)
        end
    end
end

local default_mat = Material("models/wireframe")
function ENT:GenerateMesh(heightFunction, chunk, size)
    local cox = chunk[1] * InfMap.chunk_size
    local coy = chunk[2] * InfMap.chunk_size
    // planet is a bit cursed since they are spherical, we need to cut off and round the edges of the chunk
	local triangles = {}
    local chunk_resolution = InfMap.planet_resolution
    for y = 0, chunk_resolution - 1 do
        for x = 0, chunk_resolution - 1 do
            local x1 = (x    ) / chunk_resolution
            local y1 = (y    ) / chunk_resolution
            local x2 = (x + 1) / chunk_resolution
            local y2 = (y + 1) / chunk_resolution
            local min_pos_x = -size + x1 * size * 2
            local min_pos_y = -size + y1 * size * 2
            local max_pos_x = -size + x2 * size * 2
            local max_pos_y = -size + y2 * size * 2

            // vertex positions in local space
            local vertexPos1 = Vector(min_pos_x, min_pos_y, heightFunction(min_pos_x + cox, min_pos_y + coy))
            local vertexPos2 = Vector(min_pos_x, max_pos_y, heightFunction(min_pos_x + cox, max_pos_y + coy))
            local vertexPos3 = Vector(max_pos_x, min_pos_y, heightFunction(max_pos_x + cox, min_pos_y + coy))
            local vertexPos4 = Vector(max_pos_x, max_pos_y, heightFunction(max_pos_x + cox, max_pos_y + coy))

            local in_a = vertexPos1:LengthSqr() < size * size
            local in_b = vertexPos2:LengthSqr() < size * size
            local in_c = vertexPos3:LengthSqr() < size * size
            local in_d = vertexPos4:LengthSqr() < size * size

            // all 4 points are outside of the sphere, cut this quad off.
            if !(in_a or in_b or in_c or in_d) then
                continue
            end

            // round positions to a circle if they are cut off
            if !in_a then
                vertexPos1 = vertexPos1:GetNormalized() * size
                vertexPos1[3] = heightFunction(vertexPos1[1] + cox, vertexPos1[2] + coy)
            end

            if !in_b then
                vertexPos2 = vertexPos2:GetNormalized() * size
                vertexPos2[3] = heightFunction(vertexPos2[1] + cox, vertexPos2[2] + coy)
            end

            if !in_c then
                vertexPos3 = vertexPos3:GetNormalized() * size
                vertexPos3[3] = heightFunction(vertexPos3[1] + cox, vertexPos3[2] + coy)
            end

            if !in_d then
                vertexPos4 = vertexPos4:GetNormalized() * size
                vertexPos4[3] = heightFunction(vertexPos4[1] + cox, vertexPos4[2] + coy)
            end

            local normal_size = size / chunk_resolution
            local normal1 = smoothedNormal(heightFunction, vertexPos1, normal_size, cox, coy)
            local normal2 = smoothedNormal(heightFunction, vertexPos2, normal_size, cox, coy)
            local normal3 = smoothedNormal(heightFunction, vertexPos3, normal_size, cox, coy)
            local normal4 = smoothedNormal(heightFunction, vertexPos4, normal_size, cox, coy)

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

    self.RENDER_MESH = {Mesh = Mesh(), Material = default_mat}
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
local tree_material = Material("infmap/arbre01")  //models/props_foliage/bush models/props_foliage/arbre01
local tree_mesh = Mesh()
tree_mesh:BuildFromTriangles(util.GetModelMeshes("models/infmap/tree_pine_large.mdl", 0)[1].triangles)
//tree_mesh:BuildFromTriangles(util.GetModelMeshes("models/props_foliage/rock_coast02b.mdl", 0)[1].triangles)

function ENT:Draw()
    local radius = self:GetPlanetRadius()
    if EyePos():DistToSqr(self:GetPos()) < radius * radius then
        self:DrawModel()
    end
end

// this MUST be optimized as much as possible, it is called multiple times every frame
function ENT:GetRenderMesh()
    local self = self
    if !self.RENDER_MESH then return end

    // No Trees?
    if !self.TreeMatrices then return self.RENDER_MESH end

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
    render_SetMaterial(tree_material)

    // render foliage
    local lastlight
    for i = 1, #matrices do
        //local matrix = matrices[i]
        //local modelID = models[i]
           
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
        cam_PushModelMatrix(matrices[i])
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