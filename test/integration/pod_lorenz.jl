include("../helpers/problems.jl")
using LinearAlgebra
using ReducedComplexityModeling
using ReducedComplexityModeling: POD, reduce!, compose
using Test

begin
    # Lorenz problem with POD

    # Reduced Basis Model Pipeline
    #------------------------------------------------------------------------------

    # 1. Get data. A short time span: on (0, 100) the Lorenz system is chaotic and grows the
    # round-off of the reduced integration to O(1).
    prob, sol = lorenz_problem(; tspan = (0.0, 1.0))
    data = GeometricIntegratorData(sol)

    # 2. Define a model with an appropriate algorithm.
    ## TODO : Extend the algorithm struct to carry its parameters.
    k=3
    alg = POD()
    model = ReducedBasisModel(alg, data.snapshot)

    # This falls into the learn function.
    reduce!(model, k, alg)
    red_prob = compose(prob, model)
    red_sol = integrate(red_prob, ExplicitEuler())
    psol = project(red_sol, model)

    # With k = 3 the basis is an orthogonal 3 × 3 matrix, and the explicit Euler steps of the
    # reduced problem are those of the full problem in rotated coordinates, so the projected
    # solution is the snapshot of the full integration. The relative error is 1.5e-15.
    @testset "POD with k = n reproduces the full solution" begin
        R = model.reduced_basis
        @test R' * R ≈ I(k) atol=1e-12
        @test size(psol) == size(data.snapshot)
        @test psol ≈ data.snapshot rtol=1e-12
    end

    #------------------------------------------------------------------------------

    # Visualization and Shennanigans
    using Plots
    atemp = 1:k
    display(plot(red_sol.q, vars = (1, 2), title = "Reduced Basis"))
    display(plot(psol[1, :], psol[2, :], psol[3, :], title = "Remade"))
    display(plot(sol.q, vars = (1, 2, 3), title = "Original"))
end

# Heat Equation. Solver first. Then use the Reduced basis.
