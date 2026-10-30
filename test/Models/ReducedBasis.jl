using LinearAlgebra
using Random: Xoshiro
using ReducedComplexityModeling
using Test

const RCM = ReducedComplexityModeling

# The canonical symplectic matrix of dimension 2m.
canonical_J(m) = [zeros(m, m) I(m); -I(m) zeros(m, m)]

# A snapshot whose q and p columns lie in the span of the orthonormal columns of `V`, so a basis
# of `size(V, 2)` vectors in q and in p reconstructs it.
function lowrank_snapshot(rng, n, k, m)
    V = Matrix(qr(randn(rng, n, k)).Q)
    vcat(V * randn(rng, k, m), V * randn(rng, k, m))
end

@testset "reduce! with $(nameof(typeof(alg)))" for alg in (
    RCM.CotangentLiftEVD(), RCM.ComplexSVD())
    n, k, m = 4, 2, 10
    X = lowrank_snapshot(Xoshiro(1), n, k, m)
    model = ReducedBasisModel(alg, X)
    A = reduce!(model, k, alg)

    @test A === model.reduced_basis
    @test size(A) == (2n, 2k)
    # the residuals are below 1e-15; a wrong basis gives O(1)
    @test A' * A ≈ I(2k) atol=1e-12
    @test A' * canonical_J(n) * A ≈ canonical_J(k) atol=1e-12
    @test A * (A' * X) ≈ X rtol=1e-12
end
