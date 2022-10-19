# GMod Infinite Map

### Overview
This is a garrys mod addon that adds a map to the game called gm_infinite, as the title suggests this map visually appears infinite
This is partially inspired by gm_infiniteflatgrass (from the Gravity Hull addon), but the map was very buggy and mostly impractical for use, especially when it comes to planes and ACF cars. Since the original creator of Gravity Hull is (presumably) dead, I am attempting to recreate it (Only the infinite map aspect).

### This mod attempts (or is planning) to recreate gm_infiniteflatgrass with more features including:
* Generally less buggy
* Generally better addon support
* Ability to see over 2 billion hammer units in real time
* ACF Support (May need help from ACF devs on this one)
* WAC Support (sorry, no LFS)
* Simphys car support
* Basic terrain including a ocean / lake system
* Ability to "Go to space"
* (Maybe) Procedural Planets^
* An attempt to revive the Spacebuild gamemode

### How It Works
The map isnt actually infinite, its impossible to go past the source bounds, so the entirety of the play space in the map is occupied in the same location. A hook is used to determine which props should and should not collide, and all entities are given perceived visual offsets per entity depending on which chunk (or cell) they are in, giving the illusion the map is presumably infinite (You cant do anything physical past the source boundery, but you can render things past it). The original Gravity Hull addon used this same method with "Cells" (But I call them chunks)

### For better addon support this mod currently detours the following functions (ONLY ON THE SERVER!):
* Entity:SetPos
* Entity:LocalToWorld
* Entity:WorldToLocal
* Entity:EyePos
* Entity:NearestPoint
* Entity:GetAttachment

* PhysObj:GetPos
* PhysObj:SetPos
* PhysObj:LocalToWorld
* PhysObj:WorldToLocal

* Vehicle:GetPos
* Vehicle:SetPos
* Vehicle:LocalToWorld
* Vehicle:WorldToLocal

* CTakeDamageInfo:GetDamagePosition

* NextBot:GetRangeSquaredTo
* NextBot:GetRangeTo

* CLuaLocomotionMT:Approach
* CLuaLocomotionMT:FaceTowards

* Player:ShootPos

* util.TraceLine
* util.TraceHull
* util.TraceEntity
* util.IsInWorld
* ents.FindInSphere
* WireLib:SetPos (unclamps wiremods setpos function since it wont let objects position be set outside of the source bounderies)
