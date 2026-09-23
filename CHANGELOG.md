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

### Bug Fixes

- The two `Batch` examples in the docstrings of `Batch` and `number_of_batches` show the batches
  that Julia 1.13 draws from the seeded `Random.shuffle` stream. The old expected output did not
  match that stream, so the required doctest check failed on 1.13. The batch counts and sizes are
  unchanged; only the order of the indices differs. The package code is unchanged.

- `show(io, ::Parameter)` defined a module-local `show` method that never dispatched to
  `Base.show`, so parameters displayed with their structural form instead of the formatted
  output. It is now `Base.show(io, ::MIME"text/plain", ::Parameter)`.

- `read_parameters(fpath)` passed the group path as a keyword argument, but the underlying
  method takes it positionally. This always threw a `MethodError`. The call site is corrected.

### Breaking Changes

- `AutoEncoderModel`, an exported stub type with no implemented behaviour, has been removed.

- The export `read_sampling_parameters` named no definition and has been removed.

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

## Open Issues
