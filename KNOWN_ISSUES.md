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

### K2 · The JET launcher lines do not see a dispatch on an argument of a kernel launch

- **Kind:** missing test
- **Location:** `test/quality/jet.jl`, the `report_opt` lines of
  `convert_input_and_batch_indices_to_array`, `onehotbatch` and `split_and_flatten`.
- **Evidence:** a runtime dispatch on an argument of a KernelAbstractions call or of a kernel
  launch sits in a KernelAbstractions frame, which `target_modules = (ReducedComplexityModeling,)`
  filters out; `JET.AnyFrameModule` through a launcher reports on KernelAbstractions' own
  machinery for a clean kernel, so the lines do not use it. Mutants that survive:
  `Base.inferencebarrier(dl.input)` as a kernel argument in `src/data_loader/batch.jl:372`;
  `Base.inferencebarrier(batch.seq_length)` into the output launch; a barrier on `length(target)`
  in `zeros(...)` and on `target` in `assign_val!` of `onehotbatch`; a barrier in
  `allocate(... size(input, 3))`. A barrier on a value that the launcher's own frame uses
  (`length(batch_indices_tuple)`, `q_input`) gives 1–2 reports. Reproducer:
  `mutate.jl <repository> src/data_loader/mnist_utils.jl 'assign_val!(output, target, ndrange =
  length(target))' 'assign_val!(output, Base.inferencebarrier(target), ndrange = length(target))'
  quality/jet.jl` prints `SURVIVED — no unit sees the mutant` (`selected | 9 9`). The kernel
  bodies are checked by the `cpu_<kernel>` lines, which analyse only the `NoDynamicCheck` context;
  the `DynamicCheck` variant has the same body.
- **Found:** 2026-09-28

### K3 · `test_onehotbatch` checks one column, at an index off by one

- **Kind:** defect
- **Location:** `test/data_loader/mnist_utils.jl:49`
- **Evidence:** `zip(length(V), V)` gives the one pair `(4, 1)` for `V = [1, 2, 5, 0]`, so the loop
  checks only column 4. `onehotbatch` maps `i` to row `i + 1`, but the test reads
  `V_encoded[v, 1, i]` (`:51`); the check passes only because `V[4] = 0`. The fix is
  `for (i, v) in enumerate(V)` with `V_encoded[v + 1, 1, i]`.
- **Found:** 2026-09-28

### K4 · `test_dummy_mnist` asserts nothing

- **Kind:** missing test
- **Location:** `test/data_loader/mnist_utils.jl:70`
- **Evidence:** the function builds a `DataLoader` and ends with `@warn "缺少test"`; it has no
  `@test`. `test/quality/jet.jl` takes the `Float32` type of its `split_and_flatten` lines from
  this call.
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

### K12 · `accuracy(::NeuralNetwork, ::DataLoader)` calls an undefined `params`

- **Location:** `src/data_loader/data_loader.jl:540`, the method
  `accuracy(nn::NeuralNetwork, dl::DataLoader) = accuracy(nn.model, params(nn), dl)`.
- **Evidence:** `params` is defined neither by this package nor by `Base`.
  `isdefined(ReducedComplexityModeling, :params)` is `false` in an environment with
  AbstractNeuralNetworks 0.8.0 and in one with 0.6.4, since the module imports only `Chain` and
  `NeuralNetwork` from it, and `isdefined(Base, :params)` is `false` on Julia 1.10, 1.11, 1.12 and
  1.13. The call therefore raises `UndefVarError: params not defined in ReducedComplexityModeling`.
  No test reaches the method and `accuracy` is not exported, so the suite passes.
- **Kind:** defect
- **Found:** 2026-10-11 (merge base `3b0554e`)

### K13 · Explicit import checks report implicit and non-public dependency accesses

- **Location:** `src/ReducedComplexityModeling.jl:4`, the dependency imports, and their uses in
  included source files.
- **Evidence:** on Julia 1.13.1, ExplicitImports 1.15.0,
  `print_explicit_imports(ReducedComplexityModeling; report_non_public = true)` reports 31
  implicitly imported names, 3 non-public explicit imports (`AbstractDataType`, `AbstractSystem`,
  `H5DataStore`), and 9 non-public qualified accesses.
  `test_explicit_imports(ReducedComplexityModeling)` fails the implicit-import, public-import and
  public-qualified-access checks. The import statements are present at merge base `3b0554e`;
  the `Chain` and `NeuralNetwork` imports have no diagnostic.
- **Kind:** defect
- **Found:** 2026-10-11 (pre-PR verification of `compat/ann-0.8`)
