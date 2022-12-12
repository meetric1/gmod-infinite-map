// sound in source is what it is. This is an attempt to improve it.
// emitting from ent position does not work across chunks, so we must use client ents instead when needed.
// the logic is as follows:
// sounds are sorted into two types, looping and non-looping.
// non-looping sounds are played instantly if the player is in range - if not, discard.
// looping sounds are sorted into two types, valid and non-valid (scraping physics sounds)
// if valid, then looping sounds are stored by the server and distributed when needed.
// CSoundPatches are bound directly to client props as their behaviour is already controlled by their respective entities.
 
local function IsValidLoop( data )
	if data.Entity:GetBoneSurfaceProp( 0 ) == 0 then return false end
	local a = sound.GetProperties(util.GetSurfaceData(util.GetSurfaceIndex(data.Entity:GetBoneSurfaceProp( 0 ))).scrapeRoughSound).sound
	local b = sound.GetProperties(util.GetSurfaceData(util.GetSurfaceIndex(data.Entity:GetBoneSurfaceProp( 0 ))).scrapeSmoothSound).sound
	return a ~= data.OriginalSoundName and b ~= data.OriginalSoundName //is valid loop sound?
end

local function IsLoop( data )
	local a,b = string.find(string.lower(data.OriginalSoundName),"loop")
	if data.Flags == nil then return false end
	return (a and b) or data.Flags % 2 ~= 0 //is loop sound?
end

local sqrdist = InfMap.chunk_size * InfMap.chunk_size

local function CheckDistance( ent1, ent2, num )
	return ent1:GetPos():DistToSqr(ent2:GetPos()) < sqrdist*num //get distance, disttosqr faster
end	

if SERVER then

	util.AddNetworkString( "inf_ent_networksound" )
	util.AddNetworkString( "inf_ent_stopsound" )

	local EntityMT = FindMetaTable("Entity")
	local SoundMT = FindMetaTable("CSoundPatch")
	local inf_sounds_store = {}
	local csoundpatch_store = {}

	//sends sounds to players, or stores the sound for sending later
	local function SendToPlayers( data )
		for _, ply in ipairs(player.GetAll()) do
			if CheckDistance( ply, data.Entity, 1 ) then //if client can hear then send immediately
				if data.End then net.Start("inf_ent_stopsound") else net.Start("inf_ent_networksound") end
				net.WriteTable(data)
				net.Send(ply) //send sound to player
			else
				if IsLoop(data) and IsValidLoop(data) then //check if is looping sound 
					inf_sounds_store[ply] = inf_sounds_store[ply] or {}
					inf_sounds_store[ply][data.Entity] = inf_sounds_store[ply][data.Entity] or {}
					inf_sounds_store[ply][data.Entity][data.OriginalSoundName] = data //if not in range, store for later
				end
			end
		end
	end

	//sound hook, plus world > entity conversion
	hook.Add( "EntityEmitSound", "infmap_sounddetour", function(data)
		if data.Entity:IsWorld() then //emitting sounds from world is stupid, lets change to entity
			local dist = 16384 //big number
			local ent, vec
			for k, v in pairs(ents.GetAll()) do
				vec = v:InfMap_GetPos() //get true pos / chunk (better method, thanks mee)
				if vec:DistToSqr(data.Pos) < dist and !InfMap.filter_entities(v) then //get closest entity to emitted sound, filtered!
					dist = vec:DistToSqr(data.Pos) //faster than distance
					ent = v
				end
			end
			if IsValid(ent) then //is valid ent?
				data.Entity = ent
			end
		end 

		SendToPlayers(data)//send only to players who can hear it
		return false
	end)

	//server sound delivery, check if player is close enough to send sound to them
	hook.Add("Think", "infmap_soundstore", function() //server stores all sounds, then distributes when needed
		for a, b in pairs( inf_sounds_store ) do
			for c, d in pairs( b ) do
				for e, f in pairs( d ) do
					if !IsValid(c) then table.RemoveByValue(b,d) continue end
					if CheckDistance( a, c, 1 ) then
						if f.End then net.Start("inf_ent_stopsound") else net.Start("inf_ent_networksound") end //looping sound support
						net.WriteTable(f)
						net.Send(a)
						table.RemoveByValue(b,d) //only send sound once!
					end
				end
			end
		end
	end)

	//stop sound detour
	EntityMT.InfMap_StopSound = EntityMT.InfMap_StopSound or EntityMT.StopSound //for wire thrusters and other ents
	function EntityMT:StopSound(snd)
		local data = {}
		data.OriginalSoundName = snd
		data.Entity = self
		data.End = true //marked as stopped
		SendToPlayers( data )
	end

	//serverside csound detour
	InfMap.CreateSound = InfMap.CreateSound or CreateSound
	function CreateSound(ent, soundname, filter)
		local csound = InfMap.CreateSound(ent, soundname, filter)
		csound:ChangeVolume(0,0) //required, otherwise sounds will play everywhere. Cannot use SetSoundLevel as that mutes thrusters.
		csoundpatch_store[ent] = csoundpatch_store[ent] or {} //store for later so it can be stopped
		csoundpatch_store[ent].Entity = csound
		csoundpatch_store[ent].Sound = soundname //csound + soundname are needed for stopsound networking
		return csound
	end

	//csoundpatch stop detour
	SoundMT.InfMap_Stop = SoundMT.InfMap_Stop or SoundMT.Stop //for all other csoundpatch based ents (sound emitters, E2s etc.)
	function SoundMT:Stop()
		for k,v in pairs(csoundpatch_store) do
			if self == v.Entity then
				local data = {}
				data.OriginalSoundName = v.Sound
				data.Entity = k
				data.End = true
				SendToPlayers( data )
			end
		end
		self:InfMap_Stop()
	end

