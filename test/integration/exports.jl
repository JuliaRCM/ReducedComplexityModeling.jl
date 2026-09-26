using ReducedComplexityModeling
using Test

@testset "Every exported name is defined" begin
    @test isempty(filter(
        n -> !isdefined(ReducedComplexityModeling, n), names(ReducedComplexityModeling)))
end
