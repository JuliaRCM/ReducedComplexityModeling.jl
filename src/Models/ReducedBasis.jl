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
    reduction_scheme
    snapshot
    reduced_basis

    function ReducedBasisModel(alg,snaps)
        new(alg,snaps)
    end 
end

function reduce!(model::ReducedBasisModel,k::Int,::POD)
    U,_,_ = svd(model.snapshot)
    model.reduced_basis = U[:,1:k]    
end 

function reduce!(model::ReducedBasisModel,k::Int,::CotangentLiftEVD)
    snapshot = model.snapshot
    @assert mod(size(snapshot,1),2)==0 "The solutions in the snapshot are not sympletic"
    n = floor(Int,size(snapshot,1)/2)
    q,p = snapshot[1:n,:],snapshot[n+1:end,:]
    cotangent_snap = hcat(q,p)
    U,_,_ = svd(cotangent_snap)[:,1:k]
    reduced_basis = zeros(2*n,2*k)
    reduced_basis[1:n,1:k] = U
    reduced_basis[n+1:2*n,k+1:2*k] = U
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

function reduce!(model::ReducedBasisModel,k::Int,::ComplexSVD)
    snapshot = model.snapshot
    @assert mod(size(snapshot,1),2) == 0 "The solutions in the snapshot are not symplectic"
    n = floor(Int,size(snapshot,1)/2)
    q,p = snapshot[1:n,:],snapshot[n+1:end,:]
    csvd_snap = q + 1im * p
    U,_,_ = svd(csvd_snap)
    ϕ,Ψ = real.(U),imag.(U)
    reduced_basis = zeros(2*n,2*k)
    reduced_basis[1:n,1:k] = Φ
    reduced_basis[1:n,k+1:2*k] = -Ψ
    reduced_basis[n+1:2*n,1:k] = Ψ
    reduced_basis[n+1:2*n:k+1:2*k] = Φ
    model.reduced_basis = reduced_basis
end 

function compose(prob::ODEProblem, model::ReducedBasisModel)
    vel = functions(prob).v
    Rᵦ = model.reduced_basis

    function red_v(du,t,u,p)
        utemp = Rᵦ*u 
        dutemp = zero(utemp)
        vel(dutemp,t,utemp)
        du .= Rᵦ' * dutemp
    end

    u0 = initial_conditions(prob).q
    init = Rᵦ' * reshape(u0, (length(u0),1))
    red_prob = ODEProblem(red_v, tspan(prob), tstep(prob), init[:,1]; parameters = parameters(prob))
    red_prob
end 

function project(rsol::GeometricSolution, model::ReducedBasisModel)
    Rᵦ = model.reduced_basis
    Rᵦ * snapshot_matrix(rsol.q)
end