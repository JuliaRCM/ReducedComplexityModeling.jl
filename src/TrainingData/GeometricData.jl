#----------------------------------------------------------------------------------
# Single solution

function Base.Array(sol::DataSeries)
    n1 = length(sol)
    n2 = length(sol[1])
    Z = zeros(n1,n2)
    for (i,elem) in enumerate(sol) 
        Z[i,:] .= elem
    end 
    Array(Z')
end 

struct GeometricIntegratorData <: TrainingData
    solution::GeometricSolution
    snapshot::Matrix
    
    function GeometricIntegratorData(solution::GeometricSolution)
        new(solution,Array(solution.q))
    end 

    # function GeometricIntegratorData(solution::ODESolution)
    #     new(solution,Array(solution))
    # end 
end

#-----------------------------------------------------------------------------------
# Ensemble solutions

abstract type AbstractDependence end

struct Dependent <: AbstractDependence end 

struct Independent <: AbstractDependence end 


function Base.Array(solutions::Vector{GeometricSolution},::Dependent)
    ns = length(solutions)
    nx = length(solutions[1].q)
    ny = length(solutions[1].q[1])
    Z = zeros(eltype(solutions[1].q[1]),ns*nx,ny)
    
    i = 1
    for solution in solutions
        for ts in solution.q
            Z[i,:] .= ts
            i += 1 
        end 
    end     
    Array(Z')
end 

function Base.Array(solutions::Vector{GeometricSolution},::Independent)
    ns = length(solutions)
    nx = length(solutions[1].q)
    ny = length(solutions[1].q[1])
    Z = zeros(eltype(solutions[1].q[1]),nx,ny,ns)
    
    for (i,solution) in enumerate(solutions)   
        for (j,elem) in enumerate(solution.q)
            Z[j,:,i] .= elem
        end 
    end 
    Array(Z')
end 

struct GeometricIntegratorEnsembleData <: TrainingData
    solutions::Vector{GeometricSolution}
    snapshot::Array
    
    function GeometricIntegratorEnsembleData(solutions::Vector{GeometricSolution},deps::AbstractDependence)
        new(solutions,Array(solutions,deps))
    end 

    # function GeometricIntegratorEnsembleData(solutions::Vector{ODESolution},deps::AbstractDependence)

    # end 
end
#----------------------------------------------------------------------------------