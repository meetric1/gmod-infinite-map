AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "Other"
ENT.PrintName		= "Obj_r"
ENT.Author			= "Mee"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable		= false

if !InfMap or SERVER then return end

// the only purpose is to render a mesh
// source doesnt really like rendering raw meshes so we have to "parent" it to an entity
local default_material = CreateMaterial("infmap_objdefault", "VertexLitGeneric", {
	["$basetexture"] = "dev/graygrid", 
	["$model"] = 1, 
	["$nocull"] = 1,
	["$alpha"] = 1
})

function ENT:SetMesh(mesh, material)
    self.RENDER_MESH = {Mesh = mesh, Material = material or default_material}
    self:SetPos(Vector())
    self:SetAngles(Angle())
end

function ENT:GetRenderMesh()
    if !self.RENDER_MESH then return end
    return self.RENDER_MESH
end

function ENT:OnRemove()
    if self.RENDER_MESH and IsValid(self.RENDER_MESH.mesh) then
        self.RENDER_MESH.mesh:Destroy()
    end
end

/*
hook.Add("PostDrawOpaqueRenderables", "infmap_objdraw", function()
    for k, v in ipairs(ents.FindByClass("infmap_obj_render")) do
        v:Draw()
        v:SetRenderBoundsWS(-InfMap.source_bounds, InfMap.source_bounds) // FUCK render bounds bro
    end
end)*/