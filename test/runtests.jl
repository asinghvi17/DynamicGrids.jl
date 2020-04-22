using SafeTestsets

@time @safetestset "framework" begin include("framework.jl") end
@time @safetestset "outputs" begin include("outputs.jl") end
@time @safetestset "utils" begin include("utils.jl") end
@time @safetestset "simulationdata" begin include("simulationdata.jl") end
@time @safetestset "integration" begin include("integration.jl") end
@time @safetestset "image" begin include("image.jl") end
@time @safetestset "multi" begin include("multi.jl") end
@time @safetestset "chain" begin include("chain.jl") end
@time @safetestset "neighborhoods" begin include("neighborhoods.jl") end
@time @safetestset "mask" begin include("mask.jl") end
