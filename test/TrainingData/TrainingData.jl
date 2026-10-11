using GeometricBase
using GeometricIntegrators
using Random
using ReducedComplexityModeling
using Test

const RCM = ReducedComplexityModeling

# The `src/` directory of the package, for the source-level declaration check below.
const SRC = dirname(pathof(RCM))

# A function barrier with concrete arguments, for the allocation assertion: the first call warms
# the method and the second is measured.
allocations(f::F, x::X) where {F, X} = (f(x); @allocated f(x))

# Every `abstract type` name declared at the top level of a `.jl` file under `dir`, a docstring
# unwrapped. Julia replaces a type by a later definition of the same name, so an `abstract type
# TrainingData end` left beside the struct is invisible at run time; only the source shows it.
function abstract_declarations(dir)
    names = Set{Symbol}()
    for (root, _, files) in walkdir(dir)
        for file in files
            endswith(file, ".jl") || continue
            for ex in Meta.parseall(read(joinpath(root, file), String)).args
                abstract_declarations!(names, ex)
            end
        end
    end
    return names
end

function abstract_declarations!(names, ex)
    ex isa Expr || return names
    if ex.head === :abstract
        name = ex.args[1]
        push!(names, name isa Symbol ? name : name.args[1])
    elseif ex.head === :macrocall
        abstract_declarations!(names, ex.args[end])
    end
    return names
end

# The Hamiltonian ODE q̇ = p, ṗ = −β²q, with H = (p² + β²q²)/2.
hode_vectorfield!(v, t, q, p, params) = (v .= p)
hode_force!(f, t, q, p, params) = (f .= -params.β^2 .* q)
hode_hamiltonian(t, q, p, params) = sum(abs2, p) / 2 + params.β^2 * sum(abs2, q) / 2

const BETAS = (5.95, 6.05)

"An `HODEEnsemble` in `T`, with one member per β in `BETAS`."
function hode_ensemble(::Type{T}) where {T}
    ics = [(q = T[1, 1 / 2], p = T[0, -1 / 2]) for _ in BETAS]
    params = [(β = T(β),) for β in BETAS]
    HODEEnsemble(hode_vectorfield!, hode_force!, hode_hamiltonian, (zero(T), T(1) / T(10)),
        T(1) / T(10), ics; parameters = params)
end

# The Hamiltonian of member `i`, through the parameter-bound `h` of the member problem.
function hamiltonian_at(td, i, t, q, p)
    prob = problem(td, i)
    return functions(equation(prob), parameters(prob)).h(t, q, p)
end

# A space of a caller's own, to show that a subtype of `IntrinsicSpace` passes the guard.
abstract type LocalSpace <: RCM.IntrinsicSpace end

# Defined for intrinsic data only, so that `ObservableSpace` data reaches no method.
intrinsic_only(td::RCM.TrainingData{<:RCM.IntrinsicSpace}) = :intrinsic

