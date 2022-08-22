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
    solution::Union{SolutionODE,ODESolution}
    snapshot::Matrix
    
    function GeometricIntegratorData(solution::SolutionODE)
        new(solution,Array(solution.q))
    end 

    function GeometricIntegratorData(solution::ODESolution)
        new(solution,Array(solution))
    end 
end

#-----------------------------------------------------------------------------------
# Ensemble solutions

abstract type AbstractDepenedence end

struct Dependent <: AbstractDepenedence end 

struct Independent <: AbstractDepenedence end 


function Base.Array(solutions::Vector{SolutionODE},::Dependent)
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

function Base.Array(solutions::Vector{SolutionODE},::Independent)
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
    solutions::Vector{Union{SolutionODE,ODESolution}}
    snapshot::Array
    
    function GeometricIntegratorEnsembleData(solutions::Vector{SolutionODE},deps::AbstractDepenedence)
        new(solutions,Array(solutions,deps))
    end 

    function GeometricIntegratorEnsembleData(solutions::Vector{ODESolution},deps::AbstractDepenedence)

    end 
end
#----------------------------------------------------------------------------------