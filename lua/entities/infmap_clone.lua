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

function ENT:SetReferenceData(ent, chunk)
    self.REFERENCE_DATA = {ent, chunk, (ent.CHUNK_OFFSET - chunk) * InfMap.chunk_size * 2}    //1 = ent, 2 = world chunk, 3 = local chunk
end

local function unfuck_table(verts)
    local actually_useful_data = {}
    for convex = 1, #verts do
        actually_useful_data[convex] = {}
        for vertex = 1, #verts[convex] do
            actually_useful_data[convex][vertex] = verts[convex][vertex].pos
        end
    end
    return actually_useful_data
end

function ENT:Initialize()
    if CLIENT then 
        self:SetSolid(SOLID_VPHYSICS) // init physics object on client
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:PhysicsInit(SOLID_VPHYSICS)
        return 
    end

    local parent = self.REFERENCE_DATA[1]
    local phys = parent:GetPhysicsObject()
    if !phys:IsValid() then     
        SafeRemoveEntity(self)
        return 
    end
    
    local convexes = phys:GetMeshConvexes()
    if !convexes then
        SafeRemoveEntity(self)
        return
    end

    print("Clone initialized w", parent)

    self:SetModel(parent:GetModel())
    local points = 0
    for i = 1, #convexes do points = points + #convexes[i] end
    if points < 1024 then // lags a lot when more than this
        self:PhysicsInitMultiConvex(unfuck_table(convexes))
    else
        self:PhysicsInit(SOLID_VPHYSICS)
    end
    self:SetSolid(SOLID_VPHYSICS) 
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:EnableCustomCollisions(true)
    self:PhysWake()
    self:SetCollisionGroup(parent:GetCollisionGroup())
    if self:GetPhysicsObject():IsValid() then
        self:GetPhysicsObject():EnableMotion(false)
    end

    InfMap.prop_update_chunk(self, self.REFERENCE_DATA[2])
end

function ENT:Think()
    if CLIENT then 
        self:SetNoDraw(true)
        local phys = self:GetPhysicsObject()
        if phys:IsValid() then
            phys:EnableMotion(false)
            phys:SetPos(self:GetPos())
            phys:SetAngles(self:GetAngles())
        end
        return 
    end

    local data = self.REFERENCE_DATA
    if !data then 
        SafeRemoveEntity(self)
    end
    local parent = data[1]
    if !parent or !parent:IsValid() then
        SafeRemoveEntity(self)
        return
    end

    self:InfMap_SetPos(data[1]:InfMap_GetPos() + data[3])
    self:SetAngles(data[1]:GetAngles())
    
    local phys = self:GetPhysicsObject()
    if phys:IsValid() then phys:EnableMotion(false) end
end

hook.Add("PhysgunPickup", "infinite_chunkclone_pickup", function(ply, ent)
    if ent:IsValid() and ent:GetClass() == "infmap_clone" then 
        return false 
    end
end)