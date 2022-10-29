if E2Lib == nil then return end

E2Lib.RegisterExtension("InfMapCore", true)

__e2setcost(10)
e2function number getInfMapHeight(vector pos)
	return InfMap.height_function(pos[1] / (InfMap.chunk_size * 2), pos[2] / (InfMap.chunk_size * 2))
end