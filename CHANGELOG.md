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

### Changed

- `src/data_loader/data_loader.jl` is now Unicode NFC-normalised. It stored `ṗ` as a base letter
  plus a combining mark, three times, inherited from macOS rather than chosen. Nothing about the
  compiled code changes — Julia's parser normalises identifiers to NFC — but a `grep` pattern or an
  editor search typed in NFC now matches, where before it silently matched nothing. The file is
  byte-equal to the NFC normalisation of its predecessor; no string literal was affected, and no
  changed line falls inside a doctest block.

### New Features

### Bug Fixes

### Breaking Changes

## Open Issues
