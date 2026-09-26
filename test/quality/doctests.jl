using ReducedComplexityModeling
using Documenter
using Test

# Documenter evaluates the `@meta` block of a manual page in `Main`.
@eval Main import ReducedComplexityModeling

DocMeta.setdocmeta!(ReducedComplexityModeling, :DocTestSetup,
    :(using ReducedComplexityModeling); recursive = true)

doctest(ReducedComplexityModeling)
