# Known issues

### K1 · Revise prints EMFILE errors in the test log

- **Kind:** upstream
- **Location:** `test/quality/jet.jl` (`using JET`); JET 0.12 loads Revise, and Revise's file
  watcher runs out of file handles.
- **Evidence:** the full suite (`Pkg.test`, through `run-tests.jl <repository> affected`) on branch
  `test/part-j3`, Julia 1.13.1: 6 blocks `UNHANDLED TASK ERROR: IOError: FolderMonitor: too many
  open files (EMFILE)` in the log. The full suite on the merge base with origin/main (25c2afe)
  gives none. The test totals do not change: every testset passes, and JET passes 9 of 9.
- **Found:** 2026-09-28

### K5 · `SystemType` is declared by the caller and cannot be inferred from a problem

- **Location:** `src/TrainingData/TrainingData.jl:82`, the `SY <: AbstractSystem` parameter of the
  `TrainingData` struct declared at `:79`.
- **Evidence:** `hashamiltonian` and `haslagrangian` of `GeometricEquations` separate a
  Hamiltonian problem from a Lagrangian one and nothing finer:

      julia --startup-file=no --project=. -e '
      using GeometricEquations
      v!(v, t, q, p, params) = (v .= p)
      f!(f, t, q, p, params) = (f .= -q)
      h(t, q, p, params) = sum(abs2, p) / 2 + sum(abs2, q) / 2
      prob = HODEProblem(v!, f!, h, (0.0, 1.0), 0.1, [1.0], [0.0])
      println((hashamiltonian(prob), haslagrangian(prob)))'
      (true, false)

  Their methods are one per equation type — `Tuple{typeof(hashamiltonian), HODE}`,
  `Tuple{typeof(hashamiltonian), HDAE}` and the `GeometricEquation` and `GeometricProblem`
  fallbacks, and `haslagrangian` for `LODE` and `LDAE` — so nothing separates a canonical from a
  noncanonical or Poisson system, nor a regular from a degenerate Lagrangian one. A
  `TrainingData` therefore takes its `SystemType` from the caller, and data that never came from
  a problem have no trait to read at all.
- **Kind:** upstream
- **Found:** 2026-10-10

### K6 · `problem(td, i)` is not inferred and allocates on every call

- **Location:** `src/TrainingData/TrainingData.jl:122`, the `problem(td::TrainingData, i)` method.
- **Evidence:** a cold `Base.return_types(member2, (typeof(td),))`, with
  `member2(td) = problem(td, 2)` and `td` the benchmark ensemble data, gives
  `EquationProblem{_A, Float32, …} where _A<:GeometricEquation` in `Float32` and the `Float64` form
  in `Float64`; `allocations(member2, td)` is 384 B in `Float32` and 464 B in `Float64`,
  while `allocations(state_symbols, td)` is 0 and the control `allocations(collect, T[1, 2])` reads
  64 B and 80 B. The raw upstream call `problem(ens, 2)` allocates the same 384 B and 464 B, so the
  cost is not the forwarding. The cause is in `GeometricEquations` 0.21.5:
  `problem(::EnsembleProblem, i)` calls the `EquationProblem` constructor, which computes its first
  type parameter with `eval(typeof(equ).name.name)` (`src/problems/equation_problem.jl:82`) and
  runs `check_methods` on every construction (`:79`). `ReducedComplexityModeling` only forwards
  the call, so there is no local fix.
- **Kind:** upstream
- **Found:** 2026-10-11 (critic round 1c)

### K10 · Dropping `x_reltol = eps(T)` leaves every test green

- **Location:** `src/TrainingProblem.jl:60`, `Optim.Options(; g_abstol, x_reltol = eps(T))`.
- **Evidence:** the mutant `Optim.Options(; g_abstol, x_reltol = eps(T))` →
  `Optim.Options(; g_abstol)`, run with `run-tests.jl <repository> TrainingData/TrainingData.jl
  TrainingProblem.jl`, passes 413 of 413, the same count as the unchanged options. No input on
  which the two option sets differ is known: the 120 noisy fits of `train converges on noisy data`
  meet their tolerance under both, and a loss with a kink at its minimiser,
  `|a - 1/3| + (b - 1)²`, gives the same fit under both, so it may be an equivalent mutant.
