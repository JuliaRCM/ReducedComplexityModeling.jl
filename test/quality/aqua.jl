using ReducedComplexityModeling
using Aqua
using Test

@testset "Aqua" begin
    Aqua.test_all(ReducedComplexityModeling; ambiguities = (; broken = true))   # issue #38
end
