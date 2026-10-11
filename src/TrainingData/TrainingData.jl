"""
    ObservableSpace

The space of the recorded variables: what a measurement, a simulation or a file produced.
"""
abstract type ObservableSpace end

"""
    IntrinsicSpace

The space in which the structure of the system is manifest.

`IntrinsicSpace` marks *structure*, not size. A system may be canonically Hamiltonian while its
observables are not canonically conjugate variables, and the intrinsic coordinates are then
reached by a coordinate transformation or a learned map at the *same* dimension as the
observables; dimension reduction is only one way to reach them, so a reduced basis and a
canonicalising transformation are both maps `ObservableSpace → IntrinsicSpace`.

The map itself is not part of this type. It stays with the model that produced the data, for
example the `project` and `lift` of a reduced basis or the transformation of a
symbolic-regression method, so that each map has one owner. A package adds a subtype of
`IntrinsicSpace` to name its own kind of map.
"""
abstract type IntrinsicSpace end

# The data type and the system type of a `TrainingData` must be concrete, so that
# `state_symbols` does not construct a system the caller did not mean.
function check_axes(DT, SY)
    isconcretetype(DT) || throw(ArgumentError(
        "the data type $DT of a TrainingData must be a concrete type, " *
        "such as StateData or VectorFieldData"))
    isconcretetype(SY) || throw(ArgumentError(
        "the system type $SY of a TrainingData must be a concrete type, " *
        "such as CanonicalHamiltonianSystem or RegularLagrangianSystem"))
    return nothing
end

"""
    TrainingData{SpaceType, DataType, SystemType}(time, data[, problem])
    TrainingData{SpaceType, DataType, SystemType}(solution::EnsembleSolution)

Training data on three orthogonal axes.

The type parameters are

- `SpaceType <: Union{ObservableSpace, IntrinsicSpace}`: [`ObservableSpace`](@ref) for recorded
  data or [`IntrinsicSpace`](@ref) for data in which the structure is manifest. A method that
  expects one must not silently accept the other, so the space is a type parameter and not a
  field;
- `DataType <: GeometricBase.AbstractDataType`: what was recorded, one of `ObservableData`,
  `StateData`, `VectorFieldData` and `TangentVectorData` of `GeometricBase`;
- `SystemType <: GeometricBase.AbstractSystem`: the structure of the system, one of the concrete
  systems of `GeometricBase`, such as `CanonicalHamiltonianSystem` or
  `RegularLagrangianSystem`.

`DataType` and `SystemType` are the axes that `GeometricBase` already carries: the pair dispatches
`state_symbols`, which returns the state variable names, e.g. `(:q, :p)` for `StateData` on a
`CanonicalHamiltonianSystem` and `(:z,)` on a noncanonical one. A `TrainingData` adds the space
axis and the data themselves; it redefines neither of the others.

`SystemType` is declared by the caller and not derived from a problem. The
`hashamiltonian`/`haslagrangian` traits of a `GeometricEquations` problem separate a Hamiltonian
problem from a Lagrangian one and nothing finer, and data need not come from a problem at all.

Every constructor gives the same layout: `time` is a vector and `data` an array with the time
along its *last* dimension, so `time` has `size(data, ndims(data))` entries, and a vector, a
matrix and a 3-array are all accepted. A shape that does not match throws a
`DimensionMismatch`. The first constructor is called with two or three arguments: with two it
sets `problem` to `nothing`, with three it stores the `problem` it is given. The second one
builds the array from the ensemble: `data[:, i, n]` holds the variables that `state_symbols`
names, e.g. `q` then `p` for `StateData` on a `CanonicalHamiltonianSystem`, of member `i` at the
`n`-th stored time, and `time` is the 1-based vector of the stored times. It stores
`solution.problem` itself, not a copy, and throws an `ArgumentError` when `state_symbols` names
no variable or one that the solution does not have.

`DataType` and `SystemType` must be concrete; anything else throws an `ArgumentError`, rather
than letting `state_symbols` construct a system the caller did not mean.
"""
struct TrainingData{
    ST <: Union{ObservableSpace, IntrinsicSpace},
    DT <: AbstractDataType,
    SY <: AbstractSystem,
    TT, AT, PT}
    time::TT
    data::AT
    problem::PT

    function TrainingData{ST, DT, SY}(time::TT, data::AT,
            problem::PT) where {
            ST, DT, SY, TT <: AbstractVector, AT <: AbstractArray, PT}
        check_axes(DT, SY)
        ndims(data) > 0 || throw(DimensionMismatch("the data must have a time dimension"))
        size(data, ndims(data)) == length(time) || throw(DimensionMismatch(
            "the last dimension of the data has $(size(data, ndims(data))) entries, " *
            "but there are $(length(time)) times"))
        new{ST, DT, SY, TT, AT, PT}(time, data, problem)
    end
end

function TrainingData{ST, DT, SY}(time::AbstractVector, data::AbstractArray) where {
        ST, DT, SY}
    TrainingData{ST, DT, SY}(time, data, nothing)
end

function TrainingData{ST, DT, SY}(sol::EnsembleSolution) where {ST, DT, SY}
    check_axes(DT, SY)
    variables = state_symbols(DT(), SY())
    (!isempty(variables) && all(in(keys(sol)), variables)) || throw(ArgumentError(
        "a solution with the variables $(keys(sol)) cannot be read as $DT on $SY, " *
        "whose variables are $variables"))
    member(s) = vcat((Array(s[k]) for k in variables)...)
    time = vec(Array(sol[begin].t))
    TrainingData{ST, DT, SY}(time, stack(member, sol; dims = 2), sol.problem)
end

# The pair `DataType`/`SystemType` dispatches `state_symbols` of `GeometricBase`, so a
# `TrainingData` answers with the state variable names of the system it declares.
state_symbols(td::TrainingData{ST, DT, SY}) where {ST, DT, SY} = state_symbols(DT(), SY())

# The member problems of the ensemble the data were built from. A `TrainingData` without a
# problem reaches `problem(::Nothing, i)`, which has no method.
GeometricEquations.problem(td::TrainingData, i) = problem(td.problem, i)

include("GeometricData.jl")
