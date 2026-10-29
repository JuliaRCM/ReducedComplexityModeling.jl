#----------------------------------------------------------------------------------
# Single solution

function snapshot_matrix(sol::DataSeries)
    n1 = length(sol)
    n2 = length(sol[1])
    Z = zeros(n1, n2)
    for (i, elem) in enumerate(sol)
        Z[i, :] .= elem
    end
    Array(Z')
end

"""
    GeometricIntegratorData(solution::GeometricSolution)

The solution of a geometric integrator and its snapshot matrix: the field `snapshot` is a matrix
with one row per component of the state `q` and one column per entry of `solution.q`, the
initial state included.
"""
struct GeometricIntegratorData
    solution::GeometricSolution
    snapshot::Matrix

    function GeometricIntegratorData(solution::GeometricSolution)
        new(solution, snapshot_matrix(solution.q))
    end

    # function GeometricIntegratorData(solution::ODESolution)
    #     new(solution,Array(solution))
    # end 
end

#-----------------------------------------------------------------------------------
# Ensemble solutions

abstract type AbstractDependence end

"""
    Dependent()

The layout of the snapshot of a [`GeometricIntegratorEnsembleData`](@ref) in which the solutions
form one snapshot matrix: one row per component of the state `q`, and the entries of `q` of the
first solution, then those of the second, and so on, as its columns.
"""
struct Dependent <: AbstractDependence end

"""
    Independent()

The layout of the snapshot of a [`GeometricIntegratorEnsembleData`](@ref) in which each solution
keeps its own snapshot, along a third dimension. This layout is not implemented:
`GeometricIntegratorEnsembleData(solutions, Independent())` throws an `ErrorException`, because
the snapshot array has three dimensions and `adjoint` is not defined for it.
"""
struct Independent <: AbstractDependence end

function Base.Array(solutions::Vector{GeometricSolution}, ::Dependent)
    ns = length(solutions)
    nx = length(solutions[1].q)
    ny = length(solutions[1].q[1])
    Z = zeros(eltype(solutions[1].q[1]), ns*nx, ny)

    i = 1
    for solution in solutions
        for ts in solution.q
            Z[i, :] .= ts
            i += 1
        end
    end
    Array(Z')
end

function Base.Array(solutions::Vector{GeometricSolution}, ::Independent)
    ns = length(solutions)
    nx = length(solutions[1].q)
    ny = length(solutions[1].q[1])
    Z = zeros(eltype(solutions[1].q[1]), nx, ny, ns)

    for (i, solution) in enumerate(solutions)
        for (j, elem) in enumerate(solution.q)
            Z[j, :, i] .= elem
        end
    end
    Array(Z')
end

"""
    GeometricIntegratorEnsembleData(solutions::Vector{GeometricSolution}, deps)

The solutions of an ensemble of geometric integrations and their snapshot, in the layout that
`deps` selects: [`Dependent`](@ref) or [`Independent`](@ref). The element type of `solutions` is
`GeometricSolution` itself; a vector with a concrete element type throws a `MethodError`.
"""
struct GeometricIntegratorEnsembleData
    solutions::Vector{GeometricSolution}
    snapshot::Array

    function GeometricIntegratorEnsembleData(solutions::Vector{GeometricSolution}, deps::AbstractDependence)
        new(solutions, Array(solutions, deps))
    end

    # function GeometricIntegratorEnsembleData(solutions::Vector{ODESolution},deps::AbstractDependence)

    # end 
end
#----------------------------------------------------------------------------------
