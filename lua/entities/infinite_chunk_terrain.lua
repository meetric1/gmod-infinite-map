if game.GetMap() != "gm_infinite" then return end

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "Other"
ENT.PrintName		= "Clone"
ENT.Author			= "Mee"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable		= false


local size = Vector(InfMap.chunk_size * 1.1, InfMap.chunk_size * 1.1, 10)
local convex = {
    Vector(-size[1], -size[2], -size[3]), -- The first box vertices
    Vector(-size[1], -size[2], size[3]),
    Vector(-size[1], size[2], -size[3]),
    Vector(-size[1], size[2], size[3]),
    Vector(size[1], -size[2], -size[3]),
    Vector(size[1], -size[2], size[3]),
    Vector(size[1], size[2], -size[3]),
    Vector(size[1], size[2], size[3]),
}
function ENT:Initialize()
    if CLIENT then
        self:SetRenderBounds(-size * 50, size * 50)
    end
    self:PhysicsInitConvex(convex)
    self:SetSolid(SOLID_VPHYSICS) 
    self:SetMoveType(MOVETYPE_NONE)
    self:EnableCustomCollisions(true)
    self:PhysWake()
    if self:GetPhysicsObject():IsValid() then
        self:GetPhysicsObject():EnableMotion(false)
    end
end

if CLIENT then
    local size = InfMap.chunk_size * 51
    local data = {
        {pos = Vector(size, size, 10), normal = Vector(0, 0, 1), u = 10000, v = 0, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
        {pos = Vector(size, -size, 10), normal = Vector(0, 0, 1), u = 10000, v = 10000, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
        {pos = Vector(-size, -size, 10), normal = Vector(0, 0, 1), u = 0, v = 10000, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
        {pos = Vector(size, size, 10), normal = Vector(0, 0, 1), u = 10000, v = 0, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
        {pos = Vector(-size, -size, 10), normal = Vector(0, 0, 1), u = 0, v = 10000, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
        {pos = Vector(-size, size, 10), normal = Vector(0, 0, 1), u = 0, v = 0, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},

        {pos = Vector(-size, -size, -10), normal = Vector(0, 0, -1), u = 10000, v = 0, tangent = Vector(-1, 0, 0), userdata = {1, 0, 0, -1}},
        {pos = Vector(size, -size, -10), normal = Vector(0, 0, -1), u = 10000, v = 10000, tangent = Vector(-1, 0, 0), userdata = {1, 0, 0, -1}},
        {pos = Vector(size, size, -10), normal = Vector(0, 0, -1), u = 0, v = 10000, tangent = Vector(-1, 0, 0), userdata = {1, 0, 0, -1}},
        {pos = Vector(-size, -size, -10), normal = Vector(0, 0, -1), u = 10000, v = 0, tangent = Vector(-1, 0, 0), userdata = {1, 0, 0, -1}},
        {pos = Vector(size, size, -10), normal = Vector(0, 0, -1), u = 0, v = 10000, tangent = Vector(-1, 0, 0), userdata = {1, 0, 0, -1}},
        {pos = Vector(-size, size, -10), normal = Vector(0, 0, -1), u = 0, v = 0, tangent = Vector(-1, 0, 0), userdata = {1, 0, 0, -1}},
    }
    local m = Mesh()
    m:BuildFromTriangles(data)

    local render_mesh = {Mesh = m, Material = Material("phoenix_storms/ps_grass")}
    function ENT:GetRenderMesh()
        return render_mesh
    end

    function ENT:Think() 
        if !self:GetPhysicsObject():IsValid() then
            self:Initialize()
        end
        self:SetNextClientThink(CurTime() + 1)
        return true
    end
else
    hook.Add("InitPostEntity", "infinite_terrain_init", function()
        local e = ents.Create("infinite_chunk_terrain")
        e:InfMap_SetPos(Vector(0, 0, -15))
        e:Spawn()
        hook.Run("PropUpdateChunk", e, Vector(0, 0, 0))
        physenv.SetPerformanceSettings({MaxVelocity = 2^31})
    end)
    
end

function ENT:CanProperty()
	return false
end

function ENT:CanTool()
    return true
end

hook.Add("PhysgunPickup", "infinite_chunkterrain_pickup", function(ply, ent)
    if ent:IsValid() and ent:GetClass() == "infinite_chunk_terrain" then 
        return false 
    end
end)