using ReducedComplexityModeling
using Test

samples = [0.0, 1.0, 2.0, 3.0, 4.0]
h5file = "temp.h5"

@testset "Parameter" begin
    @test_throws AssertionError Parameter(:μ, 1.0, 4.0, samples)
    @test_throws AssertionError Parameter(:μ, 0.0, 3.0, samples)
    @test_throws AssertionError Parameter(:μ, 1.0, 0.0, 5)
    @test_throws AssertionError Parameter(:μ, 1.0, 0.0)

    p1 = Parameter(:μ, 0.0, 4.0, samples)
    p2 = Parameter(:μ, 0.0, 4.0, samples)
    p3 = Parameter(:μ, 0.0, 4.0, 5)
    p4 = Parameter(:μ, 0.0, 4.0)
    p5 = Parameter(:μ, 0.0, 4.0, nothing)

    @test p1 == p2
    @test p1 == p3
    @test p1 != p4
    @test p4 == p5

    @test hash(p1) == hash(p2)
    @test hash(p1) == hash(p3)
    @test hash(p1) != hash(p4)
    @test hash(p4) == hash(p5)

    @test length(p1) == length(samples)
    @test length(p2) == length(samples)
    @test length(p3) == length(samples)
    @test length(p4) == 0
    @test length(p5) == 0

    @test size(p1) == size(samples)
    @test size(p2) == size(samples)
    @test size(p3) == size(samples)
    @test size(p4) == (0,)
    @test size(p5) == (0,)

    @test hassamples(p1)
    @test hassamples(p2)
    @test hassamples(p3)
    @test !hassamples(p4)
    @test !hassamples(p5)

    @test collect(p1) == samples
    @test collect(p2) == samples
    @test collect(p3) == samples
    @test collect(p4) === nothing
    @test collect(p5) === nothing

    @test minimum(p1) == 0.0
    @test minimum(p2) == 0.0
    @test minimum(p3) == 0.0
    @test minimum(p4) == 0.0
    @test minimum(p5) == 0.0

    @test maximum(p1) == 4.0
    @test maximum(p2) == 4.0
    @test maximum(p3) == 4.0
    @test maximum(p4) == 4.0
    @test maximum(p5) == 4.0

    p1 = Parameter(:μ, 0.0, 1.0, 3)
    p2 = Parameter(:ν, 1.0, 1.0, 1)
    p3 = Parameter(:σ, 0.0, 4.0, 2)

    @test NamedTuple(p1, p2, p3) == NamedTuple{(:μ, :ν, :σ)}((p1, p2, p3))

    h5save(h5file, p1; mode = "w")
    @test isfile(h5file)

    p2 = h5load(Parameter, h5file; path = "μ")
    rm(h5file)
    @test p1 == p2
end

@testset "Parameter keeps the element type of its bounds ($T)" for T in (Float32, Float64)
    for name in (:mu, "mu")
        p = Parameter(name, zero(T), one(T), 5)
        @test p.name === :mu
        @test minimum(p) isa T
        @test maximum(p) isa T
        @test eltype(collect(p)) === T
        @test collect(p) == T[0, 1 // 4, 1 // 2, 3 // 4, 1]
    end

    # bounds across the range of `T`; each gives `T` samples between the bounds
    for (a, b) in ((-zero(T), nextfloat(zero(T))), (floatmin(T), eps(T)),
        (-floatmax(T) / 2, floatmax(T) / 2), (-one(T), floatmax(T)),
        ((T(10)^k .* (-one(T), one(T)) for k in -8:4:8)...))
        p = Parameter(:mu, a, b, 3)
        @test eltype(collect(p)) === T
        @test all(a .≤ collect(p) .≤ b)
    end
end

@testset "Parameter show" begin
    p = Parameter(:μ, 0.0, 1.0, 3)
    @test sprint(show, MIME"text/plain"(), p) ==
          "Parameter μ with \n   minimum = 0.0\n   maximum = 1.0\n   samples = \n" *
          sprint(show, p.samples)
end

@testset "read_parameters from a file path" begin
    params = (a = 1.0, b = 2)
    @test !isfile(h5file)
    ReducedComplexityModeling.save_parameters(h5file, params)
    @test ReducedComplexityModeling.read_parameters(h5file) == params
    rm(h5file)
end

@testset "read_parameters keeps the key order" begin
    params = (b = 2, a = 1.0)
    ReducedComplexityModeling.save_parameters(h5file, params)
    @test ReducedComplexityModeling.read_parameters(h5file) == params
    rm(h5file)
end

@testset "read_parameters reads a group without creation order" begin
    # a group created without `track_order` lists its keys alphabetically
    ReducedComplexityModeling.HDF5.h5open(h5file, "w") do file
        g = ReducedComplexityModeling.HDF5.create_group(file, "parameters")
        g["b"] = 2
        g["a"] = 1.0
    end
    @test ReducedComplexityModeling.read_parameters(h5file) == (a = 1.0, b = 2)
    rm(h5file)
end
