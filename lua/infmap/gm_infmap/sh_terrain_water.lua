local gravity_convar = GetConVar("sv_gravity")

InfMap.water_height = -5000
InfMap.water_material = "infmap/water_warp"

local function inWater(pos)
    return pos[3] < InfMap.water_height
end

// water screenspace overlay
local changedWater = false
hook.Add("RenderScreenspaceEffects", "infmap_water_pp", function()
	if inWater(InfMap.unlocalize_vector(EyePos(), LocalPlayer().CHUNK_OFFSET)) then
        DrawMaterialOverlay(InfMap.water_material, 0.1)
        DrawMaterialOverlay("effects/water_warp01", 0.1)
        
        if !changedWater then
            changedWater = true
            LocalPlayer():EmitSound("Physics.WaterSplash")
            LocalPlayer():SetDSP(14, true)
        end
    elseif changedWater then
        changedWater = false
        LocalPlayer():EmitSound("Physics.WaterSplash")
        LocalPlayer():SetDSP(0, true)
    end
end)

// swim code yoinked from gwater, thanks again kodya
// player animations
hook.Add("CalcMainActivity", "infmap_water_swimming", function(ply)
	if !inWater(ply:GetPos()) or ply:IsOnGround() or ply:InVehicle() then return end
	return ACT_MP_SWIM, -1
end)

// main movement
hook.Add("Move", "infmap_water_swimming", function(ply, move)
    if !inWater(ply:GetPos()) then return end

	local vel = move:GetVelocity()
	local ang = move:GetMoveAngles()

	local acel =
	(ang:Forward() * move:GetForwardSpeed()) +
	(ang:Right() * move:GetSideSpeed()) +
	(ang:Up() * move:GetUpSpeed())

	local aceldir = acel:GetNormalized()
	local acelspeed = math.min(acel:Length(), ply:GetMaxSpeed())
	acel = aceldir * acelspeed * 2

	if bit.band(move:GetButtons(), IN_JUMP) ~= 0 then
	    acel.z = acel.z + ply:GetMaxSpeed()
	end

	vel = vel + acel * FrameTime()
	vel = vel * (1 - FrameTime() * 2)

	local pgrav = ply:GetGravity() == 0 and 1 or ply:GetGravity()
	local gravity = pgrav * gravity_convar:GetFloat() * 0.5
	vel.z = vel.z + FrameTime() * gravity

	move:SetVelocity(vel * 0.99)
end)

// secondary, final movement
hook.Add("FinishMove", "infmap_water_swimming", function(ply, move)
	if !inWater(ply:GetPos()) then return end
	local vel = move:GetVelocity()
	local pgrav = ply:GetGravity() == 0 and 1 or ply:GetGravity()
	local gravity = pgrav * gravity_convar:GetFloat() * 0.5

	vel.z = vel.z + FrameTime() * gravity
	move:SetVelocity(vel)
end)

// serverside stuff now
if CLIENT then
    local waterMatrix = Matrix()
    waterMatrix:SetScale(Vector(500000, 500000, 1))

    local uvscale = 5000
    local waterMesh = Mesh()
    waterMesh:BuildFromTriangles({
        {pos = Vector(-1, -1, 0), u = 0, v = uvscale},
        {pos = Vector(1, 1, 0), u = uvscale, v = 0},
        {pos = Vector(1, -1, 0), u = uvscale, v = uvscale},

        {pos = Vector(-1, -1, 0), u = 0, v = uvscale},
        {pos = Vector(-1, 1, 0), u = 0, v = 0},
        {pos = Vector(1, 1, 0), u = uvscale, v = 0},

        {pos = Vector(-1, -1, 0), u = 0, v = uvscale},
        {pos = Vector(1, -1, 0), u = uvscale, v = uvscale},
        {pos = Vector(1, 1, 0), u = uvscale, v = 0},

        {pos = Vector(-1, -1, 0), u = 0, v = uvscale},
        {pos = Vector(1, 1, 0), u = uvscale, v = 0},
        {pos = Vector(-1, 1, 0), u = 0, v = 0},
    })

    local water = Material(InfMap.water_material)
    hook.Add("PreDrawTranslucentRenderables", "infmap_water_draw", function(_, sky)
        if sky then return end
        local co = Vector(LocalPlayer().CHUNK_OFFSET)
        co[1] = 0
        co[2] = 0
        if co[3] > InfMap.render_max_height then return end
        waterMatrix:SetTranslation(InfMap.unlocalize_vector(Vector(0, 0, InfMap.water_height), -co))
        render.SetMaterial(water)
        cam.PushModelMatrix(waterMatrix)
            waterMesh:Draw()
        cam.PopModelMatrix()
    end)
    return 
