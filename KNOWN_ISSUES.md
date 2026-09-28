# Known issues

### K1 · Revise prints EMFILE errors in the test log

- **Kind:** upstream
- **Location:** `test/quality/jet.jl` (`using JET`); JET 0.12 loads Revise, and Revise's file
  watcher runs out of file handles.
- **Evidence:** `run-tests.jl <repository> affected` on branch `test/part-j3`, Julia 1.13.1: 6
  blocks `UNHANDLED TASK ERROR: IOError: FolderMonitor: too many open files (EMFILE)` in the log.
  The test totals do not change: every testset passes, and JET passes 11 of 11.
- **Found:** 2026-09-28, part J3 of the test-suite unification.
