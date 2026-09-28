using ReducedComplexityModeling
using ReducedComplexityModeling: Batch, DataLoader, assign_output_estimate, augment_zeros,
                                 convert_input_and_batch_indices_to_array, onehotbatch,
                                 split_and_flatten
using JET
using Test

# Each line analyses one function that launches a kernel, at the concrete argument types
# that the tests and doctests pass, on the `CPU()` backend of KernelAbstractions.
const TimeSeriesQP = DataLoader{
    Float64, @NamedTuple{q::Array{Float64, 3}, p::Array{Float64, 3}}, Nothing, :TimeSeries}
const RegularArray = DataLoader{Float64, Array{Float64, 3}, Nothing, :RegularData}
const Indices = Vector{Tuple{Int, Int}}
const RCM = (ReducedComplexityModeling,)

@testset "JET" begin
    if isdefined(JET, :JET_AVAILABLE) ? JET.JET_AVAILABLE : JET.JET_LOADABLE
        # src/data_loader/batch.jl
        @test isempty(JET.get_reports(JET.report_opt(
            convert_input_and_batch_indices_to_array,
            (TimeSeriesQP, Batch, Indices); target_modules = RCM)))
        @test isempty(JET.get_reports(JET.report_opt(
            convert_input_and_batch_indices_to_array,
            (RegularArray, Batch, Indices); target_modules = RCM)))
        # src/data_loader/mnist_utils.jl
        @test isempty(JET.get_reports(JET.report_opt(onehotbatch, (Vector{Int},);
            target_modules = RCM)))
        @test isempty(JET.get_reports(JET.report_opt(
            split_and_flatten, (Array{Float32, 3},);
            target_modules = RCM)))
        @test isempty(JET.get_reports(JET.report_opt(split_and_flatten, (Matrix{Int},);
            target_modules = RCM)))
        # src/data_loader/tensor_assign.jl
        @test isempty(JET.get_reports(JET.report_opt(assign_output_estimate,
            (Array{Float32, 3}, Int); target_modules = RCM)))
        @test isempty(JET.get_reports(JET.report_opt(
            augment_zeros, (Array{Float32, 3}, Int);
            target_modules = RCM)))
    else
        @test_skip "JET does not work on Julia $(VERSION)"
    end
end
