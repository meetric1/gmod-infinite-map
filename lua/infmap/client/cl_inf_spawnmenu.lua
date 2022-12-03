//DOWN FURTHER THERE IS NO GOD
local def = InfMap.render_distance

CreateConVar( "infmap_renderdistance", def, FCVAR_NONE, "Infinite map render distance", 1, 8 )

hook.Add( "AddToolMenuCategories", "InfMapSpawnmenu", function()
	spawnmenu.AddToolCategory( "Options", "Infinite map", "#InfMap" )
end)

hook.Add( "PopulateToolMenu", "InfMapSpawnmenuSettings", function()
	spawnmenu.AddToolMenuOption( "Options", "Infinite map", "Settings", "#Settings", "", "", function( panel )
		panel:ClearControls()
		local slider = panel:NumSlider( "Render Distance", "infmap_renderdistance", 1, 8, 0 )

		slider:SetDefaultValue( def )
		slider:SetValue( def )
	end)
end)

cvars.AddChangeCallback( "infmap_renderdistance", function( a, b, new )
	InfMap.render_distance = tonumber( new, 10 )
	//InfMap.prop_update_chunk( LocalPlayer(), LocalPlayer().CHUNK_OFFSET ) //i have no idea how to do this
end)
