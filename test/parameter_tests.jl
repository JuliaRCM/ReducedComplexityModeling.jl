
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

    @test hassamples(p1) == true
    @test hassamples(p2) == true
    @test hassamples(p3) == true
    @test hassamples(p4) == false
    @test hassamples(p5) == false

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

@testset "Every exported name is defined" begin
    @test isempty(filter(
        n -> !isdefined(ReducedComplexityModeling, n), names(ReducedComplexityModeling)))
end
