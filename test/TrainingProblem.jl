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
        qnext = q + h * p / m
        pnext = p - h * k * q
        q, p = qnext, pnext
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
        qnext = q + h * p / θ.m
        pnext = p - h * θ.k * q
        q, p = qnext, pnext
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

# A problem over one trivial `TrainingData` in `T`, for a residual that needs no data.
function trivial_problem(::Type{T}, residual, parameters) where {T}
    data = RCM.TrainingData{
        RCM.ObservableSpace, StateData, CanonicalHamiltonianSystem}(T[0], zeros(T, 1, 1))
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

    @testset "the recorded data are the explicit Euler map" begin
        # an independent computation of the map, so the fixture cannot drift to another scheme
        for T in (Float32, Float64)
            k, m = T(17) / T(10), T(11) / T(20)
            h = one(T) / T(10)
            X = euler_trajectory(T, k, m)
            q, p = one(T), zero(T)
            @test X[1, 1] == q
            @test X[2, 1] == p
            for n in 1:NSTEPS
                qnext = q + h * p / m
                pnext = p - h * k * q
                q, p = qnext, pnext
                @test X[1, n + 1] == q
                @test X[2, n + 1] == p
            end
        end
    end

    @testset "the scan starts from the smallest finite loss" begin
        # the samples of `a` are 0, 7/4 and 7/2: a = 0 is NaN, a = 7/4 is finite but larger
        # (loss 3.8477) and reaches a = 1, and a = 7/2 (loss 2.5625) reaches the minimiser
        # a = 4. The first finite sample and the largest finite loss are both a = 7/4, so a
        # scan that picks either of those reaches a = 1 and fails the assertion.
        for T in (Float32, Float64)
            residual = function (d, θ)
                a, b = θ.a, θ.b
                a < T(1) / 2 && return T[NaN, NaN]
                return [(a - 1) * (a - 4), b - 2]
            end
            parameters = RCM.ParameterSpace(
                RCM.Parameter(:a, T(0), T(7) / 2, 3), RCM.Parameter(:b, T(1), T(3), 2))

            fit = train(trivial_problem(T, residual, parameters), LBFGS())
            @test typeof(fit.a) === T
            @test isapprox(fit.a, T(4); rtol = sqrt(eps(T)))
            @test isapprox(fit.b, T(2); rtol = sqrt(eps(T)))
        end
    end

    @testset "a loss that is nowhere finite is an ArgumentError" begin
        for T in (Float32, Float64)
            parameters = RCM.ParameterSpace(
                RCM.Parameter(:a, T(0), T(1), 2), RCM.Parameter(:b, T(0), T(1), 2))
            @test_throws ArgumentError train(
                trivial_problem(T, (d, θ) -> T[NaN, NaN], parameters), LBFGS())
            @test_throws ArgumentError train(
                trivial_problem(T, (d, θ) -> T[Inf, -Inf], parameters), LBFGS())
        end
    end

    @testset "no convergence is an error" begin
        for T in (Float32, Float64)
            parameters = RCM.ParameterSpace(
                RCM.Parameter(:a, T(0), T(1), 2), RCM.Parameter(:b, T(0), T(2), 2))
            @test_throws ErrorException train(
                trivial_problem(T, (d, θ) -> [exp(-θ.a), θ.b - one(T)], parameters), LBFGS())
        end
    end

    @testset "an exception of the residual propagates" begin
        for T in (Float32, Float64)
            parameters = RCM.ParameterSpace(
                RCM.Parameter(:a, T(0), T(1), 2), RCM.Parameter(:b, T(0), T(1), 2))
            @test_throws DomainError train(
                trivial_problem(T, (d, θ) -> throw(DomainError(θ.a, "no model")), parameters),
                LBFGS())
        end
    end

    @testset "the method is a first-order optimizer" begin
        for T in (Float32, Float64)
            @test_throws MethodError train(euler_problem(T, one(T)), NelderMead())
        end
    end
end
