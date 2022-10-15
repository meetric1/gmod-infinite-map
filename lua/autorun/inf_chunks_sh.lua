if game.GetMap() != "gm_infinite" then return end

AddCSLuaFile()

InfMap = InfMap or {}

hook.Add("ShouldCollide", "inf_chunk", function(ent1, ent2)
	return InfMap.should_collide(ent1, ent2)
end)
