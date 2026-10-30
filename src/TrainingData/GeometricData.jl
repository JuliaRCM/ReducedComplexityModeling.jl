#----------------------------------------------------------------------------------
# Single solution

function snapshot_matrix(sol::DataSeries)
    n1 = length(sol)
    n2 = length(first(sol))
    Z = zeros(eltype(first(sol)), n1, n2)
    for (i, elem) in enumerate(sol)
        Z[i, :] .= elem
    end
    permutedims(Z)
end

"""
    GeometricIntegratorData(solution::GeometricSolution)

The solution of a geometric integrator and its snapshot matrix: the field `snapshot` is a matrix
with one row per component of the state `q` and one column per entry of `solution.q`, the
initial state included.
"""
struct GeometricIntegratorData{ST <: GeometricSolution, T}
    solution::ST
    snapshot::Matrix{T}

    function GeometricIntegratorData(solution::ST) where {ST <: GeometricSolution}
        snapshot = snapshot_matrix(solution.q)
        new{ST, eltype(snapshot)}(solution, snapshot)
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
different numbers of entries in `q`, but all must have the same number of components of `q`;
otherwise the constructor throws an `ArgumentError`.
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
    mapreduce(solution -> eltype(first(solution.q)), promote_type, solutions)
end

function Base.Array(solutions::AbstractVector{<:GeometricSolution}, ::Dependent)
    nx = sum(solution -> length(solution.q), solutions)
    ny = length(first(first(solutions).q))
    all(solution -> length(first(solution.q)) == ny, solutions) ||
        throw(ArgumentError("the Dependent layout needs solutions with equal state dimensions"))
    Z = zeros(_snapshot_eltype(solutions), nx, ny)

    i = 1
    for solution in solutions
        for ts in solution.q
            Z[i, :] .= ts
            i += 1
        end
    end
    permutedims(Z)
end

function Base.Array(solutions::AbstractVector{<:GeometricSolution}, ::Independent)
    ns = length(solutions)
    nx = length(first(solutions).q)
    ny = length(first(first(solutions).q))
    all(solution -> length(solution.q) == nx, solutions) ||
        throw(ArgumentError("the Independent layout needs solutions with equal numbers of entries"))
    all(solution -> length(first(solution.q)) == ny, solutions) ||
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
struct GeometricIntegratorEnsembleData{ST <: GeometricSolution, T, N}
    solutions::Vector{ST}
    snapshot::Array{T, N}

    function GeometricIntegratorEnsembleData(
            solutions::AbstractVector{S},
            deps::AbstractDependence
    ) where {S <: GeometricSolution}
        stored = collect(solutions)
        snapshot = Array(solutions, deps)
        new{S, eltype(snapshot), ndims(snapshot)}(stored, snapshot)
    end

    # function GeometricIntegratorEnsembleData(solutions::Vector{ODESolution},deps::AbstractDependence)

    # end 
end
#----------------------------------------------------------------------------------
