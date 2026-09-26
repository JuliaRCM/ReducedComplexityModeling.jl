using SafeTestsets

const GROUPS = isempty(ARGS) ? ["core", "slow"] : ARGS

if "core" in GROUPS
    @safetestset "Aqua" include("quality/aqua.jl")
    @safetestset "Exports" include("integration/exports.jl")
    @safetestset "Parameter" include("parameters/parameter.jl")
    @safetestset "Parameter samplers" include("parameters/parametersampler.jl")
    @safetestset "Parameter spaces" include("parameters/parameterspace.jl")
    @safetestset "MNIST utilities" include("data_loader/mnist_utils.jl")
    @safetestset "Data loader for a tensor" include("data_loader/draw_batch_for_tensor_test.jl")
    @safetestset "POD of the Lorenz system" include("integration/pod_lorenz.jl")
end
if "slow" in GROUPS
    @safetestset "Doctests" include("quality/doctests.jl")
end
