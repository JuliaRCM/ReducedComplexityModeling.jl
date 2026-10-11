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

# DataLoader dispatches on (q, p) pairs of arrays with matching types, or on a single array.
const QPT{T} = NamedTuple{(:q, :p), Tuple{AT, AT}} where {T, AT <: AbstractArray{T}}
const QPTOAT{T} = Union{QPT{T}, AbstractArray{T}} where {T}

import GeometricBase: state_symbols
import ChainRulesCore
using ChainRulesCore: @thunk, Thunk

export DataLoader

# needed for shuffle function
import Random

include("data_loader/data_loader.jl")
include("data_loader/tensor_assign.jl")
include("data_loader/matrix_assign.jl")
include("data_loader/mnist_utils.jl")
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