- **Kind:** not verified
- **Found:** 2026-10-11 (critic round 1a)

### K13 · Explicit import checks report implicit and non-public dependency accesses

- **Location:** `src/ReducedComplexityModeling.jl:13`, the dependency imports, and their uses in
  included source files.
- **Evidence:** on Julia 1.13.3, ExplicitImports 1.15.0,
  `print_explicit_imports(ReducedComplexityModeling; report_non_public = true)` reports 25
  implicitly imported names, 5 non-public explicit imports (`AbstractDataType`, `AbstractSystem`,
  `ArrayOrNamedTuple`, `H5DataStore`, `NamedTupleOfArrays`), and 8 non-public qualified accesses.
  `test_explicit_imports(ReducedComplexityModeling)` fails the implicit-import, public-import and
  public-qualified-access checks. `ArrayOrNamedTuple` and `NamedTupleOfArrays` are imported at
  `src/ReducedComplexityModeling.jl:35`, for the data loader's dispatch; the other import
  statements are present at merge base `3b0554e`. The `Chain` and `NeuralNetwork` imports have no
  diagnostic.
- **Kind:** defect
- **Found:** 2026-10-11 (pre-PR verification of `compat/ann-0.8`)

### K14 · The loader's gather kernel has no device test

- **Location:** `src/data_loader/batch.jl`, `gather` and `gather_kernel!`, reached through
  `convert_input_and_batch_indices_to_array`; no test runs either on a `JLArray`.
- **Evidence:** `grep -rn 'JLArray\|JLArrays\|GPUArraysCore' test/ Project.toml test/Project.toml`
  finds no hit, so the test environment carries neither package. The code itself is device-clean.
  `julia --startup-file=no` on a script that opens a temporary environment — `Pkg.activate(;
  temp = true)`, `Pkg.develop(Pkg.PackageSpec(path = "."))`, `Pkg.add(["JLArrays",
  "GPUArraysCore", "KernelAbstractions"])` — then calls
  `convert_input_and_batch_indices_to_array` under `allowscalar(false)` passes 57 of 57 assertions
  in `Float32` and 57 of 57 in `Float64` (2026-10-28), on a tensor loader, a `(q, p)` loader and an
  `autoencoder = true` one: every drawn batch's input and target is a `JLArray{T, 3}` that holds
  the source tensor's entries, `networkbackend` is a `JLBackend`, and the conversions to `CPU()`
  and to the other precision return the element type they name. The device tests of
  GeometricMachineLearning train a network of that package, so no testset of them moves here with
  the loader.
- **Kind:** missing test
- **Found:** 2026-10-28 (critic round 1a)

### K15 · The local inventory of GeometricMachineLearning's manual does not exist

- **Location:** `docs/make.jl`, the third element of the `InterLinks` tuple,
  `joinpath(@__DIR__, "inventories", "GeometricMachineLearning.toml")`.
- **Evidence:** `ls docs/inventories` reports no such directory, on `origin/main` (`git cat-file -e
  064a310:docs/inventories/GeometricMachineLearning.toml` fails) and on this branch, and `makedocs`
  does not create one. The build of 2026-10-28 renders the 4 distinct GeometricMachineLearning
  links of its page from the remote `objects.inv` that the tuple's second element names, so the
  third element is a fallback that no build reads.
- **Kind:** defect
- **Found:** 2026-10-28 (critic round 1b)

### K16 · `GeometricIntegratorEnsembleData(solutions, Independent())` throws

- **Location:** `src/TrainingData/GeometricData.jl`, `Base.Array(solutions, ::Independent)`, which
  ends in `Array(Z')` on the three-dimensional array `Z`.
