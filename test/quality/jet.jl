using ReducedComplexityModeling
using ReducedComplexityModeling: Batch, DataLoader,
                                 convert_input_and_batch_indices_to_array,
                                 onehotbatch, split_and_flatten,
                                 assign_input_from_vector_of_tuples_kernel!,
                                 assign_output_from_vector_of_tuples_kernel!,
                                 assign_val_kernel!, split_and_flatten_kernel!
using KernelAbstractions: KernelAbstractions, CPU
using JET
using Test

# Each launcher line analyses one function that launches a kernel, on the `CPU()` backend of
# KernelAbstractions. The element types are those that a test in `test/` outside
# `test/quality/` passes to the launcher: `Float64` for `convert_input_and_batch_indices_to_array`
# and `Int` for `onehotbatch`. No test calls `split_and_flatten` directly; its `Float32` line
# follows `DataLoader(data, target)` in `test/data_loader/mnist_utils.jl`. The `Int` of its
# doctest is in `test/quality/` and gets no line.
const TimeSeriesQP = DataLoader{
    Float64, @NamedTuple{q::Array{Float64, 3}, p::Array{Float64, 3}}, Nothing, :TimeSeries}
const RegularArray = DataLoader{Float64, Array{Float64, 3}, Nothing, :RegularData}
const Indices = Vector{Tuple{Int, Int}}
const RCM = (ReducedComplexityModeling,)

# JET drops the reports of a kernel body when it analyses the launcher, so each `@kernel`
# also gets a line that analyses the generated `cpu_<kernel>` function directly, at the
# `CompilerMetadata` context that the launcher builds. This uses internals of
# KernelAbstractions (`launch_config`, `mkcontext`, `blocks`, `Kernel.f`).
function kernel_body_reports(kernel, ndrange, args...)
    k = kernel(CPU())
    nd, _, iterspace, dynamic = KernelAbstractions.launch_config(k, ndrange, nothing)
    ctx = KernelAbstractions.mkcontext(
        k, first(KernelAbstractions.blocks(iterspace)), nd, iterspace, dynamic)
    JET.get_reports(JET.report_opt(k.f, (typeof(ctx), map(typeof, args)...);
        target_modules = (JET.AnyFrameModule(ReducedComplexityModeling),)))
end

@testset "JET" begin
    if isdefined(JET, :JET_AVAILABLE) ? JET.JET_AVAILABLE : JET.JET_LOADABLE
        # src/data_loader/batch.jl
        @test isempty(JET.get_reports(JET.report_opt(
            convert_input_and_batch_indices_to_array,
            (TimeSeriesQP, Batch, Indices); target_modules = RCM)))
        @test isempty(JET.get_reports(JET.report_opt(
            convert_input_and_batch_indices_to_array,
            (RegularArray, Batch, Indices); target_modules = RCM)))
        a = zeros(2, 3, 4)
        qp = (q = zeros(2, 8, 4), p = zeros(2, 8, 4))
        indices = ones(Int, 2, 4)
        @test isempty(kernel_body_reports(
            assign_input_from_vector_of_tuples_kernel!, size(a), a, copy(a), qp, indices))
        @test isempty(kernel_body_reports(
            assign_input_from_vector_of_tuples_kernel!, size(a), a, zeros(2, 8, 4), indices))
        @test isempty(kernel_body_reports(
            assign_output_from_vector_of_tuples_kernel!, size(a), a, copy(a), qp, indices, 3))

        # src/data_loader/mnist_utils.jl
        @test isempty(JET.get_reports(JET.report_opt(onehotbatch, (Vector{Int},);
            target_modules = RCM)))
        @test isempty(JET.get_reports(JET.report_opt(
            split_and_flatten, (Array{Float32, 3},);
            target_modules = RCM)))
        @test isempty(kernel_body_reports(assign_val_kernel!, 4, zeros(Int, 10, 4), [
            1, 2, 5, 0]))
        @test isempty(kernel_body_reports(split_and_flatten_kernel!, (28, 28, 2),
            zeros(Float32, 49, 16, 2), zeros(Float32, 28, 28, 2), 7, 16))
    else
        @test_skip "JET does not work on Julia $(VERSION)"  # aviatesk/JET.jl#681
    end
end
