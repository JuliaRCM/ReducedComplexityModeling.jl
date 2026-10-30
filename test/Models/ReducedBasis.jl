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

const SYMPLECTIC_ALGS = (RCM.CotangentLiftSVD(), RCM.CotangentLiftEVD(), RCM.ComplexSVD())

@testset "reduce! with $(nameof(typeof(alg)))" for alg in SYMPLECTIC_ALGS
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

@testset "The cotangent lift by SVD and by EVD span the same space" begin
    n, k, m = 6, 3, 12
    X = lowrank_snapshot(Xoshiro(2), n, k, m)
    A_svd = reduce!(ReducedBasisModel(RCM.CotangentLiftSVD(), X), k, RCM.CotangentLiftSVD())
    A_evd = reduce!(ReducedBasisModel(RCM.CotangentLiftEVD(), X), k, RCM.CotangentLiftEVD())
    # the orthogonal projectors on the two column spaces agree
    @test A_svd * A_svd' ≈ A_evd * A_evd' atol=1e-12
end

@testset "The cotangent lifts reject a complex snapshot, $(nameof(typeof(alg)))" for alg in (
    RCM.CotangentLiftSVD(), RCM.CotangentLiftEVD())
    X = ComplexF64[1 0; im 0; 0 0; 0 0]
    @test_throws MethodError reduce!(ReducedBasisModel(alg, X), 1, alg)
end

@testset "reduce! beyond the thin SVD, $(nameof(typeof(alg)))" for alg in SYMPLECTIC_ALGS
    # a 6 × 1 snapshot has n = 3 and one snapshot column, so k = 2 and k = 3 need completion
    X = reshape(Float64[1, 2, 3, 4, 5, 6], 6, 1)
    for k in 1:3
        A = reduce!(ReducedBasisModel(alg, X), k, alg)
        @test size(A) == (6, 2k)
        @test A' * A ≈ I(2k) atol=1e-12
        @test A' * canonical_J(3) * A ≈ canonical_J(k) atol=1e-12
    end
end

@testset "POD beyond the thin SVD" begin
    X = reshape(Float64[1, 2, 3, 4, 5, 6], 6, 1)
    A = reduce!(ReducedBasisModel(RCM.POD(), X), 2, RCM.POD())
    @test size(A) == (6, 2)
    @test A' * A ≈ I(2) atol=1e-12
end

@testset "An integer snapshot gives a Float64 basis, $(nameof(typeof(alg)))" for alg in (
    RCM.POD(), SYMPLECTIC_ALGS...)
    X = [1 2; 3 4; 5 6; 7 8]
    model = ReducedBasisModel(alg, X)
    @test model isa ReducedBasisModel{typeof(alg), Float64, Matrix{Int}}
    @test eltype(reduce!(model, 1, alg)) === Float64
end

@testset "The basis has the element type of the snapshot, $(nameof(typeof(alg)))" for alg in (
    RCM.POD(), SYMPLECTIC_ALGS...)
    for T in (Float16, Float32)
        X = T.(lowrank_snapshot(Xoshiro(3), 4, 2, 10))
        model = ReducedBasisModel(alg, X)
        A = reduce!(model, 2, alg)
        @test A === model.reduced_basis
        @test eltype(A) === T
    end
end

@testset "The fields of ReducedBasisModel are concretely typed" begin
    X = lowrank_snapshot(Xoshiro(4), 4, 2, 10)
    model = ReducedBasisModel(RCM.POD(), X)
    @test model isa ReducedBasisModel{RCM.POD, Float64, Matrix{Float64}}
    @test isconcretetype(typeof(model))
    @test all(isconcretetype, fieldtypes(typeof(model)))
end
