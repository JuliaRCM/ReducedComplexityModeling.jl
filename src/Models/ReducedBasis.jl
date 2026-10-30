"""
    POD()

Proper orthogonal decomposition: `reduce!(model, k, POD())` takes the first `k` left singular
vectors of the snapshot matrix as the reduced basis.
"""
struct POD end
struct CotangentLiftSVD end
struct CotangentLiftEVD end
struct ComplexSVD end

"""
    ReducedBasisModel(alg, snapshot)

A reduced-basis model of the snapshot matrix `snapshot`, whose columns are the snapshots, with
the reduction scheme `alg`, such as [`POD`](@ref). [`reduce!`](@ref) computes the reduced basis
and stores it in the field `reduced_basis`, which is undefined until then.
"""
mutable struct ReducedBasisModel{AT, T, ST <: AbstractMatrix{T}} <: AbstractModel
    reduction_scheme::AT
    snapshot::ST
    reduced_basis::Matrix{T}

    function ReducedBasisModel(alg::AT, snaps::ST) where {AT, T, ST <: AbstractMatrix{T}}
        new{AT, T, ST}(alg, snaps)
    end
end

"""
    reduce!(model::ReducedBasisModel, k::Int, ::POD)
    reduce!(model::ReducedBasisModel, k::Int, ::CotangentLiftSVD)
    reduce!(model::ReducedBasisModel, k::Int, ::CotangentLiftEVD)
    reduce!(model::ReducedBasisModel, k::Int, ::ComplexSVD)

Compute a reduced basis from the snapshot matrix of `model`, whose columns are the snapshots,
store it in `model.reduced_basis` and return it. With [`POD`](@ref), the basis is the matrix of
the first `k` left singular vectors of the snapshot matrix. With `CotangentLiftSVD()`,
`CotangentLiftEVD()` and `ComplexSVD()`, which the package does not export, the snapshot has `2n`
rows, `q` above `p`, and the basis is an orthonormal and symplectic `2n × 2k` matrix, for
`k ≤ n`. `CotangentLiftSVD()` and `CotangentLiftEVD()` give the cotangent lift of the first `k`
left singular vectors of `[q p]`: the first takes them from the singular value decomposition of
`[q p]`, the second from the eigendecomposition of the Gram matrix `q qᵀ + p pᵀ`. `ComplexSVD()`
gives the real form of the first `k` left singular vectors of `q + im * p`. Where `k` exceeds the
number of singular vectors, the basis is completed with orthonormal vectors. The basis has the
element type of the snapshot.
"""
function reduce!(model::ReducedBasisModel, k::Int, ::POD)
    U, _, _ = svd(model.snapshot)
    model.reduced_basis = U[:, 1:k]
end

# the first `k` left singular vectors of `A`, completed to an orthonormal set where `A` has
# fewer than `k` of them
function _left_singular_vectors(A, k)
    svd(A; full = k > minimum(size(A))).U[:, 1:k]
end

# `n`, `q` and `p` of a snapshot with `2n` rows
function _split_snapshot(snapshot)
    @assert iseven(size(snapshot, 1)) "The solutions in the snapshot are not symplectic"
    n = size(snapshot, 1) ÷ 2
    n, snapshot[1:n, :], snapshot[(n + 1):end, :]
end

# the `2n × 2k` matrix `blockdiag(U, U)`
function _cotangent_lift(U)
    n, k = size(U)
    A = zeros(eltype(U), 2n, 2k)
    A[1:n, 1:k] = U
    A[(n + 1):(2n), (k + 1):(2k)] = U
    A
end

function reduce!(model::ReducedBasisModel, k::Int, ::CotangentLiftSVD)
    _, q, p = _split_snapshot(model.snapshot)
    model.reduced_basis = _cotangent_lift(_left_singular_vectors(hcat(q, p), k))
end

function reduce!(model::ReducedBasisModel, k::Int, ::CotangentLiftEVD)
    n, q, p = _split_snapshot(model.snapshot)
    gram = Symmetric(q * q' + p * p')
    # `eigen` sorts the eigenvalues in ascending order: take the `k` largest, largest first
    U = eigen(gram, (n - k + 1):n).vectors[:, k:-1:1]
    model.reduced_basis = _cotangent_lift(U)
end

function reduce!(model::ReducedBasisModel, k::Int, ::ComplexSVD)
    n, q, p = _split_snapshot(model.snapshot)
    U = _left_singular_vectors(q + im * p, k)
    Φ, Ψ = real.(U), imag.(U)
    reduced_basis = zeros(eltype(Φ), 2n, 2k)
    reduced_basis[1:n, 1:k] = Φ
    reduced_basis[1:n, (k + 1):(2k)] = -Ψ
    reduced_basis[(n + 1):(2n), 1:k] = Ψ
    reduced_basis[(n + 1):(2n), (k + 1):(2k)] = Φ
    model.reduced_basis = reduced_basis
end

"""
    compose(prob::ODEProblem, model::ReducedBasisModel)

The reduced problem of `prob` in the reduced basis `R = model.reduced_basis`: an `ODEProblem` in
the reduced coordinates `u`, with the vector field `R' * v(R * u)`, where `v` is the vector field
of `prob`, and the initial condition `R' * q₀`. The time span, the time step and the parameters
are those of `prob`. Call [`reduce!`](@ref) on `model` first.
"""
function compose(prob::ODEProblem, model::ReducedBasisModel)
    Rᵦ = model.reduced_basis

    function red_v(du, t, u, p)
        utemp = Rᵦ*u
        dutemp = zero(utemp)
        functions(prob).v(dutemp, t, utemp, p)
        du .= Rᵦ' * dutemp
    end

    u0 = initial_conditions(prob).q
    init = Rᵦ' * reshape(u0, (length(u0), 1))
    red_prob = ODEProblem(
        red_v, timespan(prob), timestep(prob), init[:, 1]; parameters = parameters(prob))
    red_prob
end

"""
    project(rsol::GeometricSolution, model::ReducedBasisModel)

Map the solution `rsol` of a reduced problem (see [`compose`](@ref)) back to the full space. The
result is the matrix `model.reduced_basis * Q`, where the columns of `Q` are the entries of
`rsol.q`; its columns are the states in the full space.
"""
function project(rsol::GeometricSolution, model::ReducedBasisModel)
    Rᵦ = model.reduced_basis
    Rᵦ * snapshot_matrix(rsol.q)
end
