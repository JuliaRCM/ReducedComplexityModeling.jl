using GeometricBase
using Optim
using ReducedComplexityModeling
using Test

const RCM = ReducedComplexityModeling

const NSTEPS = 20

"`NSTEPS` steps of the explicit-Euler map of `q̇ = p/m`, `ṗ = −kq`, with `h = 1/10`, from `(1, 0)`."
function euler_trajectory(::Type{T}, k, m) where {T}
    h = one(T) / T(10)
    X = Matrix{T}(undef, 2, NSTEPS + 1)
    q = one(T)
    p = zero(T)
    X[1, 1] = q
    X[2, 1] = p
    for n in 1:NSTEPS
        q = q + h * p / m
        p = p - h * k * q
        X[1, n + 1] = q
        X[2, n + 1] = p
    end
    return X
end

# The same map as the residual: the difference from the recorded trajectory, times `scale`.
function euler_residual(data, θ, scale)
    X = data.data
    W = promote_type(eltype(X), typeof(θ.k), typeof(θ.m))
    h = one(W) / W(10)
    s = W(scale)
    r = Vector{W}(undef, 2 * NSTEPS)
    q = W(X[1, 1])
    p = W(X[2, 1])
    for n in 1:NSTEPS
        q = q + h * p / θ.m
        p = p - h * θ.k * q
        r[2n - 1] = s * (q - X[1, n + 1])
        r[2n] = s * (p - X[2, n + 1])
    end
    return r
end

"The `TrainingProblem` of the two-parameter model, with the residual scaled by `scale`."
function euler_problem(::Type{T}, scale) where {T}
    k, m = T(17) / T(10), T(11) / T(20)
    time = collect(zero(T):(T(1) / T(10)):T(2))
    X = euler_trajectory(T, k, m)
    data = RCM.TrainingData{
        RCM.ObservableSpace, StateData, CanonicalHamiltonianSystem}(time, X)
    parameters = RCM.ParameterSpace(
        RCM.Parameter(:k, T(1), T(3), 4), RCM.Parameter(:m, T(3) / 10, T(9) / 10, 3))
    return RCM.TrainingProblem(data, (d, θ) -> euler_residual(d, θ, scale), parameters)
end

# A problem over one trivial `TrainingData`, for a residual that needs no data.
function trivial_problem(residual, parameters)
    data = RCM.TrainingData{
        RCM.ObservableSpace, StateData, CanonicalHamiltonianSystem}([0.0], zeros(1, 1))
    return RCM.TrainingProblem(data, residual, parameters)
end

@testset "TrainingProblem" begin
    @test !isdefined(RCM, :learn)
    @test parentmodule(RCM.train) === RCM
    @test isempty(methods(RCM.train!))

    @testset "train recovers two known parameters" begin
        for T in (Float32, Float64)
            ktrue, mtrue = T(17) / T(10), T(11) / T(20)
            for scale in (one(T), T(1e-4), T(1e-8), T(1e8))
                problem = euler_problem(T, scale)
                # the truth is not a sample, so a fit that stops where it starts cannot pass
                @test all(s -> (s.k, s.m) ≠ (ktrue, mtrue), collect(problem.parameters))

                fit = train(problem, LBFGS())
                @test typeof(fit.k) === T
                @test typeof(fit.m) === T
                @test isapprox(fit.k, ktrue; rtol = sqrt(eps(T)))
                @test isapprox(fit.m, mtrue; rtol = sqrt(eps(T)))
            end
        end
    end

    @testset "the scan starts from the smallest finite loss" begin
        # its finite samples sit at a = 7/2 with loss 2.5625, away from the minimiser a = 4;
        # the samples with a = 0 are NaN, and the mid-range of the box reaches a = 1 instead
        residual = function (d, θ)
            a, b = θ.a, θ.b
            a < 1 / 2 && return [NaN, NaN]
            return [(a - 1) * (a - 4), b - 2]
        end
        parameters = RCM.ParameterSpace(
            RCM.Parameter(:a, 0.0, 7 / 2, 2), RCM.Parameter(:b, 1.0, 3.0, 2))

        fit = train(trivial_problem(residual, parameters), LBFGS())
        @test isapprox(fit.a, 4)
        @test isapprox(fit.b, 2)
    end

    @testset "a loss that is nowhere finite is an ArgumentError" begin
        parameters = RCM.ParameterSpace(
            RCM.Parameter(:a, 0.0, 1.0, 2), RCM.Parameter(:b, 0.0, 1.0, 2))
        @test_throws ArgumentError train(
            trivial_problem((d, θ) -> [NaN, NaN], parameters), LBFGS())
        @test_throws ArgumentError train(
            trivial_problem((d, θ) -> [Inf, -Inf], parameters), LBFGS())
    end

    @testset "no convergence is an error" begin
        parameters = RCM.ParameterSpace(
            RCM.Parameter(:a, 0.0, 1.0, 2), RCM.Parameter(:b, 0.0, 2.0, 2))
        @test_throws ErrorException train(
            trivial_problem((d, θ) -> [exp(-θ.a), θ.b - 1], parameters), LBFGS())
    end

    @testset "an exception of the residual propagates" begin
        parameters = RCM.ParameterSpace(
            RCM.Parameter(:a, 0.0, 1.0, 2), RCM.Parameter(:b, 0.0, 1.0, 2))
        @test_throws DomainError train(
            trivial_problem((d, θ) -> throw(DomainError(θ.a, "no model")), parameters),
            LBFGS())
    end

    @testset "the method is a first-order optimizer" begin
        problem = euler_problem(Float64, 1.0)
        @test_throws MethodError train(problem, NelderMead())
    end
end
