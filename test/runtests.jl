using SafeTestsets

const GROUPS = isempty(ARGS) ? ["core", "slow"] : ARGS

if "core" in GROUPS
    @safetestset "Aqua" include("quality/aqua.jl")
    @safetestset "JET" include("quality/jet.jl")
    @safetestset "Exports" include("integration/exports.jl")
    @safetestset "Parameter" include("parameters/parameter.jl")
    @safetestset "Parameter samplers" include("parameters/parametersampler.jl")
    @safetestset "Parameter spaces" include("parameters/parameterspace.jl")
    @safetestset "TrainingData" include("TrainingData/TrainingData.jl")
    @safetestset "TrainingProblem" include("TrainingProblem.jl")
    @safetestset "The loader's names and constructors" include("data_loader/data_loader.jl")
    @safetestset "Batching" include("data_loader/batch.jl")
    @safetestset "The parametric data loader" include("data_loader/parametric_data_loader.jl")
    @safetestset "Data loader for a tensor" include("data_loader/draw_batch_for_tensor_test.jl")
    @safetestset "Batch functor(s)" include("data_loader/batch_functor.jl")
    @safetestset "The minibatch index set is concrete and grows linearly" include("data_loader/batch_index_set.jl")
    @safetestset "An unexpected `autoencoder` keyword throws rather than returning nothing" include("data_loader/autoencoder_keyword.jl")
    @safetestset "Classifier accuracy" include("data_loader/accuracy.jl")
    @safetestset "POD of the Lorenz system" include("integration/pod_lorenz.jl")
end
if "doctests" in GROUPS
    @safetestset "Doctests" include("quality/doctests.jl")
end
