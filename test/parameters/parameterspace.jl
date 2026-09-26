using ReducedComplexityModeling
using Test
using Random: Xoshiro

grid = [0.0 1.0 0.0
        0.5 1.0 0.0
        1.0 1.0 0.0
        0.0 1.0 4.0
        0.5 1.0 4.0
        1.0 1.0 4.0]
h5file = "temp.h5"

@testset "ParameterSpace" begin
    μ = Parameter(:μ, 0.0, 1.0, 3)
    ν = Parameter(:ν, 1.0, 1.0, 1)
    σ = Parameter(:σ, 0.0, 4.0, 2)

    params = (μ, ν, σ)
    pkeys = (:μ, :ν, :σ)
    pgrid = [NamedTuple{pkeys}(Tuple(grid[i, :])) for i in axes(grid, 1)]

    p1 = ParameterSpace(NamedTuple(params...), sample(CartesianParameterSampler(), params...))
    p2 = ParameterSpace(NamedTuple(params...))
    p3 = ParameterSpace(params...)

    @test p1 == p2 == p3
    @test p1[:] == p2[:] == p3[:] == pgrid

    for i in axes(grid, 1)
        @test p1[i] == p2[i] == p3[i] == pgrid[i]
    end

    @test p1.samples.μ == p2.samples.μ == p3.samples.μ == grid[:, 1]
    @test p1.samples.ν == p2.samples.ν == p3.samples.ν == grid[:, 2]
    @test p1.samples.σ == p2.samples.σ == p3.samples.σ == grid[:, 3]

    h5save(h5file, p1; mode = "w")
    @test isfile(h5file)

    p2 = h5load(ParameterSpace, h5file)
    rm(h5file)
    @test p1 == p2
end

@testset "h5save and h5load keep the parameter order" begin
    ps = ParameterSpace(Parameter(:ν, 0.0, 1.0, 2), Parameter(:μ, 0.0, 2.0, 3))

    h5save(h5file, ps; mode = "w")
    @test h5load(ParameterSpace, h5file) == ps
    rm(h5file)
end

@testset "ParameterSpace with mixed element types" begin
    μ = Parameter(:μ, 0.0, 1.0, 3)
    σ = Parameter(:σ, 0.0f0, 4.0f0, 2)

    @testset "$(nameof(typeof(sampler)))" for sampler in (CartesianParameterSampler(),
        RandomParameterSampler(4, Xoshiro(1)), QuasiRandomParameterSampler(4))
        ps = ParameterSpace(sampler, μ, σ)
        @test ps.parameters == (μ = μ, σ = σ)
        @test eltype(ps.samples.μ) == Float64
        @test eltype(ps.samples.σ) == Float32
    end
end
