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
