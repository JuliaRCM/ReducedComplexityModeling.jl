module ReducedComplexityModeling

using ForwardDiff
using GeometricBase: AbstractDataType, AbstractSystem
using GeometricEquations
using GeometricSolutions
using HDF5
using HDF5: H5DataStore
using LazyArrays
using LinearAlgebra
using Optim
using TypedTables
using KernelAbstractions
using AbstractNeuralNetworks: Chain, NeuralNetwork
using NeuralNetworkParameters: NetworkParameters

# The input and output types of a network: `NamedTupleOfArrays{T, (:q, :p)}` is data in `(q, p)`
# form and `ArrayOrNamedTuple{T}` is an array or a named tuple of arrays. The data loader dispatches
# on them, and the package that owns them does not export either.
using AbstractNeuralNetworks: NamedTupleOfArrays, ArrayOrNamedTuple
# `networkbackend` is a loader's backend and `params` a network's parameters: both are generics of a
# dependency rather than functions of this package. `params` is NeuralNetworkParameters', which
# AbstractNeuralNetworks re-exports.
import AbstractNeuralNetworks: networkbackend, params

import GeometricBase: state_symbols

export DataLoader, Batch

# needed for shuffle function
import Random
import Random: shuffle

include("data_loader/data_loader.jl")
include("data_loader/tensor_assign.jl")
include("data_loader/batch.jl")

include("TrainingData/TrainingData.jl")

export ObservableSpace, IntrinsicSpace, TrainingData

include("Models/Models.jl")

export Array
export GeometricIntegratorData, GeometricIntegratorEnsembleData
export Dependent, Independent
export ReducedBasisModel
export POD, reduce!, project, compose

include("parameters/parameter.jl")

export Parameter, hassamples

include("parameters/parametersampler.jl")

export ParameterSampler, CartesianParameterSampler, sample
export RandomParameterSampler, QuasiRandomParameterSampler

include("parameters/parameterspace.jl")

export ParameterSpace

include("parameters/h5routines.jl")

export h5save, h5load

include("TrainingProblem.jl")

export TrainingProblem, train, train!

end
