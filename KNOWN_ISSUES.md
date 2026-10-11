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
- **Location:** `test/data_loader/mnist_utils.jl:50`
- **Evidence:** `zip(length(V), V)` gives the one pair `(4, 1)` for `V = [1, 2, 5, 0]`, so the loop
  checks only column 4. `onehotbatch` maps `i` to row `i + 1`, but the test reads
  `V_encoded[v, 1, i]` (`:52`); the check passes only because `V[4] = 0`. The fix is
  `for (i, v) in enumerate(V)` with `V_encoded[v + 1, 1, i]`.
- **Found:** 2026-09-28

### K4 · `test_dummy_mnist` asserts nothing

- **Kind:** missing test
- **Location:** `test/data_loader/mnist_utils.jl:71`
- **Evidence:** the function builds a `DataLoader` and ends with `@warn "缺少test"`; it has no
  `@test`. `test/quality/jet.jl` takes the `Float32` type of its `split_and_flatten` lines from
  this call.
- **Found:** 2026-09-28

### K5 · `SystemType` is declared by the caller and cannot be inferred from a problem

- **Location:** `src/TrainingData/TrainingData.jl:73`, the `SY <: AbstractSystem` parameter of
  `TrainingData`.
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
