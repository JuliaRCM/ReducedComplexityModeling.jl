using GeometricIntegrators
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
end

@testset "Dependent: the snapshot matrices side by side" begin
    for sols in ((sol1, sol2), (sol1, sol3), (sol3, sol1))
        Z = GeometricIntegratorEnsembleData(RCM.GeometricSolution[sols...], Dependent()).snapshot
        @test Z == hcat(RCM.snapshot_matrix(sols[1].q), RCM.snapshot_matrix(sols[2].q))
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