else

	local inf_sounds = {}
	local inf_csounds = {}

	//client ent for seamless chunk sounds
	function SoundObject( ent )
		local s_Model =  ents.CreateClientProp() //no model to disable phys
		s_Model:InfMap_SetPos( ent:GetPos() ) //set client ent to true pos
		s_Model:Spawn()
		return s_Model
	end

	//receive sounds from server, either plays on client ent or ent itself (for awkward looping sounds)
	net.Receive( "inf_ent_networksound", function()
		local data = net.ReadTable()
		if IsValid(data.Entity) then
			if IsLoop(data) and !IsValidLoop(data) then //check if sound is awkward looping sound
				inf_sounds[data.Entity] = data //attach sound to looping monitor
				data.Entity:EmitSound(data.OriginalSoundName,data.SoundLevel,data.Pitch,data.Volume,data.Channel,data.Flags,data.DSP) //play sound directly on entity
			else
				if data.Entity ~= LocalPlayer() or !LocalPlayer():Alive() then //exception for players, sounds seem to duplicate for them
					if !IsValid(inf_csounds[data.Entity]) then
						inf_csounds[data.Entity] = SoundObject(data.Entity) //create clientside prop
						inf_csounds[data.Entity].Position = data.Entity:GetPos() //store client prop position
					end
					inf_csounds[data.Entity]:EmitSound(data.OriginalSoundName,data.SoundLevel,data.Pitch,data.Volume,data.Channel,data.Flags,data.DSP) //play sound on client prop
					data.Entity:CallOnRemove("stopsound_"..data.OriginalSoundName,function(ent) pcall(function() inf_csounds[ent]:StopSound( data.OriginalSoundName ) inf_csounds[ent]:Remove() end) end) //Remove client prop on entity deletion
				end
			end
		end
	end)

	//stop sound
	net.Receive( "inf_ent_stopsound", function()
		local data = net.ReadTable()
		if IsValid(data.Entity) then data.Entity:StopSound(data.OriginalSoundName) end //stop sound on ent
		if IsValid(inf_csounds[data.Entity]) then inf_csounds[data.Entity]:StopSound(data.OriginalSoundName) end //stop sound on client ent
	end)

	//sound manager to stop/start sounds depending on distance
	hook.Add( "Think", "infmap_soundmanager", function()
		for k, v in pairs(inf_sounds) do
			if !IsValid(k) then table.RemoveByValue(inf_sounds,k) continue end
			if !CheckDistance(LocalPlayer(), v.Entity, 1) then
				v.Entity:StopSound(v.OriginalSoundName) //stop sound if too far away
			end
		end
		for k, v in pairs(inf_csounds) do
			if !IsValid(k) then table.RemoveByValue(inf_csounds,k) continue end
			if (CheckDistance(LocalPlayer(), v, 4) or CheckDistance(LocalPlayer(), k, 4)) and v.Position ~= k:GetPos() then //if within chunk_size and moving, update pos
				local pos = k:GetPos()
				pos[1] = math.Clamp(pos[1],-100000,100000) //clamp client prop pos to avoid out of bounds errors
				pos[2] = math.Clamp(pos[2],-100000,100000)
				pos[3] = math.Clamp(pos[3],-100000,100000)
				v:InfMap_SetPos( pos )
				v.Position = pos
			end
		end
	end)

	//csound clientside detour, sets csound to client prop for seamless chunk sounds
	InfMap.CreateSound = InfMap.CreateSound or CreateSound
	function CreateSound(ent, soundname, filter)
		if !IsValid(inf_csounds[ent]) then inf_csounds[ent] = SoundObject(ent) end
		local csound = InfMap.CreateSound(inf_csounds[ent], soundname, filter) //create csound on client ent
		ent:CallOnRemove("stopsound_"..soundname,function(cent) pcall(function() csound:Stop() inf_csounds[cent]:Remove() end) end) //Remove client prop on entity deletion
		return csound
	end

end
