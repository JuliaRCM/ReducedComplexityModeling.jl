# Release Notes

All notable changes to ReducedComplexityModeling.jl.

This package is pre-1.0, so *every* minor release is potentially breaking in the sense of
[SemVer](https://semver.org) for `0.x` versions. The sections below name what actually
changed, so that a compat-only bump can be told apart from a rename or a change in results.

This file was started on 2026-08-31. 2 versions were released before it, the most recent
`v0.1.1`, and neither is written up here: the record of that history is `git log` and the
tags. It is named as a gap rather than reconstructed, because a changelog assembled after the
fact loses exactly the reasoning that makes it worth keeping. The `[Unreleased]` section below
holds the changes since the last release until that release is cut.

## [Unreleased]

### Breaking Changes

- `ReducedComplexityModeling` no longer exports `Array`. The binding is `Core`'s, and every module
  sees it without the export, so `Array` keeps its meaning in a caller's code; what changes is the
  export list that `names(ReducedComplexityModeling)` returns.

- `ReducedBasisModel` has type parameters for the reduction scheme, the element type of the basis
  and the type of the snapshot, and its three fields are concretely typed. They were `Any`. The
  constructor takes an `AbstractMatrix` snapshot: a `Vector` throws a `MethodError`. The basis has
  the floating-point type of the snapshot's element type, so a `Float32` snapshot gives a `Float32`
  basis, and an integer snapshot gives a `Float64` basis.

- `reduce!(model, k, CotangentLiftEVD())` takes the eigenvectors of the Gram matrix `q qᵀ + p pᵀ`.
  It took the left singular vectors of `[q p]` before. The two bases span the same space, and the
  columns can differ in sign and, for equal singular values, in order, so a result that compares
  the basis entry by entry changes.

### Bug Fixes

- `Parameter` takes a `Symbol` or a string name in every constructor form. The call
  `Parameter("μ", minimum, maximum, n)` returns a `Parameter` whose samples are those of
  `LinRange(minimum, maximum, n)` when the bounds differ, without duplicates. Equal bounds and a
  positive count give the one sample `minimum`. A count of 0 gives no sample. It threw a
  `MethodError` before, because two methods matched it equally well. This relates to issue #38:
  the two string-name methods that clashed are deleted, and
  `detect_ambiguities(ReducedComplexityModeling)` reports no ambiguity. A gap remains: unequal
  integer bounds with a sample count still throw a `MethodError`. Their `LinRange` has a float
  element type, so `Parameter(:a, 0, 10, 5)` throws.

- `GeometricIntegratorEnsembleData(solutions, Independent())` builds its snapshot (K16). It threw
  an `ErrorException` before. The snapshot is an array of size `ny × nx × ns`, for `ns` solutions
  with `nx` entries of a state `q` with `ny` components. Its slice `[:, :, i]` is the snapshot
  matrix of solution `i`, in the layout of `GeometricIntegratorData`. Solutions with different
  numbers of entries in `q` throw an `ArgumentError`. Solutions with different numbers of
  components of `q` also throw an `ArgumentError`.

- `GeometricIntegratorEnsembleData(solutions, Dependent())` sizes its snapshot from the total number
  of entries of all solutions. It was sized from the first solution alone: a later solution with
  fewer entries left zero-filled trailing columns, and one with more entries threw a `BoundsError`.
  The solutions may now have different numbers of entries in `q`. Solutions with different numbers
  of components of `q` throw an `ArgumentError` (K26). A solution with one component after one with
  two was copied into both rows without an error before. The snapshot of one solution and the
  `Dependent` snapshot change their layout with `permutedims`. `Array(Z')` conjugated complex
  values. No complex state reaches them today, because `integrate` does not take one.

- In both layouts, the snapshot of `GeometricIntegratorEnsembleData` has the `promote_type` of
  the element types of the states `q` of all solutions. A `Float32` solution followed by a
  `Float64` solution gives a `Float64` snapshot, so a value of `1e40`, which is above
  `floatmax(Float32)`, is kept. The order of the columns is unchanged.

- `GeometricIntegratorEnsembleData` and both `Base.Array(solutions, ::Dependent)` and
  `Base.Array(solutions, ::Independent)` take a vector with a concrete element type, such as
  `[sol, sol]`. `GeometricIntegratorEnsembleData([sol, sol], Dependent())` threw a `MethodError`
  before.

- `reduce!(model, k, CotangentLiftEVD())` (K17) and `reduce!(model, k, ComplexSVD())` (K18) no
  longer throw on every call. Each stores a `2n × 2k` basis in `model.reduced_basis`, orthonormal
  and symplectic (`AᵀJA = J`). Neither algorithm type is exported: a caller reaches them as
  `ReducedComplexityModeling.CotangentLiftEVD` and `ReducedComplexityModeling.ComplexSVD`.

- Help text: the module and every exported name have a docstring with text. `Parameter`,
  `ParameterSampler` and `CartesianParameterSampler` replace their empty docstrings, and `POD`,
  `reduce!`, `compose`, `project`, `hassamples`, `GeometricIntegratorData`,
  `GeometricIntegratorEnsembleData`, `Dependent` and `Independent` gain one. The exports test
  requires the docstring of every exported or public name to contain that name. The docstrings of
  `h5save` and `h5load` name their three methods and their arguments (K21). Each shows a round
  trip, as a doctest. `h5save` writes a `ParameterSpace`, and `h5load` reads it back.
  `h5save(file, p)` writes a `Parameter` `p` to the group of its name.
  `h5load(Parameter, file; path = string(p.name))` reads it back. With the default
  `path = "/"`, `h5load(Parameter, file)` throws a `KeyError`. The docstring of
  `ReducedBasisModel` no longer names packages that are not dependencies of this package.

- `reduce!` takes a `k` above the columns of the thin SVD (K22), for `POD()` and for
  `CotangentLiftSVD()`, `CotangentLiftEVD()` and `ComplexSVD()`, the last three with any `k ≤ n`.
  It threw a `BoundsError`; the basis is completed with orthonormal vectors now, and stays
  symplectic. The basis of the three symplectic algorithms has the floating-point type of the
  snapshot's element type (K23). It was `Float64` for a `Float32` snapshot, and `compose` then
  promoted the reduced problem to `Float64`. The snapshot of one solution, `GeometricIntegratorData`,
  has the element type of the solution too. It was `Float64` always.

- `GeometricIntegratorEnsembleData` takes an offset-indexed vector of solutions (K24), and the
  snapshot functions read a solution that holds only its initial entry (K25). A `step` larger than
  the number of time steps stores the initial state alone, and `snapshot_matrix` threw a
  `BoundsError` for it.

### New Features

- `reduce!(model, k, CotangentLiftSVD())` stores the cotangent lift of the first `k` left singular
  vectors of `[q p]`. The algorithm type is not exported.
- `scripts/pod_lorenz.jl` draws the Lorenz solution, the reduced solution and its projection with
  CairoMakie, into the directory of `--results-dir`. It has its own environment in `scripts/`. The
  original solution uses `LorenzAttractor.plot_phase_portrait` of GeometricProblems 0.10.

### Changed

- The tests no longer plot. `test/integration/pod_lorenz.jl` builds its problem with
  `LorenzAttractor.odeproblem` of GeometricProblems, in place of a local copy, and
  `test/helpers/problems.jl` is deleted: its other two functions were empty. `Plots` leaves the
  test environment, `OffsetArrays` joins it, and the test compat of GeometricProblems is `0.10`.

## [0.4.1] — 2026-10-29

### Changed

- Ten names are declared `public`: `number_of_batches`, `accuracy`, `assign_output_estimate`,
  `convert_input_and_batch_indices_to_array`, `data_tensors_from_geometric_solution`, `map_to_type`,
  `map_to_new_backend`, `save_parameters`, `read_parameters` and `_create_group`. These are the names
  that GeometricMachineLearning and ReducedBasisMethods import or call. They were neither exported
  nor `public` before, so a check that every import of those packages is `public`
  (ExplicitImports' `check_all_explicit_imports_are_public`) reports them. Nothing is exported and
  no function changes behaviour. `ParametricDataLoader` was already `public`. `_create_group` keeps
  its underscore name; it is declared `public` but not renamed.
- `data_tensors_from_geometric_solution`, `map_to_type`, `map_to_new_backend` and `_create_group`
  gain docstrings. `save_parameters` and `read_parameters` replace their placeholder docstrings
  with real ones.

## [0.4.0] — 2026-10-28

### Breaking Changes

- **The data loader is this package's now: its code arrives from GeometricMachineLearning.**
  `src/data_loader/data_loader.jl`, `src/data_loader/batch.jl`,
  `src/data_loader/tensor_assign.jl` and `src/data_loader/parametric_data_loader.jl` are
  GeometricMachineLearning's files of those names, moved here, with the testsets that exercise
  them; GeometricMachineLearning removes its copies of all four. This package's own
  `data_loader.jl`, `batch.jl`, `tensor_assign.jl` and
  `test/data_loader/draw_batch_for_tensor_test.jl` give way to them.
  `src/data_loader/matrix_assign.jl` and `src/data_loader/mnist_utils.jl` are
  deleted with no successor here: `matrix_assign.jl` held `draw_batch!` alone, and no code called
  it; MNIST data and the patch utilities are `GMLDatasets`'. `test/data_loader/mnist_utils.jl` is
  deleted with them. `Batch` is now exported next to `DataLoader`; `number_of_batches`,
  `assign_output_estimate`, `convert_input_and_batch_indices_to_array`, `batch_over_two_axes`,
  `accuracy` and `ParametricDataLoader` are unexported, and `ParametricDataLoader` is `public`: a
  caller writes `ReducedComplexityModeling.ParametricDataLoader`.
- **A matrix or a vector is a time series by default.** `DataLoader(::AbstractMatrix)` and
  `DataLoader(::AbstractVector)` default `autoencoder = false`, where the fork defaulted it to
  `true`: `DataLoader(data)` reads the second axis as the number of time steps, and a set of
  samples is `DataLoader(data; autoencoder = true)`. `DataLoader(solution)` takes `suppress_info`
  as a keyword, so `DataLoader(solution, true)` raises a `MethodError`.
- **`DataLoader(tensor, labels::AbstractVector)` is gone.** That method preprocessed images for
  MNIST, with `patch_length = 7`; patch the images and build the one-hot target with `GMLDatasets`
  first, then call `DataLoader(input, output)`, whose output may be an integer array for a tensor,
  a matrix or a vector input. The fork's pairs took one element type for both arguments, whatever
  the shape, so an integer output with a real input was a `MethodError` there.
- **A sample-count mismatch in `DataLoader(input, output)` throws `ArgumentError`.** The third axes
  of input and output must agree, and the message names both sizes. The fork's `@assert` threw
  `AssertionError`, so a caller that catches that type must catch `ArgumentError` now.
- `accuracy` returns `float(T)`, the element type of the loader's input, where the fork returned
  `Float64` whatever the loader held.
- `accuracy` counts one error per wrong label for an output of any integer type, unsigned ones
  included, and divides by every labelled column: the output's time steps times its parameter axis.
  A loader that `DataLoader(input, output)` builds from a matrix or a vector has one parameter
  axis entry and many time steps, so its accuracy is a fraction in `[0, 1]`.
- `accuracy(::NeuralNetwork, ::DataLoader)` works: `params` is imported from
  AbstractNeuralNetworks, which closes known issue K12. Known issues K2, K3 and K4 leave
  `KNOWN_ISSUES.md` with the code they described.
- `ChainRulesCore` leaves `[deps]` and `[compat]`: the fork's `rrule` for `assign_output_estimate`
  was its only use.
- `[compat]`: `AbstractNeuralNetworks` rises to `"0.9.1"`, `NeuralNetworkParameters` to `"0.5"`,
  `GeometricBase` narrows from `"0.14.6, 0.15"` to `"0.15"`, `GeometricEquations` rises from
  `"0.21"` to `"0.21.5"`, and `GeometricSolutions` from `"0.6"` to `"0.6.6"`.
  The moved code calls `networkbackend`, `params`, `NamedTupleOfArrays` and `ArrayOrNamedTuple`,
  which AbstractNeuralNetworks 0.9 defines, so an environment on an earlier
  AbstractNeuralNetworks no longer resolves this release. AbstractNeuralNetworks 0.9.0 caps
  `NeuralNetworkParameters` at 0.4, and 0.9.1 is the first to allow 0.5. `NeuralNetworkParameters`
  0.5 requires `GeometricBase` 0.15, and `GeometricEquations` 0.21.5 and `GeometricSolutions` 0.6.6
  are the first releases that accept `GeometricBase` 0.15, so the old floors could not be resolved
  alongside it. An environment on `GeometricBase` 0.14 therefore no longer resolves this release,
  where v0.3.1 allowed it.

## [0.3.1] — 2026-10-24

### Changed

- **Julia 1.12 is the floor** (`[compat] julia = "1.12"`, from 1.11). A patch release, because no
  API changes: a caller on Julia 1.11 can no longer install this version.
  The repository records no reason for the raise, and nothing in the package's code changes: it
  held no workaround that existed only for Julia 1.11.

## [0.3.0] — 2026-10-12

### Breaking Changes

- `[compat] AbstractNeuralNetworks` is `"0.8"` alone, and `julia` is `"1.11"`. AbstractNeuralNetworks
  0.8 requires Julia 1.11, so a Julia 1.10 environment no longer resolves this package; 0.2.0 is the
  last release that loads there. The bound is what makes the package installable beside
  `GeometricOptimizers` 0.7 or 0.8, both of which require AbstractNeuralNetworks 0.8, and therefore
  usable by `SparseIdentification`.
- `accuracy(::Chain, ps, ::DataLoader)` types `ps` as `NetworkParameters`, so a caller that passes
  anything else gets a `MethodError` at the call rather than a failure deeper in. `NeuralNetworkParameters`
  joins `[deps]`, because AbstractNeuralNetworks 0.7 moved the parameters type into that package and
  0.8 imports it without exporting it. That release also removed `QPT` and `QPTOAT`, which this
  package used only as dispatch annotations in the data-loader fork, so it now defines both itself,
  copied from AbstractNeuralNetworks 0.6.4, and imports only `Chain` and `NeuralNetwork`. No data
  format, result or public name changes.

## [0.2.0] — 2026-10-11

### New Features

- Two new parameter samplers for use with `ParameterSpace`. `RandomParameterSampler(n, rng =
  Random.default_rng())` draws uniform samples from each parameter's `[minimum, maximum]`
  interval; with a seeded `rng`, the sequence is reproducible.
  `QuasiRandomParameterSampler(n)` generates the first `n` points of a Halton sequence (the
  `j`-th parameter uses the `j`-th prime as its base, starting from index 1), scaled to the
  parameter box. Both subtype `ParameterSampler`, ignore any stored samples, and work with
  `sample` and the `ParameterSpace(sampler, params...)` constructor.

- HDF5 groups created by `save_parameters`, `h5save(::Parameter)`, and `h5save(::ParameterSpace)`
  now track link creation order, so keys are preserved in the order written. Previously, keys were
  reordered alphabetically when read back. A file written before this change reads with keys in
  alphabetical order. A group that exists before the write and does not track creation order,
  such as the file root in `save_parameters(h5, params; path = "/")`, keeps the alphabetical
  order. The `HDF5` compat bound rises to `0.16.11, 0.17`, because 0.16.11 is the first HDF5.jl
  release where `keys(group)` returns a group's creation order.

- Training data and training problems are first class. `TrainingData{SpaceType, DataType,
  SystemType}(time, data[, problem])` tags data with three orthogonal axes: the space
  (`ObservableSpace` or `IntrinsicSpace`), what was recorded (`DataType`, one of GeometricBase's
  `ObservableData`, `StateData`, `VectorFieldData` and `TangentVectorData`) and the structure of the
  system (`SystemType`, one of GeometricBase's concrete systems, such as
  `CanonicalHamiltonianSystem`). The last two dispatch `state_symbols`, which returns `(:q, :p)` for
  state data on a canonical Hamiltonian system and `(:z,)` on a noncanonical one, so a method that
  expects one kind of data no longer accepts another in silence. A shape mismatch between `time` and
  `data` throws a `DimensionMismatch`. The ensemble constructor, `TrainingData{SpaceType, DataType,
  SystemType}(solution::EnsembleSolution)`, builds `data` from the variables that `state_symbols`
  names, and `time` from the stored times. `TrainingProblem(data, residual, parameters)` holds the
  data, a residual `residual(data, θ::NamedTuple)` and a `ParameterSpace`, and
  `train(problem, method::Optim.FirstOrderOptimizer)` fits the parameters by minimising the squared
  residual, starting from the sample whose loss is finite and smallest. The samples are starting
  points and not bounds, and `train` returns the fitted parameters as a `NamedTuple` of the samples'
  element type. Its stopping test is relative to the gradient at the start, so it converges on noisy
  data, where the loss does not vanish at the minimiser; it throws when Optim reports that it did not
  converge. `train!` is the in-place companion of `train` and defines no method here. The exported
  names are `ObservableSpace`, `IntrinsicSpace`, `TrainingData`, `TrainingProblem`, `train` and
  `train!`. This adds `GeometricBase` to the dependencies with the
  compat bound `0.14.6, 0.15`. GeometricBase 0.15 requires Julia 1.11, above this package's floor
  of 1.10, so Julia 1.10 must admit a 0.14 release. The bound starts at 0.14.6, the first 0.14
  release whose fallback `state_symbols(::AbstractDataType, ::AbstractSystem)` returns `()`;
  0.14.1–0.14.5 return `missing`, so `state_symbols` of `ObservableData` would differ on them.
  0.14.0 also cannot be installed with GeometricSolutions 0.6.

### Bug Fixes

- `ParameterSpace` and `NamedTuple(::Parameter...)` now accept parameters with different element
  types, e.g. a `Float64` and a `Float32` parameter together. Previously this threw a
  `MethodError`. `CartesianParameterSampler` on mixed element types now returns each column with
  its parameter's element type. Before, every column had the common supertype, e.g.
  `AbstractFloat` for `Float64` and `Float32`, or `Real` for `Float64` and `Int`.

- The two `Batch` examples in the docstrings of `Batch` and `number_of_batches` show the batches
  that Julia 1.13 draws from the seeded `Random.shuffle` stream. The old expected output did not
  match that stream, so the required doctest check failed on 1.13. The batch counts and sizes are
  unchanged; only the order of the indices differs. The package code is unchanged.

- `show(io, ::Parameter)` defined a module-local `show` method that never dispatched to
  `Base.show`, so parameters displayed with their structural form instead of the formatted
  output. It is now `Base.show(io, ::MIME"text/plain", ::Parameter)`.

- `read_parameters(fpath)` passed the group path as a keyword argument, but the underlying
  method takes it positionally. This always threw a `MethodError`. The call site is corrected.

- `save_parameters(fpath, params)` opened files with `"r+"`, so it failed on a path that
  did not exist yet. It now opens with `"cw"`, which creates a missing file and keeps the
  contents of an existing one.

- `h5save(h5, ::Parameter)` now correctly handles Parameters without samples. Previously, a
  Parameter with `samples === nothing` was written as an HDF5 dataset, which threw the error
  "size must be positive". Now no `samples` dataset is written, and `Parameter(h5, path)` or
  `h5load(Parameter, …)` reads a missing `samples` dataset as `nothing`, so the round trip
  works correctly. This was essential for saving a `ParameterSpace` built from samplers like
  `RandomParameterSampler` and `QuasiRandomParameterSampler`, which ignore pre-stored samples.

- The export `read_sampling_parameters`, which named no definition, has been removed. Since it
  was never defined, accessing it always threw `UndefVarError`; this removal is cleanup rather
  than a breaking change.

- The `DataLoader` constructors read the `autoencoder` keyword as a `Bool`. Before, they
  compared it with `== false` and `== true`, so a value such as `autoencoder = nothing` or
  `autoencoder = :yes` matched neither branch and the constructor silently returned `nothing`.
  Such a value now raises an error: a `MethodError` from `!` in the data constructors, and a
  `TypeError` in `DataLoader(dl::DataLoader; autoencoder)`. `autoencoder = 0` and
  `autoencoder = 1` matched before, because `0 == false` and `1 == true`, and now raise the same
  errors. `DataLoader(dl::DataLoader; autoencoder = nothing)` still inherits the loader's own
  setting.

### Breaking Changes

- The sampler interface changes: `sample(sampler, parameters::NamedTuple)` is now the primitive
  and infers a concrete `Table` (column names are type-level keys). `sample(sampler, p1, p2, …)`
  still works, but does not infer, because it builds the names at run time. For parameters of
  one element type it returns the same `Table` as before. A sampler now implements
  `_columns(sampler, parameters::Tuple)`, returning one sample vector per parameter, instead of
  a `sample(::MySampler, ::Vararg{Parameter})` method. The keys of the NamedTuple must equal
  the parameter names, else an `AssertionError` is raised.

- `AutoEncoderModel`, an exported stub type with no implemented behaviour, has been removed.

- `TrainingData` is now a struct rather than an abstract type, and it is exported.
  `GeometricIntegratorData` and `GeometricIntegratorEnsembleData` keep their fields and their
  exports but no longer subtype it: they are not a kind of `TrainingData` any more. Nothing
  dispatched on the old abstract type, in this package or outside it, so no call site changes.

### Changed

- `Pkg.test()` no longer runs the doctests. `test/quality/doctests.jl` is now the group `doctests`, which an empty `ARGS` does not run; `Pkg.test(test_args = ["doctests"])` runs it. In CI the Doctests job stays their runner, so the test matrix no longer runs them a second time.

- CI uploads coverage from the `Julia 1 - ubuntu-latest` job instead of `Julia min`, and a test
  job saves the Julia cache only when it succeeds.

- `src/data_loader/data_loader.jl` is now Unicode NFC-normalised. It stored `ṗ` as a base letter
  plus a combining mark, three times, inherited from macOS rather than chosen; `q̇` has no
  precomposed codepoint and is unchanged. Nothing about the compiled code changes — Julia's parser
  normalises identifiers to NFC, and all three changed lines are `NamedTuple` type parameters in
  function signatures — but a `grep` pattern or an editor search typed in NFC now matches, where
  before it silently matched nothing. The file is byte-equal to the NFC normalisation of its
  predecessor; no string literal was affected, and no changed line falls inside a doctest block.

- Internal stub types have been removed: the marker data types (`GenericData`, `VectorFieldData`,
  `TrajectoryData`, `InputOutputData`, `ProjectionData`, `AutoEncoderData`,
  `VlasovParticleMethodData`, `VlasovVariationalIntegratorData`) and the `learn` function. None of
  these had any behaviour — the marker types are empty structs, and `learn`'s body was empty. All
  were internal (not exported; reachable only as `ReducedComplexityModeling.VectorFieldData` etc.).
  Neither this package nor ReducedBasisMethods uses any of them. The `TrainingProblem` stub is
  removed as well; the exported `TrainingProblem` of the training-data entry above replaces it,
  with the behaviour the stub never had. `learn` stays removed: the entry point is `train`.

- The doctests of `Batch` and `number_of_batches` no longer print the batches of a seeded
  shuffle, whose values differ between Julia 1.10–1.12 and 1.13. They now print the length of
  each batch and the sorted indices of all batches, which hold for every permutation, so the
  doctests pass on every supported Julia version. Only docstring text changes; `Batch` and its
  shuffle behave as before.

- The test suite follows the common test convention. The test dependencies (now including
  AbstractNeuralNetworks, Aqua and Documenter) are in `test/Project.toml` rather than in
  `[extras]`/`[targets]`. `Pkg.test()` runs the `core` and `slow` groups, and
  `Pkg.test(test_args = ["core"])` runs one group; every test file runs in its own module. The
  suite now runs `Aqua.test_all` in `core`, with its ambiguity check marked broken for issue #38,
  and the doctests in `slow`. `Project.toml` gains the compat entry `LinearAlgebra = "1"`, which Aqua
  requires. The POD pipeline script that had no `@test` still runs, as
  `test/integration/pod_lorenz.jl`, and `test/helpers/problems.jl` holds the Lorenz problem it
  uses; the empty `test/Models.jl` is removed.

- The `core` group runs JET's `report_opt` in `test/quality/jet.jl`, after Aqua. The file checks
  each function that launches a KernelAbstractions kernel and that a test reaches —
  `convert_input_and_batch_indices_to_array`, `onehotbatch` and `split_and_flatten` — at the
  argument types the tests pass. It also checks the body of each kernel that the tests reach,
  through the `cpu_<kernel>` function that `@kernel` generates, because the analysis of a
  launcher does not report a defect in a kernel body. On a Julia version where JET does not work,
  the file records one skipped test. JET and KernelAbstractions are added to `test/Project.toml`,
  with no `[compat]` bound.

- `test/Project.toml` no longer has `[compat]` entries for `AbstractNeuralNetworks` and `Random`.
  Both are dependencies of the package, and the package's own `[compat]` bounds them.
