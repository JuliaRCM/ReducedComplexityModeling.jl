abstract type AbstractOperatorInference end

abstract type Lineartiy end
struct Linear <: Lineartiy end 
struct Quadratic <: Lineartiy end

abstract type AbstractOptimizer end
struct LSTSQ <: AbstractOptimizer end
struct Newton <: AbstractOptimizer end

struct PlainOperatorInference <: AbstractOperatorInference
    snapshots
    linearity
    operator

    function PlainOperatorInference(snapshots)
        new(snapshots,Linear())
    end 

    function PlainOperatorInference(snapshots,linearity)
        new(snapshots,linearity)
    end 
end 

function gradient(snapshots)

end 

function optimize!(snaps,vel,::LSTSQ)
    # Conventional inference using Least squares
    # Ax = b
    # xTAT=bT
    # AT = bT \ xT
    A = transpose(vel)\transpose(snaps)
    tranpose(A)
end 

# Is usually very expensive
function optimize!(snaps,vel,::Netwon)
    
end 

function infer!(opinfer::PlainOperatorInference{Any,::Linear},opt::AbstractOptimizer)
    vel = gradient(opinfer.snapshots)
    snaps = opinfer.snapshots
    opinfer.operator = optimize!(snaps,vel,opt)
end 

function kron(v::Vector) 
    n = length(vec)
    Z = zeros(n*n)
    k = 1
    for elem in vec
        for elem2 in vec
            X[k] = elem*elem2
            k = k + 1
        end 
    end 
    Z
end

function infer!(opinfer::PlainOperatorInference{Any,::Quadratic},opt::AbstractOptimizer)
    vel = gradient(opinfer.snapshots)
    snaps = opinfer.snapshots
    qsnaps = zeros(size(snaps,1)^2,size(snaps,2))
    for i=1:size(snaps,2)
        qsnaps[:,i] = kron(snaps[:,i])
    end 
    
    # A x + B (x⊗x) = v
    # 
end 