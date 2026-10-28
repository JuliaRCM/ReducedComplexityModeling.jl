using ReducedComplexityModeling, Test
using ReducedComplexityModeling: convert_input_and_batch_indices_to_array
import Random

include("../helpers/eltypes.jl")

Random.seed!(1234)

function test_data_loader_for_qp_tensor(
        system_dim2::Int, input_time_steps::Int, n_params::Int, batch_size::Int,
        seq_length::Int, prediction_window::Union{Int, Nothing} = nothing)
    _prediction_window = isnothing(prediction_window) ? seq_length : prediction_window
    dummy_data = (q = rand(system_dim2, input_time_steps, n_params),
        p = rand(system_dim2, input_time_steps, n_params))

    dl = DataLoader(dummy_data)
    batch = isnothing(prediction_window) ? Batch(batch_size, seq_length) :
            Batch(batch_size, seq_length, prediction_window)

    batch_indices_all = batch(dl)
    for batch_indices in batch_indices_all
        batched_array = convert_input_and_batch_indices_to_array(dl, batch, batch_indices)
        @test size(batched_array[1].q) == (system_dim2, seq_length, batch_size)
        @test size(batched_array[2].q) == (system_dim2, _prediction_window, batch_size)
    end
end

test_data_loader_for_qp_tensor(5, 50, 20, 10, 16)

# `gather` allocates with the element type of the data it reads, so a batch has the loader's own
# element type in both precisions and on both input forms — the kernel runs once per tensor of a
# `(q, p)` pair. An integer target stays integer: it is read at its own element type, which a
# conversion to the input's would lose.
@testset "a batch has the element type of its data ($T)" for T in REAL_ELTYPES
    n_steps = 10
    tensor_loader = DataLoader(rand(T, 2, n_steps, 3); suppress_info = true)
    qp_loader = DataLoader((q = rand(T, 2, n_steps, 3), p = rand(T, 2, n_steps, 3));
        suppress_info = true)
    batch = Batch(3, 4, 2)
    indices = first(batch(tensor_loader))

    input, target = convert_input_and_batch_indices_to_array(tensor_loader, batch, indices)
    @test eltype(input) === T
    @test eltype(target) === T
    @test size(input) == (2, 4, length(indices))
    @test size(target) == (2, 2, length(indices))

    qp_input, qp_target = convert_input_and_batch_indices_to_array(qp_loader, batch, indices)
    @test qp_input isa NamedTuple{(:q, :p)}
    @test eltype(qp_input.q) === T && eltype(qp_input.p) === T
    @test eltype(qp_target.q) === T && eltype(qp_target.p) === T

    output = rand(0:1, 3, 1, 3)
    classification_loader = DataLoader(rand(T, 2, 1, 3), output; suppress_info = true)
    classification_batch = Batch(3, classification_loader)
    class_input, class_target = convert_input_and_batch_indices_to_array(
        classification_loader, classification_batch, first(classification_batch(classification_loader)))
    @test eltype(class_input) === T
    @test eltype(class_target) === Int
end
