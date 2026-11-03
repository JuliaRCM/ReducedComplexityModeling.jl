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

### K28 · A minibatch of a tensor is not a uniform sample of the pairs (time, parameter)

- **Location:** `src/data_loader/batch.jl:212`, `batch_over_two_axes`, which the `Batch` functor
  calls for a `DataLoader` (`:219`) and for a `ParametricDataLoader`
  (`src/data_loader/parametric_data_loader.jl:103`).
- **Evidence:** the function shuffles the start positions and the parameter indices separately,
  takes their product in column order and cuts this list into pieces of length `b`. So every
  parameter uses one permutation of the start positions, and an epoch runs through the parameters
  one after the other. An excerpt of the output on Julia 1.13.3, whose seeded lines can differ on
  another version:

      julia --startup-file=no --project=. scripts/batch_parameter_floor.jl
      6 time steps, 3 parameters, Batch(2, 1, 1): 8 batches
      distinct parameters per batch: [1, 1, 2, 1, 1, 1, 1, 1]
      batches: [[(5, 2), (4, 2)], [(2, 2), (1, 2)], [(3, 2), (5, 1)], [(4, 1), (2, 1)], [(1, 1), (3, 1)], [(5, 3), (4, 3)], [(2, 3), (1, 3)], [(3, 3)]]

      n start positions, P parameters, batch size b, over 200 seeds
      n = 5, P = 3, b = 2: 8 batches, 1 with more than one parameter
      n = 10, P = 7, b = 4: 18 batches, 3 with more than one parameter
      n = 10, P = 7, b = 10: 7 batches, 0 with more than one parameter

      mean square difference from the epoch mean, n = 100, P = 10, 400 epochs
      between-parameter term: 0.7963
      b = 5: loader measured 0.9933, closed form 0.9942, uniform partition closed form 0.3641
      b = 10: loader measured 0.89, closed form 0.89, uniform partition closed form 0.1811
      b = 100: loader measured 0.7963, closed form 0.7963, uniform partition closed form 0.0165

  An epoch has `⌈nP/b⌉` batches and no pair appears twice. For `b ≤ n`, a batch holds more than
  one parameter once for each `k` in `1:(P - 1)` where `b` does not divide `k n`, so at most `P - 1`
  batches do. The script asserts these counts over 200 seeds, and the measured column against its
  closed form. Where one axis has length one, the batches are a uniform partition: a matrix, a
  vector or a `(q, p)` pair with `autoencoder = true`, or one trajectory. A tensor with
  `autoencoder = true` keeps both axes, and its batches have the same form as above.

  This is a question of design and no broken promise. The docstrings of `Batch` and
  `number_of_batches` promise that an epoch draws every pair once, which holds, and no docstring
  or page of this package promises uniform batches. The manual of `GeometricMachineLearning`
  describes this product, with a figure.

  **Consequence:** the mean of a per-sample gradient over a batch has a mean square difference from
  the full gradient with a term that does not fall with `b`: the mean over the parameters of the
  square difference between that parameter's gradient and the full gradient. A uniform partition
  has no such term and falls as `1/b`. Steps inside an epoch also follow the data of one parameter
  at a time. The term is zero only where the gradients of all parameters agree. No training was
  compared, so the effect on a trained model is not measured.

  **Possible fix:** cut one shuffle of all pairs,
  `shuffle(vec(collect(Iterators.product(1:n, 1:P))))`. This keeps the number of batches and
  draws every pair once, and it changes the batches that every downstream training sees, so the
  manual of `GeometricMachineLearning` needs the same change. The fix was not tried on the suite.
- **Kind:** defect
- **Found:** 2026-11-04
