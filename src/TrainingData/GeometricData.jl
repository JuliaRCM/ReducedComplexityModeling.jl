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
first solution, then those of the second, and so on, as its columns. The solutions may have
different numbers of entries in `q`.
"""
struct Dependent <: AbstractDependence end

"""
    Independent()

The layout of the snapshot of a [`GeometricIntegratorEnsembleData`](@ref) in which each solution
keeps its own snapshot, along a third dimension: an array of size `ny × nx × ns`, for `ns`
solutions with `nx` entries of a state `q` with `ny` components. Its slice `[:, :, i]` is the
snapshot matrix of solution `i`, in the layout of [`GeometricIntegratorData`](@ref). All
solutions must have the same number of entries in `q` and the same number of components of `q`;
otherwise the constructor throws an `ArgumentError`.
"""
struct Independent <: AbstractDependence end

# the element type that holds the state `q` of every solution without loss
function _snapshot_eltype(solutions)
    mapreduce(solution -> eltype(solution.q[1]), promote_type, solutions)
end

function Base.Array(solutions::AbstractVector{<:GeometricSolution}, ::Dependent)
    nx = sum(solution -> length(solution.q), solutions)
    ny = length(solutions[1].q[1])
    Z = zeros(_snapshot_eltype(solutions), nx, ny)

    i = 1
    for solution in solutions
        for ts in solution.q
            Z[i, :] .= ts
            i += 1
        end
    end
    Array(Z')
end

function Base.Array(solutions::AbstractVector{<:GeometricSolution}, ::Independent)
    ns = length(solutions)
    nx = length(solutions[1].q)
    ny = length(solutions[1].q[1])
    all(solution -> length(solution.q) == nx, solutions) ||
        throw(ArgumentError("the Independent layout needs solutions with equal numbers of entries"))
    all(solution -> length(solution.q[1]) == ny, solutions) ||
        throw(ArgumentError("the Independent layout needs solutions with equal state dimensions"))
    Z = zeros(_snapshot_eltype(solutions), nx, ny, ns)

    for (i, solution) in enumerate(solutions)
        for (j, elem) in enumerate(solution.q)
            Z[j, :, i] .= elem
        end
    end
    permutedims(Z, (2, 1, 3))
end

"""
    GeometricIntegratorEnsembleData(solutions::AbstractVector{<:GeometricSolution}, deps)

The solutions of an ensemble of geometric integrations and their snapshot, in the layout that
`deps` selects: [`Dependent`](@ref) or [`Independent`](@ref). The element type of the snapshot
is the promotion of the element types of the states `q` of all solutions.
"""
struct GeometricIntegratorEnsembleData
    solutions::Vector{GeometricSolution}
    snapshot::Array

    function GeometricIntegratorEnsembleData(
            solutions::AbstractVector{<:GeometricSolution}, deps::AbstractDependence)
        new(solutions, Array(solutions, deps))
    end

    # function GeometricIntegratorEnsembleData(solutions::Vector{ODESolution},deps::AbstractDependence)

    # end 
end
#----------------------------------------------------------------------------------