- **Evidence:** with `sol` the Lorenz solution of `test/helpers/problems.jl`,
  `GeometricIntegratorEnsembleData(GeometricSolution[sol, sol], Independent())` throws
  `ErrorException: adjoint not defined for Array{Float64, 3}`; the same call with `Dependent()`
  returns a `3 × 20002` snapshot. No test constructs the `Independent` layout.
- **Kind:** defect
- **Found:** 2026-10-29

### K17 · `reduce!` with `CotangentLiftEVD` throws on every call

- **Location:** `src/Models/ReducedBasis.jl`, `reduce!(model, k, ::CotangentLiftEVD)`, the line
  `U, _, _ = svd(cotangent_snap)[:, 1:k]`.
- **Evidence:** `reduce!(ReducedBasisModel(alg, randn(6, 10)), 2, alg)` with
  `alg = ReducedComplexityModeling.CotangentLiftEVD()` throws `MethodError: no method matching
  getindex(::LinearAlgebra.SVD{…}, ::Colon, ::UnitRange{Int64})`. No test calls the method, and
  the mutant that makes its body `error("mutant")` passes `integration/pod_lorenz.jl` and
  `TrainingProblem.jl`.
- **Kind:** defect
- **Found:** 2026-10-29

### K18 · `reduce!` with `ComplexSVD` throws on every call

- **Location:** `src/Models/ReducedBasis.jl`, `reduce!(model, k, ::ComplexSVD)`, which assigns
  `ϕ, Ψ = real.(U), imag.(U)` and then reads `Φ`.
- **Evidence:** `reduce!(ReducedBasisModel(alg, randn(6, 10)), 2, alg)` with
  `alg = ReducedComplexityModeling.ComplexSVD()` throws `UndefVarError: Φ not defined in
  ReducedComplexityModeling`. No test calls the method, and the mutant that makes its body
  `error("mutant")` passes `integration/pod_lorenz.jl` and `TrainingProblem.jl`.
- **Kind:** defect
- **Found:** 2026-10-29

### K19 · The parameter tests write `temp.h5` in the working directory

- **Location:** `test/parameters/parameter.jl`, `h5file = "temp.h5"`, and
  `test/parameters/parametersampler.jl`, the testset `h5save and h5load of a randomly sampled
  ParameterSpace`.
- **Evidence:** in a `mutate.jl --warm … --jobs 4` run of four mutants started at once, two logs
  show `Parameter: Error During Test` with `unable to determine if temp.h5 is accessible in the
  HDF5 format (file may not exist)` and then `read_parameters from a file path: Test Failed` at
  `@test !isfile(h5file)`: the processes share one working directory, so one test removes or
  finds the file of another. A test run in one process does not show it.
- **Kind:** defect
- **Found:** 2026-10-29

### K20 · The reduced-basis integration test asserts nothing

- **Location:** `test/integration/pod_lorenz.jl`, the calls `reduce!(model, k, alg)`,
  `compose(prob, model)` and `project(red_sol, model)`.
- **Evidence:** `grep -c '@test' test/integration/pod_lorenz.jl` gives `0`. The script fails only
  when one of these calls throws, so a `reduce!`, `compose` or `project` that returns a wrong basis
  or a wrong state passes it. A test that compares `project(red_sol, model)` with `sol.q` to a
  stated tolerance would catch such a change.
- **Kind:** missing test
- **Found:** 2026-10-29 (critic round 1a)

### K21 · The docstrings of `h5save` and `h5load` name only the `ParameterSpace` method

- **Location:** `src/parameters/parameterspace.jl`, the docstrings `save ParameterSpace` and
  `Load ParameterSpace`.
- **Evidence:** each name has three methods: the `ParameterSpace` method there, the `Parameter`
  method in `src/parameters/parameter.jl` and the file-path method in
  `src/parameters/h5routines.jl`. Only the `ParameterSpace` method has a docstring, and it gives
  neither the arguments nor the other two forms.
- **Kind:** docs
- **Found:** 2026-10-29 (critic rounds 1a and 1b)
