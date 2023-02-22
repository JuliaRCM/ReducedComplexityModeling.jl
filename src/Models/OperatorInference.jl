abstract type AbstractOperatorInference end

abstract type Lineartiy end
struct Linear <: Lineartiy end 
struct Quadratic <: Lineartiy end

abstract type AbstractOptimizer end
struct LSTSQ <: AbstractOptimizer end
struct Newton <: AbstractOptimizer end

struct PlainOperatorInference <: AbstractOperatorInference
    tinterval
    snapshots
    linearity
    operator

    function PlainOperatorInference(tinterval,snapshots)
        new(tinterval,snapshots,Linear())
    end 

    function PlainOperatorInference(tinterval,snapshots,linearity)
        new(tinterval,snapshots,linearity)
    end 
end 

# We use forward difference for estimating the gradient.
# A more appropriate approximation should be using higher order Fornberg methods.
function gradient(tinterval,snapshots)
    @assert size(snapshots,2)-1 ==  length(tinterval)
    sdt = snapshots[:,2:end] - snapshots[:,1:end-1]
    for i=1:length(tinterval)
        sdt[:,i] = sdt[:,i]./tinterval[i]
    end 
    return sdt
end 

function optimize(snaps,vel,::LSTSQ)
    # Conventional inference using Least squares
    # Ax = b
    # xTAT=bT
    # AT = bT \ xT
    A = transpose(vel)\transpose(snaps)
    return tranpose(A)
end 

# Is usually very expensive
function optimize(snaps,vel,::Netwon)
    ninstances = size(vel,2)
    # Loss function
    loss = function(A)
        l = 0
        for i=1:ninstances
            eval = A*snaps[:,i]
            l += norm(eval-vel[:,i])
        end 
        return l
    end 
    
    # Setup optimization problem
    nx,ny = size(vel,1),size(snaps,1)
    A = rand(nx,ny)
    Optim.optimize(loss,A,LBFGS())
    return A
end 

function infer!(opinfer::PlainOperatorInference{Any,::Linear},opt::AbstractOptimizer)
    vel = gradient(opinder.tinterval,opinfer.snapshots)
    snaps = opinfer.snapshots[:,1:end-1]
    opinfer.operator = optimize(snaps,vel,opt)
end