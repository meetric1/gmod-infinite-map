AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "Other"
ENT.PrintName		= "Clone"
ENT.Author			= "Mee"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable		= false

if !InfMap then return end

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "ReferenceParent")
end

function ENT:SetReferenceData(ent, chunk)
    self:SetReferenceParent(ent)
    self.REFERENCE_DATA = {parent = ent, chunk = chunk, chunk_offset = ent.CHUNK_OFFSET + chunk}    //1 = ent, 2 = world chunk, 3 = local chunk
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

function ENT:InitializePhysics(convexes)
    local points = 0
    for i = 1, #convexes do points = points + #convexes[i] end
    if points < 1024 then // lags a lot when generating more than this
        self:PhysicsInitMultiConvex(unfuck_table(convexes))
    else
        self:PhysicsInit(SOLID_VPHYSICS)
    end

    self:EnableCustomCollisions(true)
    
    if self:GetPhysicsObject():IsValid() then
        self:GetPhysicsObject():EnableMotion(false)
    end
end

function ENT:InitializeClient(parent)
    if !IsValid(parent) then
        print("Failed to initialize clone", self)
        return
    end

    self:SetSolid(SOLID_VPHYSICS) 
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetModel(parent:GetModel())
    self:SetCollisionGroup(parent:GetCollisionGroup())

    local phys = parent:GetPhysicsObject()
    if !phys:IsValid() then // no custom physmesh, bail
        self:PhysicsInit(SOLID_VPHYSICS)
        return 
    end
    
    local convexes = phys:GetMeshConvexes()
    if !convexes then   // no convexes, bail
        self:PhysicsInit(SOLID_VPHYSICS)
        return
    end
    
    self:InitializePhysics(convexes)
end

function ENT:Initialize()
    local parent = self:GetReferenceParent()
    if CLIENT then
        self:InitializeClient(parent)
        return
    end
    
    self:SetModel(parent:GetModel())
    self:SetCollisionGroup(parent:GetCollisionGroup())
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)

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

    self:InitializePhysics(convexes)

    InfMap.prop_update_chunk(self, self.REFERENCE_DATA.chunk_offset)
end

function ENT:Think()
    if CLIENT then 
        self:SetNoDraw(true)
        local phys = self:GetPhysicsObject()
        if phys:IsValid() then
            phys:EnableMotion(false)
            phys:SetPos(self:GetPos())
            phys:SetAngles(self:GetAngles())
        else
            print("Regenerating Physics For Clone", self)
            self:Initialize()
        end
        return 
    end

    local data = self.REFERENCE_DATA
    if !data then 
        SafeRemoveEntity(self)
    end
    
    local parent = data.parent
    if !IsValid(parent) or data.chunk_offset != parent.CHUNK_OFFSET + data.chunk then
        SafeRemoveEntity(self)
        return
    end

    self:InfMap_SetPos(data.parent:InfMap_GetPos() - data.chunk * InfMap.chunk_size * 2)
    self:SetAngles(data.parent:GetAngles())
    
    local phys = self:GetPhysicsObject()
    if phys:IsValid() then phys:EnableMotion(false) end
end