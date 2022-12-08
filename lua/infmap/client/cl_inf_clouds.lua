local mat = Material( "infmap/clouds" )
local size = 50000000 //terrain blinks after size being more than 50000000

hook.Add( "PostDrawTranslucentRenderables", "DrawClouds", function()
    render.SetMaterial( mat )
    
    local vec = Vector(LocalPlayer().CHUNK_OFFSET)
    vec[3] = -vec[3]
    
    render.DrawQuadEasy( InfMap.unlocalize_vector(Vector(0,0,500000), vec), Vector(0,0,-1), size, size, Color(255,255,255) )
end)