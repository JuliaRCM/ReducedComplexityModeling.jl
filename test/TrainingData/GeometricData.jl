using GeometricIntegrators
using OffsetArrays: OffsetVector
using ReducedComplexityModeling
using Test

const RCM = ReducedComplexityModeling

# The harmonic oscillator q̇₁ = q₂, q̇₂ = −q₁; each initial condition gives a different solution.
oscillator!(v, t, q, params) = (v[1] = q[2]; v[2] = -q[1])

function oscillator_solution(q0, tend)
    integrate(ODEProblem(oscillator!, (0.0, tend), 0.01, q0), ExplicitEuler())
end

sol1 = oscillator_solution([1.0, 0.0], 0.1)
sol2 = oscillator_solution([0.0, 2.0], 0.1)
sol3 = oscillator_solution([3.0, 1.0], 0.05)

@testset "Independent: slice i is the snapshot matrix of solution i" begin
    Z = GeometricIntegratorEnsembleData(RCM.GeometricSolution[sol1, sol2], Independent()).snapshot
    @test size(Z) == (2, length(sol1.q), 2)
    @test Z[:, :, 1] == RCM.snapshot_matrix(sol1.q)
    @test Z[:, :, 2] == RCM.snapshot_matrix(sol2.q)
    @test Z[:, 1, 2] == [0.0, 2.0]

    @test_throws ArgumentError GeometricIntegratorEnsembleData(
        RCM.GeometricSolution[sol1, sol3], Independent())

    # a solution with one component after one with two
    decay!(v, t, q, params) = (v[1] = -q[1])
    sol1d = integrate(ODEProblem(decay!, (0.0, 0.1), 0.01, [1.0]), ExplicitEuler())
    @test length(sol1d.q) == length(sol1.q)
    @test_throws ArgumentError GeometricIntegratorEnsembleData(
        RCM.GeometricSolution[sol1, sol1d], Independent())
end

@testset "The snapshot promotes the element types of all solutions" begin
    # 1e40 overflows to Inf in Float32
    sol32 = integrate(ODEProblem(oscillator!, (0.0f0, 0.1f0), 0.01f0, Float32[1, 0]),
        ExplicitEuler())
    sol64 = integrate(ODEProblem(oscillator!, (0.0, 0.1), 0.01, [1e40, 0.0]), ExplicitEuler())
    @test eltype(sol32.q[1]) === Float32
    sols = RCM.GeometricSolution[sol32, sol64]

    Z = GeometricIntegratorEnsembleData(sols, Independent()).snapshot
    @test eltype(Z) === Float64
    @test Z[1, 1, 2] == 1e40
    @test Z[:, :, 1] == RCM.snapshot_matrix(sol32.q)
    @test Z[:, :, 2] == RCM.snapshot_matrix(sol64.q)

    Z = GeometricIntegratorEnsembleData(sols, Dependent()).snapshot
    @test eltype(Z) === Float64
    @test Z[1, length(sol32.q) + 1] == 1e40
    @test Z == hcat(RCM.snapshot_matrix(sol32.q), RCM.snapshot_matrix(sol64.q))
end

@testset "The snapshot of one solution has its element type" begin
    sol32 = integrate(ODEProblem(oscillator!, (0.0f0, 0.1f0), 0.01f0, Float32[1, 0]),
        ExplicitEuler())
    @test eltype(GeometricIntegratorData(sol32).snapshot) === Float32
end

@testset "Dependent: the snapshot matrices side by side" begin
    for sols in ((sol1, sol2), (sol1, sol3), (sol3, sol1))
        Z = GeometricIntegratorEnsembleData(RCM.GeometricSolution[sols...], Dependent()).snapshot
        @test Z == hcat(RCM.snapshot_matrix(sols[1].q), RCM.snapshot_matrix(sols[2].q))
    end
end

@testset "Dependent: solutions with different state dimensions throw" begin
    decay!(v, t, q, params) = (v[1] = -q[1])
    sol1d = integrate(ODEProblem(decay!, (0.0, 0.1), 0.01, [1.0]), ExplicitEuler())
    @test length(sol1d.q) == length(sol1.q)
    @test_throws ArgumentError GeometricIntegratorEnsembleData(
        RCM.GeometricSolution[sol1, sol1d], Dependent())
    @test_throws ArgumentError GeometricIntegratorEnsembleData(
        RCM.GeometricSolution[sol1d, sol1], Dependent())
end

@testset "An offset-indexed vector of solutions" begin
    sols = OffsetVector([sol1, sol2], 0:1)
    for deps in (Dependent(), Independent())
        data = GeometricIntegratorEnsembleData(sols, deps)
        @test data.snapshot ==
              GeometricIntegratorEnsembleData(RCM.GeometricSolution[sol1, sol2], deps).snapshot
        @test data.solutions == [sol1, sol2]
    end
end

@testset "A solution with only its initial entry" begin
    # a step larger than the number of time steps stores the initial state alone
    prob = ODEProblem(oscillator!, (0.0, 0.1), 0.01, [1.0, 0.0])
    sol0 = RCM.GeometricSolution(prob, 1000)
    @test length(sol0.q) == 1

    @test RCM.snapshot_matrix(sol0.q) == reshape([1.0, 0.0], 2, 1)
    @test GeometricIntegratorData(sol0).snapshot == reshape([1.0, 0.0], 2, 1)
    sols = RCM.GeometricSolution[sol0, sol0]
    @test GeometricIntegratorEnsembleData(sols, Dependent()).snapshot == [1.0 1.0; 0.0 0.0]
    @test GeometricIntegratorEnsembleData(sols, Independent()).snapshot ==
          reshape([1.0, 0.0, 1.0, 0.0], 2, 1, 2)
end

@testset "The fields of the data types are concretely typed" begin
    data = GeometricIntegratorData(sol1)
    @test isconcretetype(typeof(data))
    @test all(isconcretetype, fieldtypes(typeof(data)))
    @test typeof(data.snapshot) === Matrix{Float64}

    for (deps, N) in ((Dependent(), 2), (Independent(), 3))
        ens = GeometricIntegratorEnsembleData([sol1, sol2], deps)
        @test isconcretetype(typeof(ens))
        @test all(isconcretetype, fieldtypes(typeof(ens)))
        @test typeof(ens.snapshot) === Array{Float64, N}
    end
end

@testset "A vector with a concrete element type" begin
    sols = [sol1, sol2]
    @test !(sols isa Vector{RCM.GeometricSolution})
    for deps in (Dependent(), Independent())
        data = GeometricIntegratorEnsembleData(sols, deps)
        @test data.snapshot ==
              GeometricIntegratorEnsembleData(RCM.GeometricSolution[sol1, sol2], deps).snapshot
        @test data.solutions == sols
    end
end
