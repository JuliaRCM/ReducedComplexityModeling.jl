using Random: Xoshiro

@testset "RandomParameterSampler" begin
    μ = Parameter(:μ, 0.0, 1.0)
    ν = Parameter(:ν, -2.0, 3.0)
    σ = Parameter(:σ, 1.0f0, 4.0f0)

    s1 = sample(RandomParameterSampler(100, Xoshiro(42)), μ, ν, σ)
    s2 = sample(RandomParameterSampler(100, Xoshiro(42)), μ, ν, σ)
    s3 = sample(RandomParameterSampler(100, Xoshiro(43)), μ, ν, σ)

    @test s1 == s2
    @test s1 != s3
    @test length(s1) == 100

    @test all(minimum(μ) .≤ s1.μ .≤ maximum(μ))
    @test all(minimum(ν) .≤ s1.ν .≤ maximum(ν))
    @test all(minimum(σ) .≤ s1.σ .≤ maximum(σ))
    @test eltype(s1.σ) == Float32

    # the draws cover the box and do not collapse onto a point
    @test length(unique(s1.μ)) == 100
    @test minimum(s1.ν) < 0 < maximum(s1.ν)

    ps1 = ParameterSpace(RandomParameterSampler(10, Xoshiro(1)), μ, ν)
    ps2 = ParameterSpace(RandomParameterSampler(10, Xoshiro(1)), μ, ν)
    @test ps1 == ps2
    @test size(ps1) == (10, 2)

    @test_throws AssertionError RandomParameterSampler(0)
end

@testset "QuasiRandomParameterSampler" begin
    μ = Parameter(:μ, 0.0, 1.0)
    ν = Parameter(:ν, 0.0, 1.0)
    σ = Parameter(:σ, 0.0, 10.0)

    s = sample(QuasiRandomParameterSampler(5), μ, ν, σ)

    # the Halton sequence in bases 2, 3 and 5, starting at index one
    @test s.μ ≈ [1 / 2, 1 / 4, 3 / 4, 1 / 8, 5 / 8]
    @test s.ν ≈ [1 / 3, 2 / 3, 1 / 9, 4 / 9, 7 / 9]
    @test s.σ ≈ 10 .* [1 / 5, 2 / 5, 3 / 5, 4 / 5, 1 / 25]

    @test s == sample(QuasiRandomParameterSampler(5), μ, ν, σ)

    ps = ParameterSpace(QuasiRandomParameterSampler(8), μ, ν)
    @test size(ps) == (8, 2)
    @test ps[1] == (μ = 1 / 2, ν = 1 / 3)

    @test_throws AssertionError QuasiRandomParameterSampler(0)
end
