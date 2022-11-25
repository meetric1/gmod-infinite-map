// sound in source is is pretty shit

if SERVER then
	// serverside sounds need to be networked to individual clients
	util.AddNetworkString("INF_SOUND")
	local invalid_channels = {
		[CHAN_WEAPON] = true,
		[CHAN_BODY] = true,
		[CHAN_STATIC] = true,
	}
	// sounds that should be predicted on client, but arent
	local valid_sounds = {
		["Weapon_Crossbow.BoltElectrify"] = true,
	}
	hook.Add("EntityEmitSound", "infmap_sounddetour", function(data)
		local ent = data.Entity
		if !ent.CHUNK_OFFSET then return end	// no parent chunk, ignore
		data.Entity = ent:EntIndex()
		for _, ply in ipairs(player.GetAll()) do
			//PrintTable(data)
			//(ent != ply or !invalid_channels[data.Channel] or game.SinglePlayer())
			if (ent != ply or !invalid_channels[data.Channel] or game.SinglePlayer() or valid_sounds[data.OriginalSoundName]) and ply.CHUNK_OFFSET == ent.CHUNK_OFFSET then	// only network to clients that need to hear the sound
				net.Start("INF_SOUND") 
				net.WriteTable(data)	// probably the only valid place for writing a table in network
				net.Send(ply)
			end
		end
		return false
	end)
else
	// if not in our chunk, dont play sound
	hook.Add("EntityEmitSound", "!infmap_sounddetour", function(data)
		local co = data.Entity.CHUNK_OFFSET
		if co and co != LocalPlayer().CHUNK_OFFSET then	
			return false
		end
	end)
	
	// receive from server and play sound, then store in table
	local sound_ents = {}	// key = entity, key = soundname
	net.Receive("INF_SOUND", function()
		local data = net.ReadTable()
		//PrintTable(data)
		if !data.Pos then 
			data.Pos = Vector()
			//data.Channel = -1
		end
		EmitSound(data.OriginalSoundName, data.Pos, data.Entity, data.Channel, data.Volume, data.SoundLevel, data.Flags, data.Pitch, data.DSP)
		sound_ents[data.Entity] = sound_ents[data.Entity] or {}
		sound_ents[data.Entity][data.OriginalSoundName] = true
	end)

	// if the entity playing the sound leaves the chunk the client is in, stop it
	hook.Add("PropUpdateChunk", "infmap_soundstop", function(ent, _, chunk)
		local ent_idx = ent:EntIndex()
		if !sound_ents[ent_idx] or LocalPlayer().CHUNK_OFFSET == chunk then return end
		
		for snd, _ in pairs(sound_ents[ent_idx]) do
			ent:StopSound(snd)
		end

		table.Empty(sound_ents[ent_idx])
		sound_ents[ent_idx] = nil
	end)
end


// detour createsound so we can use our own filter
local sound_ents = {}	// key = entity
InfMap.CreateSound = InfMap.CreateSound or CreateSound
function CreateSound(ent, soundname, filter)
	if SERVER then
		if !filter then
			filter = RecipientFilter()
			filter:AddAllPlayers()
		end

		// remove players not in chunk
		for _, ply in ipairs(filter:GetPlayers()) do
			if ply.CHUNK_OFFSET != ent.CHUNK_OFFSET then
				filter:RemovePlayer(ply)
			end
		end
	end
	
	sound_ents[ent] = sound_ents[ent] or {}
	sound_ents[ent][soundname] = InfMap.CreateSound(ent, soundname, filter)
	return sound_ents[ent][soundname]
end

if SERVER then return end

hook.Add("PropUpdateChunk", "infmap_soundfilter", function(ent, chunk, oldchunk)
	if !sound_ents[ent] then return end
	timer.Simple(0, function()	// wait for contraption to teleport
		if ent.CHUNK_OFFSET == LocalPlayer().CHUNK_OFFSET then return end
		for sndname, snd in pairs(sound_ents[ent]) do	
			snd:Stop()	// not in our chunk, shut the fuck up
		end
	end)
end)