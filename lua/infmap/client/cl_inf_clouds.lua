local mat = Material( "infmap/clouds" )
local size = 50000000 //terrain blinks after size being more than 50000000

hook.Add( "PostDrawTranslucentRenderables", "DrawClouds", function()
    render.SetMaterial( mat )
    
    local vec = Vector(LocalPlayer().CHUNK_OFFSET[1],LocalPlayer().CHUNK_OFFSET[2],-LocalPlayer().CHUNK_OFFSET[3]) //immovable object, unstoppable force

    render.DrawQuadEasy( InfMap.unlocalize_vector(Vector(0,0,500000), vec), Vector(0,0,-1), size, size, Color(255,255,255) )
    render.DrawQuadEasy( InfMap.unlocalize_vector(Vector(0,0,500000), vec), Vector(0,0,1), size, size, Color(255,255,255) ) //because it's a plane
end)