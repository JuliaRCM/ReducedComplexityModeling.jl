using ForwardDiff
using GeometricIntegrators
using LinearAlgebra
using Random: Xoshiro
using ReducedComplexityModeling
using Test

include("../helpers/eltypes.jl")

# A full vector field that does not allocate, so that the allocations measured below are those of
# the reduced vector field alone. It is nonlinear, so that its Jacobian depends on the state.
full_v!(v, t, q, params) = (v .= params.a .* sin.(q) .- q; nothing)

# A function barrier with concrete arguments, for the allocation assertion: the first call warms
# the method and the second is measured.
function allocations(f::F, du::D, t::TT, u::U, p::P) where {F, D, TT, U, P}
    f(du, t, u, p)
    @allocated f(du, t, u, p)
end

# A POD basis of `k` vectors for a full problem in `T` with `N` states, and the reduced problem of
# that full problem in that basis.
function reduced_problem(::Type{T}, N, k) where {T}
    rng = Xoshiro(N + k)
    prob = ODEProblem(full_v!, (zero(T), one(T)), T(1) / T(10), randn(rng, T, N);
        parameters = (a = T(1) / T(2),))
    model = ReducedBasisModel(POD(), randn(rng, T, N, 2k))
    reduce!(model, k, POD())
    model.reduced_basis, compose(prob, model)
end

# `Rᵦ' * v(Rᵦ * u)`, computed by hand with fresh arrays.
function reduced_by_hand(R, t, u, p)
    y = R * u
    w = similar(y)
    full_v!(w, t, y, p)
    R' * w
end

@testset "The reduced vector field of compose, $T, N = $N, k = $k" for T in REAL_ELTYPES,
    (N, k) in ((100, 5), (1000, 20))

    R, red_prob = reduced_problem(T, N, k)
    red_v = functions(red_prob).v
    p = parameters(red_prob)
    t = zero(T)
    u = randn(Xoshiro(3), T, k)
    du = zeros(T, k)

    @test eltype(R) === T

    @testset "the value is Rᵦ' * v(Rᵦ * u), and inferred" begin
        @inferred red_v(du, t, u, p)
        ref = reduced_by_hand(R, t, u, p)
        @test norm(du - ref) ≤ 8 * eps(T) * norm(ref)
    end

    @testset "a call with ForwardDiff.Dual numbers gives the Jacobian of the allocating form" begin
        J = ForwardDiff.jacobian((y, x) -> red_v(y, t, x, p), zeros(T, k), u)
        J_ref = ForwardDiff.jacobian(x -> reduced_by_hand(R, t, x, p), u)
        @test eltype(J) === T
        @test norm(J - J_ref) ≤ 8 * eps(T) * norm(J_ref)
    end

    # Coverage instrumentation can add allocations, so the reading holds only in a run without it.
    if Base.JLOptions().code_coverage == 0
        @testset "a call in the element type of the basis does not allocate" begin
            # the positive control: the barrier reports the allocations of the hand-computed form
            @test allocations(
                (y, s, x, q) -> (y .= reduced_by_hand(R, s, x, q)), du, t, u, p) > 0
            @test allocations(red_v, du, t, u, p) == 0
        end
    end
end
