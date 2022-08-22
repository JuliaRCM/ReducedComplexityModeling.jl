using ReducedBasisMethods:CotangentLiftEVD,CotangentLiftSVD,ReductionAlgorithm
struct POD end 

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

end

function reduce!(model::ReducedBasisModel,k::Int,::CotangentLiftSVD)

end 

function compose(prob::ODEProblem, model::ReducedBasisModel)
    vel = prob.f 
    Rᵦ = model.reduced_basis

    function red_v(du,u,p,t)
        utemp = Rᵦ*u 
        dutemp = zero(utemp)
        vel(dutemp,utemp,p,t)
        du .= Rᵦ' * dutemp
    end

    init = Rᵦ' * reshape(prob.u0,(length(prob.u0),1))
    init1 = init[:,1]
    red_prob = ODEProblem(red_v,init1,prob.tspan,prob.p)
    red_prob
end 

function project(rsol::ODESolution,model::ReducedBasisModel)
    Rᵦ = model.reduced_basis
    Rᵦ * Array(rsol)
end 