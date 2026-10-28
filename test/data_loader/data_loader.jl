# The loader's names, its extension points and the four names the fork got wrong. `DataLoader`,
# `Batch` and `train!` are this package's, so a dependent package re-exports them rather than
# defining a second struct of either name; `networkbackend` is AbstractNeuralNetworks' generic, and
# the loader adds a method to it; `NoTangent` and `unthunk` were called by the fork without an
# import, `params` was called without one and is now imported, and `TransformerLoss` was a function
# of this package that the fork made from GeometricMachineLearning's name.

using ReducedComplexityModeling
using AbstractNeuralNetworks: AbstractNeuralNetworks, networkbackend
using KernelAbstractions: CPU
using Test
import Random

include("../helpers/eltypes.jl")

Random.seed!(1234)

@testset "the data loader's names are this package's" begin
    @test parentmodule(DataLoader) === ReducedComplexityModeling
    @test parentmodule(Batch) === ReducedComplexityModeling
    @test parentmodule(ReducedComplexityModeling.train!) === ReducedComplexityModeling
    @test parentmodule(ReducedComplexityModeling.accuracy) === ReducedComplexityModeling
    @test parentmodule(ReducedComplexityModeling.assign_output_estimate) ===
          ReducedComplexityModeling
end

@testset "networkbackend is AbstractNeuralNetworks' generic ($T)" for T in REAL_ELTYPES
    @test parentmodule(ReducedComplexityModeling.networkbackend) === AbstractNeuralNetworks
    @test networkbackend(DataLoader(rand(T, 2, 10); suppress_info = true)) == CPU()
    @test networkbackend(DataLoader(
        (q = rand(T, 2, 10, 2), p = rand(T, 2, 10, 2)); suppress_info = true)) == CPU()
end

@testset "the four names the fork left undefined" begin
    @test isdefined(ReducedComplexityModeling, :params)
    @test !isdefined(ReducedComplexityModeling, :NoTangent)
    @test !isdefined(ReducedComplexityModeling, :unthunk)
    @test !isdefined(ReducedComplexityModeling, :TransformerLoss)
end
