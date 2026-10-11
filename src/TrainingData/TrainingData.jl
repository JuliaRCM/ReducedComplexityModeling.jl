"""
    AbstractSolutionSpace

Supertype of the spaces in which training data are recorded.

A `TrainingData` is tagged with the space its values live in. There are two: what was measured,
[`ObservableSpace`](@ref), and the space in which the structure of the system is manifest,
[`IntrinsicSpace`](@ref). A method that expects one must not silently accept the other, so the
tag is a type parameter and not a field.
"""
abstract type AbstractSolutionSpace end

"""
    ObservableSpace <: AbstractSolutionSpace

The space of the recorded variables: what a measurement, a simulation or a file produced.
"""
abstract type ObservableSpace <: AbstractSolutionSpace end

"""
    IntrinsicSpace <: AbstractSolutionSpace

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
abstract type IntrinsicSpace <: AbstractSolutionSpace end

"""
    TrainingData{SpaceType, DataType, SystemType}(time, data[, problem])
    TrainingData{SpaceType, DataType, SystemType}(solution::EnsembleSolution)

Training data on three orthogonal axes.

The type parameters are

- `SpaceType <: AbstractSolutionSpace`: [`ObservableSpace`](@ref) for recorded data or
  [`IntrinsicSpace`](@ref) for data in which the structure is manifest;
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

The second constructor stores `solution.t`, `solution.s` and `solution.problem` itself, not a
copy of the problem. The first one is called with two or three arguments: with two it takes the
time along the *last* dimension of `data` and sets `problem` to `nothing`, so `time` must have
`size(data, ndims(data))` entries and a vector, a matrix and a 3-array are all accepted; with
three it stores the `problem` it is given and checks no shape.

`DataType` and `SystemType` must be concrete, and `SpaceType` must be a subtype of
`ObservableSpace` or of `IntrinsicSpace`; anything else throws an `ArgumentError`, rather than
letting `state_symbols` construct a system the caller did not mean.
"""
struct TrainingData{
    ST <: AbstractSolutionSpace,
    DT <: AbstractDataType,
    SY <: AbstractSystem,
    TT, AT, PT}
    time::TT
    data::AT
    problem::PT

    function TrainingData{ST, DT, SY}(time::TT, data::AT, problem::PT) where {
            ST, DT, SY, TT, AT, PT}
        isconcretetype(DT) || throw(ArgumentError(
            "the data type $DT of a TrainingData must be a concrete type, " *
            "such as StateData or VectorFieldData"))
        isconcretetype(SY) || throw(ArgumentError(
            "the system type $SY of a TrainingData must be a concrete type, " *
            "such as CanonicalHamiltonianSystem or RegularLagrangianSystem"))
        (ST !== Union{} && (ST <: ObservableSpace || ST <: IntrinsicSpace)) ||
            throw(ArgumentError(
                "the space type $ST of a TrainingData must be a subtype of " *
                "ObservableSpace or of IntrinsicSpace"))
        new{ST, DT, SY, TT, AT, PT}(time, data, problem)
    end
end

function TrainingData{ST, DT, SY}(time::AbstractVector, data::AbstractArray) where {
        ST, DT, SY}
    ndims(data) > 0 || throw(DimensionMismatch("the data must have a time dimension"))
    size(data, ndims(data)) == length(time) || throw(DimensionMismatch(
        "the last dimension of the data has $(size(data, ndims(data))) entries, " *
        "but there are $(length(time)) times"))
    TrainingData{ST, DT, SY}(time, data, nothing)
end

function TrainingData{ST, DT, SY}(sol::EnsembleSolution) where {ST, DT, SY}
    TrainingData{ST, DT, SY}(sol.t, sol.s, sol.problem)
end

# The pair `DataType`/`SystemType` dispatches `state_symbols` of `GeometricBase`, so a
# `TrainingData` answers with the state variable names of the system it declares.
state_symbols(td::TrainingData{ST, DT, SY}) where {ST, DT, SY} = state_symbols(DT(), SY())

# The member problems of the ensemble the data were built from. A `TrainingData` without a
# problem reaches `problem(::Nothing, i)`, which has no method.
GeometricEquations.problem(td::TrainingData, i) = problem(td.problem, i)

include("GeometricData.jl")
