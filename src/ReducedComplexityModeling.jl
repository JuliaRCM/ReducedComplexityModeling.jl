module ReducedComplexityModeling

using ForwardDiff
using GeometricBase: AbstractDataType, AbstractSystem
using GeometricEquations
# The solution types this package dispatches on: an ensemble of solutions, one solution, and the
# data series a snapshot matrix is built from. The loader also dispatches on `TimeSeries`, the time
# axis a solution of an `EnsembleSolution` carries.
using GeometricSolutions: DataSeries, EnsembleSolution, GeometricSolution, TimeSeries
using HDF5
using HDF5: H5DataStore
using LazyArrays
using LinearAlgebra
using Optim
using TypedTables
using KernelAbstractions
using AbstractNeuralNetworks: Chain, NeuralNetwork
# `NetworkParameters` is a network's parameter container. `parameter_eltype` and `parameterlayout`
# are what the parametric loader compares one system parameter against another with: an element
# type, and the keys and leaf sizes at every level.
using NeuralNetworkParameters: NetworkParameters, parameter_eltype, parameterlayout

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

# `ParametricDataLoader` is public and not exported: a caller reaches it as
# `ReducedComplexityModeling.ParametricDataLoader`, so the loader of trajectories and their system
# parameters is available without growing the export list.
public ParametricDataLoader

# The routines that GeometricMachineLearning and ReducedBasisMethods call, and that a caller can
# name without owning the loader: the loader's batch and tensor routines, the conversions to a type
# and to a backend, the accuracy of a network on a loader, and the HDF5 helpers that a package
# with its own data type writes its groups with.
public number_of_batches, accuracy
public assign_output_estimate, convert_input_and_batch_indices_to_array
public data_tensors_from_geometric_solution, map_to_type, map_to_new_backend
public save_parameters, read_parameters, _create_group

# needed for shuffle function
import Random
import Random: shuffle

include("data_loader/data_loader.jl")
include("data_loader/tensor_assign.jl")
include("data_loader/batch.jl")
include("data_loader/parametric_data_loader.jl")

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
