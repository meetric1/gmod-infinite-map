if game.GetMap() != "gm_infinite" then return end

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= ""
ENT.PrintName		= ""
ENT.Author			= "Mee"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable		= false

function ENT:BuildCollision(heightFunction)
    local chunk_offset = self.CHUNK_OFFSET or Vector()
    local x = chunk_offset[1]
    local y = chunk_offset[2]

    local p1 = Vector(InfMap.chunk_size, InfMap.chunk_size, heightFunction(x + 0.5, y + 0.5))
    local p2 = Vector(-InfMap.chunk_size, InfMap.chunk_size, heightFunction(x - 0.5, y + 0.5))
    local p3 = Vector(InfMap.chunk_size, -InfMap.chunk_size, heightFunction(x + 0.5, y - 0.5))
    local p4 = Vector(-InfMap.chunk_size, -InfMap.chunk_size, heightFunction(x - 0.5, y - 0.5))

    local finalMesh = {
        {pos = p1},
        {pos = p2},
        {pos = p3},
        {pos = p2},
        {pos = p3},
        {pos = p4}
    }

    self:PhysicsDestroy()
	self:PhysicsFromMesh(finalMesh)

    if CLIENT then
        self:SetRenderBounds(self:OBBMins(), self:OBBMaxs())
    end
end

/****************** CLIENT *********************/

local default_mat = Material("phoenix_storms/ps_grass")
function ENT:GenerateMesh(heightFunction)
    self.RENDER_MESH = {Mesh = Mesh(), Material = default_mat}
    local mesh = mesh   // local lookup is faster than global
    local err, msg
    mesh.Begin(self.RENDER_MESH.Mesh, MATERIAL_TRIANGLES, 2)  // 2 triangles per chunk (yeah, really.)
        err, msg = pcall(function()
            // chunk offset in world space
            local chunk_offset = self.CHUNK_OFFSET or Vector()
            local chunkoffsetx = chunk_offset[1]
            local chunkoffsety = chunk_offset[2]

            // the height of the vertex using the math function
            local vertexHeight1 = heightFunction(chunkoffsetx - 0.5, chunkoffsety - 0.5)
            local vertexHeight2 = heightFunction(chunkoffsetx - 0.5, chunkoffsety + 0.5)
            local vertexHeight3 = heightFunction(chunkoffsetx + 0.5, chunkoffsety - 0.5)
            local vertexHeight4 = heightFunction(chunkoffsetx + 0.5, chunkoffsety + 0.5)

            // vertex positions in local space
            local vertexPos1 = Vector(-InfMap.chunk_size, -InfMap.chunk_size, vertexHeight1)
            local vertexPos2 = Vector(-InfMap.chunk_size, InfMap.chunk_size, vertexHeight2)
            local vertexPos3 = Vector(InfMap.chunk_size, -InfMap.chunk_size, vertexHeight3)
            local vertexPos4 = Vector(InfMap.chunk_size, InfMap.chunk_size, vertexHeight4)

            local normal1 = -(vertexPos1 - vertexPos2):Cross(vertexPos1 - vertexPos3)//:GetNormalized()
            local normal2 = -(vertexPos4 - vertexPos3):Cross(vertexPos4 - vertexPos2)//:GetNormalized()

            local uvscale = 500

            // first tri
            mesh.Position(vertexPos1)
            mesh.TexCoord(0, 0, 0)        // texture UV
            mesh.Normal(normal1)
            mesh.AdvanceVertex()

            mesh.Position(vertexPos2)
            mesh.TexCoord(0, uvscale, 0)
            mesh.Normal(normal1)
            mesh.AdvanceVertex()

            mesh.Position(vertexPos3)
            mesh.TexCoord(0, 0, uvscale)
            mesh.Normal(normal1)
            mesh.AdvanceVertex()

            // second tri
            mesh.Position(vertexPos3)
            mesh.TexCoord(0, 0, uvscale)
            mesh.Normal(normal2)
            mesh.AdvanceVertex()

            mesh.Position(vertexPos2)
            mesh.TexCoord(0, uvscale, 0)
            mesh.Normal(normal2)
            mesh.AdvanceVertex()

            mesh.Position(vertexPos4)
            mesh.TexCoord(0, uvscale, uvscale)
            mesh.Normal(normal2)
            mesh.AdvanceVertex()
        end)
    mesh.End()

    if !err then print(msg) end  // if there is an error, catch it and throw it outside of mesh.begin since you crash if mesh.end is not called
end

function ENT:ClientInitialize()
    self:BuildCollision(InfMap.height_function)
    if self:GetPhysicsObject():IsValid() then
        self:GetPhysicsObject():EnableMotion(false)
        self:GetPhysicsObject():SetMass(50000)  // make sure to call these on client or else when you touch it, you will crash
        self:GetPhysicsObject():SetPos(self:GetPos())
    end

    self:GenerateMesh(InfMap.height_function)
end

function ENT:GetRenderMesh()
    if !self.RENDER_MESH then return end
    return self.RENDER_MESH
end

if CLIENT then
    hook.Add("PropUpdateChunk", "infmap_terrain_init", function(ent, chunk)
        if ent:GetClass() == "infmap_terrain" then
            ent:ClientInitialize()
        end
    end)
end

/****************** SERVER *********************/

function ENT:Initialize()
    if CLIENT then return end

    self:SetModel("models/props_c17/FurnitureCouch002a.mdl")
    self:BuildCollision(InfMap.height_function)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:EnableCustomCollisions(true)
    self:GetPhysicsObject():EnableMotion(false)
    self:GetPhysicsObject():SetMass(50000)  // max weight, should help a bit with the physics solver
    self:DrawShadow(false)
end

hook.Add("PhysgunPickup", "infinite_chunkterrain_pickup", function(ply, ent)
    if (ent:IsValid() and ent:GetClass() == "infmap_terrain") then 
        return false 
    end
end)

if CLIENT then return end

local function resetAll()
    local e = ents.Create("prop_physics")
    e:SetPos(Vector(0, 0, -10))
    e:SetModel("models/hunter/blocks/cube8x8x025.mdl")
    e:SetMaterial("models/gibs/metalgibs/metal_gibs")
    e:Spawn()
    e:GetPhysicsObject():EnableMotion(false)
    constraint.Weld(e, game.GetWorld(), 0, 0, 0)

    for y = -0, 0 do
        for x = -0, 0 do 
            local e = ents.Create("infmap_terrain")
            e:SetPos(Vector(x * InfMap.chunk_size * 2, y * InfMap.chunk_size * 2, 0))
            e:Spawn()
        end
    end
end


hook.Add("InitPostEntity", "infinite_terrain_init", function() timer.Simple(0, resetAll) end)
hook.Add("PostCleanupMap", "infmap_cleanup", resetAll)