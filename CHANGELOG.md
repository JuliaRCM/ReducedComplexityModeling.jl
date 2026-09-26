# Release Notes

All notable changes to ReducedComplexityModeling.jl.

This package is pre-1.0, so *every* minor release is potentially breaking in the sense of
[SemVer](https://semver.org) for `0.x` versions. The sections below name what actually
changed, so that a compat-only bump can be told apart from a rename or a change in results.

This file was started on 2026-08-31 and deliberately holds no entries. 2 versions were
released before it, the most recent `v0.1.1`, and neither is written up here: the record of
that history is `git log` and the tags. It is named as a gap rather than reconstructed,
because a changelog assembled after the fact loses exactly the reasoning that makes it worth
keeping. The `[Unreleased]` target below is provisional — confirm it when the first entry is
written.

## [Unreleased] — targeting 0.2.0

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

### Breaking Changes

- The sampler interface changes: `sample(sampler, parameters::NamedTuple)` is now the primitive
  and infers a concrete `Table` (column names are type-level keys). `sample(sampler, p1, p2, …)`
  still works, but does not infer, because it builds the names at run time. For parameters of
  one element type it returns the same `Table` as before. A sampler now implements
  `_columns(sampler, parameters::Tuple)`, returning one sample vector per parameter, instead of
  a `sample(::MySampler, ::Vararg{Parameter})` method. The keys of the NamedTuple must equal
  the parameter names, else an `AssertionError` is raised.

- `AutoEncoderModel`, an exported stub type with no implemented behaviour, has been removed.

### Changed

- `src/data_loader/data_loader.jl` is now Unicode NFC-normalised. It stored `ṗ` as a base letter
  plus a combining mark, three times, inherited from macOS rather than chosen; `q̇` has no
  precomposed codepoint and is unchanged. Nothing about the compiled code changes — Julia's parser
  normalises identifiers to NFC, and all three changed lines are `NamedTuple` type parameters in
  function signatures — but a `grep` pattern or an editor search typed in NFC now matches, where
  before it silently matched nothing. The file is byte-equal to the NFC normalisation of its
  predecessor; no string literal was affected, and no changed line falls inside a doctest block.

- Internal stub types have been removed: `TrainingProblem` and marker data types (`GenericData`,
  `VectorFieldData`, `TrajectoryData`, `InputOutputData`, `ProjectionData`, `AutoEncoderData`,
  `VlasovParticleMethodData`, `VlasovVariationalIntegratorData`), plus `learn(::TrainingProblem)`.
  None of these had any behaviour — the marker types are empty structs, and `TrainingProblem`'s
  constructor and `learn` have empty bodies. All were internal (not exported; reachable only as
  `ReducedComplexityModeling.TrainingProblem` etc.). Neither this package nor ReducedBasisMethods
  uses any of them.

- The doctests of `Batch` and `number_of_batches` no longer print the batches of a seeded
  shuffle, whose values differ between Julia 1.10–1.12 and 1.13. They now print the length of
  each batch and the sorted indices of all batches, which hold for every permutation, so the
  doctests pass on every supported Julia version. Only docstring text changes; `Batch` and its
  shuffle behave as before.

- The test suite follows the common test convention. The test dependencies (now including
  AbstractNeuralNetworks, Aqua and Documenter) are in `test/Project.toml` rather than in
  `[extras]`/`[targets]`. `Pkg.test()` runs the `core` and `slow` groups, and
  `Pkg.test(test_args = ["core"])` runs one group; every test file runs in its own module. The
  suite now runs `Aqua.test_all`, with its ambiguity check marked broken for issue #38, and the
  doctests, in `slow`. `Project.toml` gains the compat entry `LinearAlgebra = "1"`, which Aqua
  requires. The POD pipeline script that had no `@test` still runs, as
  `test/integration/pod_lorenz.jl`, and `test/helpers/problems.jl` holds the Lorenz problem it
  uses; the empty `test/Models.jl` is removed.

## Open Issues
