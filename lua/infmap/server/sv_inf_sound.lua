// sound in source is is pretty shit
// choosing whether to start or stop a sound is not easy
// you may think "oh, just use the EmitSound hook"
// unfortunately the client's ".Entity" part of the table is mostly defined to the world
// this means we have to network server sounds to clients manually depending if the entity is in their chunk or not


hook.Add("EntityEmitSound", "infmap_sounddetour", function(data)
	//PrintTable(data)
end)