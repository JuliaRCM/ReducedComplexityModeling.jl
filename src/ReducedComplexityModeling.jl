module ReducedComplexityModeling

using ForwardDiff
using GeometricEquations
using GeometricSolutions
using HDF5
using HDF5: H5DataStore
using LazyArrays
using LinearAlgebra
using Optim
using TypedTables
using KernelAbstractions
using AbstractNeuralNetworks: QPT, QPTOAT, Chain, NeuralNetworkParameters, NeuralNetwork

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
include("Models/Models.jl")
include("TrainingProblem.jl")

export Array
export GeometricIntegratorData, GeometricIntegratorEnsembleData
export Dependent, Independent
export ReducedBasisModel
export POD, reduce!, project, compose

export AutoEncoderModel

include("parameters/parameter.jl")

export Parameter, hassamples

include("parameters/parametersampler.jl")

export ParameterSampler, CartesianParameterSampler, sample

include("parameters/parameterspace.jl")

export ParameterSpace

include("parameters/h5routines.jl")

export h5save, h5load, read_sampling_parameters

end
