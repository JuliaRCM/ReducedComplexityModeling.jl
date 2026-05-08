using ReducedComplexityModeling
using Test
using Plots
using SafeTestsets

include("GeometricData.jl")
include("Models.jl")
include("parameter_tests.jl")
include("parameterspace_tests.jl")

@safetestset "Test mnist_utils.                                                               " begin
    include("data_loader/mnist_utils.jl")
end
@safetestset "Test data loader for a tensor (q and p data)                                    " begin
    include("data_loader/draw_batch_for_tensor_test.jl")
end