end

hook.Add("PlayerFootstep", "infmap_water_footsteps", function(ply, pos, foot, sound, volume, rf)
    if inWater(ply:GetPos()) then 
        ply:EmitSound(foot == 0 and "Water.StepLeft" or "Water.StepRight", nil, nil, volume, CHAN_BODY)     // volume doesnt work for some reason.. oh well
        return true
    end
end )

// no fall damage in fake water
hook.Add("GetFallDamage", "infmap_water_falldmg", function(ply, speed)
    // for some reason player position isnt fully accurate when this is called
    local tr = util.TraceHull({
        start = ply:GetPos(),
        endpos = ply:GetPos() + ply:GetVelocity(),
        maxs = ply:OBBMaxs(),
        mins = ply:OBBMins(),
        filter = ply
    })
    if tr.Hit and inWater(tr.HitPos) then return 0 end
end)


if SERVER then
    local IsValid = IsValid
    local positions = {}
    local valid_materials = {
        ["floating_metal_barrel"] = true,
        ["wood"] = true,
        ["wood_crate"] = true,
        ["wood_furniture"] = true,
        ["rubbertire"] = true,
        ["wood_solid"] = true,
        ["plastic"] = true,
        ["watermelon"] = true,
        ["default"] = true,
        ["cardboard"] = true,
        ["paper"] = true,
        ["popcan"] = true,
    }
    hook.Add("Think", "infmap_water_buoyancy", function()
        local waterHeight = InfMap.water_height
        local entities = ents.FindByClass("prop_*")
        for _, prop in ipairs(entities) do
            local phys = prop:GetPhysicsObject()
            if !phys:IsValid() or phys:IsAsleep() then continue end

            local is_airboat = prop:GetClass() == "prop_vehicle_airboat"
            if valid_materials[phys:GetMaterial()] or is_airboat then 
                local mins = prop:OBBMins()
                local maxs = prop:OBBMaxs()

                // do not calculate object, we know it is too far and not near the water
                local p = prop:GetPos()[3] - 1
                if p - math.abs(mins[3]) > waterHeight and p - math.abs(maxs[3]) > waterHeight then
                    continue
                end

                // why is the airboat size fucked?
                if is_airboat then 
                    mins = mins * 0.5
                    maxs = maxs * 0.5
                    mins[3] = 0
                    maxs[3] = 0
                end

                // so many points
                positions[1] = Vector(mins[1], mins[2], mins[3])
                positions[2] = Vector(mins[1], mins[2], maxs[3])
                positions[3] = Vector(mins[1], maxs[2], mins[3])
                positions[4] = Vector(maxs[1], mins[2], mins[3])
                positions[5] = Vector(mins[1], maxs[2], maxs[3])
                positions[6] = Vector(maxs[1], maxs[2], mins[3])
                positions[7] = Vector(maxs[1], mins[2], maxs[3])
                positions[8] = Vector(maxs[1], maxs[2], maxs[3])

                local prop_inwater = false
                local should_sleep = (phys:GetVelocity() + phys:GetAngleVelocity()):Length() < 1 and !prop:IsPlayerHolding()
                for _, pos in ipairs(positions) do
                    local world_pos = prop:LocalToWorld(pos)
                    if inWater(world_pos) then
                        if is_airboat then
                            phys:ApplyForceOffset(Vector(0, 0, phys:GetMass() * math.min(((waterHeight - world_pos[3]) * 0.75), 2)), world_pos)
                            phys:ApplyForceCenter(phys:GetMass() * phys:GetVelocity() * -0.001)   //dampen very small bit for airboats
                        else
                            phys:ApplyForceOffset(Vector(0, 0, phys:GetMass() * (math.min(((waterHeight - world_pos[3]) * 0.1), 3))), world_pos)
                            phys:ApplyForceCenter(phys:GetMass() * phys:GetVelocity() * -0.003)   //dampen a bit
                        end
                        phys:AddAngleVelocity(phys:GetAngleVelocity() * -0.01)
                        prop_inwater = true
                        //debugoverlay.Sphere(world_pos, 10, 0.1)
                    end
                end

                if prop_inwater and should_sleep then
                    phys:Sleep()
                end
            end
        end
    end)
end