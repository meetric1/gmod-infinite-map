if game.GetMap() != "gm_infinite" then return end

AddCSLuaFile()

InfMap = InfMap or {}

hook.Add("ShouldCollide", "infinite_shouldcollide", function(ent1, ent2)
	if ent1.CHUNK_OFFSET != ent2.CHUNK_OFFSET then return false end
end)