@testset "TrainingData" begin
    for T in (Float32, Float64)
        @testset "$T" begin
            ens = hode_ensemble(T)
            sol = EnsembleSolution(ens)
            td = RCM.TrainingData{
                RCM.ObservableSpace, StateData, CanonicalHamiltonianSystem}(sol)

            time = T[0, 1 / 10, 2 / 10]
            X = T[1 3 5; 2 4 6]
            td_plain = RCM.TrainingData{
                RCM.ObservableSpace, StateData, CanonicalHamiltonianSystem}(time, X)

            @testset "the Hamiltonian reads back for each member" begin
                @test td.problem === ens
                @test parameters(problem(td, 2)) == (β = T(BETAS[2]),)
                @test parameters(problem(td, Int32(2))) == (β = T(BETAS[2]),)

                rng = Xoshiro(42)
                t = rand(rng, T)
                q = rand(rng, T, 2)
                p = rand(rng, T, 2)
                h1 = hamiltonian_at(td, 1, t, q, p)
                h2 = hamiltonian_at(td, 2, t, q, p)

                @test h1 == hode_hamiltonian(t, q, p, (β = T(BETAS[1]),))
                @test h2 == hode_hamiltonian(t, q, p, (β = T(BETAS[2]),))
                @test h1 ≠ h2
                @test hamiltonian_at(td, Int32(2), t, q, p) == h2
            end

            @testset "SpaceType dispatches" begin
                td_intrinsic = RCM.TrainingData{
                    RCM.IntrinsicSpace, StateData, CanonicalHamiltonianSystem}(time, X)
                td_local = RCM.TrainingData{
                    LocalSpace, StateData, CanonicalHamiltonianSystem}(time, X)

                @test intrinsic_only(td_intrinsic) === :intrinsic
                @test intrinsic_only(td_local) === :intrinsic
                @test_throws MethodError intrinsic_only(td_plain)
            end

            @testset "DataType and SystemType dispatch through state_symbols" begin
                @test RCM.AbstractDataType === GeometricBase.AbstractDataType
                @test RCM.AbstractSystem === GeometricBase.AbstractSystem

                canonical = RCM.TrainingData{
                    RCM.ObservableSpace, StateData, CanonicalHamiltonianSystem}(time, X)
                noncanonical = RCM.TrainingData{
                    RCM.ObservableSpace, StateData, NoncanonicalHamiltonianSystem}(time, X)
                lagrangian = RCM.TrainingData{
                    RCM.ObservableSpace, StateData, RegularLagrangianSystem}(time, X)

                @test state_symbols(canonical) == (:q, :p)
                @test state_symbols(noncanonical) == (:z,)
                @test state_symbols(lagrangian) == (:q, :q̇)

                # the DataType axis dispatches on its own, at a fixed system
                observable = RCM.TrainingData{
                    RCM.ObservableSpace, ObservableData, CanonicalHamiltonianSystem}(
                    time, X)
                vectorfield = RCM.TrainingData{
                    RCM.ObservableSpace, VectorFieldData, CanonicalHamiltonianSystem}(
                    time, X)
                tangent = RCM.TrainingData{
                    RCM.ObservableSpace, TangentVectorData, CanonicalHamiltonianSystem}(
                    time, X)

                @test state_symbols(observable) == ()
                @test state_symbols(vectorfield) == (:q̇, :ṗ)
                @test state_symbols(tangent) == (:q, :p, :q̇, :ṗ)

                # the accessor is inferred and allocation-free on a warm call
                @test (@inferred state_symbols(canonical)) == (:q, :p)
                @test (@inferred state_symbols(noncanonical)) == (:z,)
                @test (@inferred state_symbols(lagrangian)) == (:q, :q̇)
                @test allocations(state_symbols, canonical) == 0
                @test allocations(state_symbols, noncanonical) == 0
                @test allocations(state_symbols, lagrangian) == 0
                @test allocations(collect, T[1, 2]) > 0
            end

            @testset "concrete fields, an optional problem, one binding" begin
                @test all(isconcretetype, fieldtypes(typeof(td)))
                @test all(isconcretetype, fieldtypes(typeof(td_plain)))
                @test td_plain.problem === nothing
                @test !isabstracttype(RCM.TrainingData)
                @test :TrainingData ∉ abstract_declarations(SRC)

                @test_throws ArgumentError RCM.TrainingData{
                    RCM.ObservableSpace, StateData, HamiltonianSystem}(time, X)
                @test_throws ArgumentError RCM.TrainingData{
                    RCM.ObservableSpace, GeometricBase.AbstractDataType,
                    CanonicalHamiltonianSystem}(time, X)
                @test_throws ArgumentError RCM.TrainingData{
                    RCM.AbstractSolutionSpace, StateData, CanonicalHamiltonianSystem}(
                    time, X)
            end

            @testset "the time axis is the last dimension of the data" begin
                time20 = collect(range(zero(T); step = T(1) / T(10), length = 20))
                @test_throws MethodError problem(td_plain, 1)
                @test_throws DimensionMismatch RCM.TrainingData{
                    RCM.ObservableSpace, StateData, CanonicalHamiltonianSystem}(
                    time20, zeros(T, 2, 21))
                @test_throws DimensionMismatch RCM.TrainingData{
                    RCM.ObservableSpace, StateData, CanonicalHamiltonianSystem}(
                    time20, zeros(T, 2, 20, 3))

                td3 = RCM.TrainingData{
                    RCM.ObservableSpace, StateData, CanonicalHamiltonianSystem}(
                    time20, zeros(T, 2, 3, 20))
                @test size(td3.data) == (2, 3, 20)
                @test length(td3.time) == 20
            end
        end
    end
end
