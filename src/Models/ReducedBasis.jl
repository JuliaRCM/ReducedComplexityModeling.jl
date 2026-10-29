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
Reduced Basis

Uses ModelOrderReduction methods from ReducedBasisMethods.jl
to represent the data in latent space.

"""
mutable struct ReducedBasisModel <: AbstractModel
    reduction_scheme::Any
    snapshot::Any
    reduced_basis::Any

    function ReducedBasisModel(alg, snaps)
        new(alg, snaps)
    end
end

"""
    reduce!(model::ReducedBasisModel, k::Int, ::POD)

Compute a reduced basis of dimension `k` from the snapshot matrix of `model`, whose columns are
the snapshots, store it in `model.reduced_basis` and return it. With [`POD`](@ref), the basis is
the matrix of the first `k` left singular vectors of the snapshot matrix.
"""
function reduce!(model::ReducedBasisModel, k::Int, ::POD)
    U, _, _ = svd(model.snapshot)
    model.reduced_basis = U[:, 1:k]
end

function reduce!(model::ReducedBasisModel, k::Int, ::CotangentLiftEVD)
    snapshot = model.snapshot
    @assert mod(size(snapshot, 1), 2)==0 "The solutions in the snapshot are not sympletic"
    n = floor(Int, size(snapshot, 1)/2)
    q, p = snapshot[1:n, :], snapshot[(n + 1):end, :]
    cotangent_snap = hcat(q, p)
    U, _, _ = svd(cotangent_snap)[:, 1:k]
    reduced_basis = zeros(2*n, 2*k)
    reduced_basis[1:n, 1:k] = U
    reduced_basis[(n + 1):(2 * n), (k + 1):(2 * k)] = U
    model.reduced_basis = reduced_basis
end

# function reduce!(model::ReducedBasisModel,k::Int,::CotangentLiftEVD)
#     snapshot = model.snapshot
#     @assert mod(size(snapshot,1),2)==0 "The solutions in the snapshot are not sympletic"
#     n = floor(Int,size(snapshot,1)/2)
#     q,p = snapshot[1:n,:],snapshot[n+1:end,:]
#     cotangent_snap = hcat(q,p)
#     U = eigen(cotangent_snap).vectors[:,1:k]
#     reduced_basis = zeros(2*n,2*k)
#     reduced_basis[1:n,1:k] = U
#     reduced_basis[n+1:2*n,k+1:2*k] = U
#     model.reduced_basis = reduced_basis
# end

function reduce!(model::ReducedBasisModel, k::Int, ::ComplexSVD)
    snapshot = model.snapshot
    @assert mod(size(snapshot, 1), 2) == 0 "The solutions in the snapshot are not symplectic"
    n = floor(Int, size(snapshot, 1)/2)
    q, p = snapshot[1:n, :], snapshot[(n + 1):end, :]
    csvd_snap = q + 1im * p
    U, _, _ = svd(csvd_snap)
    ϕ, Ψ = real.(U), imag.(U)
    reduced_basis = zeros(2*n, 2*k)
    reduced_basis[1:n, 1:k] = Φ
    reduced_basis[1:n, (k + 1):(2 * k)] = -Ψ
    reduced_basis[(n + 1):(2 * n), 1:k] = Ψ
    reduced_basis[((n + 1):(2 * n):(k + 1)):(2 * k)] = Φ
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
