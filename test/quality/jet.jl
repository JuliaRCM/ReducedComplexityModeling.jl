using ReducedComplexityModeling
using ReducedComplexityModeling: Batch, DataLoader,
                                 convert_input_and_batch_indices_to_array,
                                 assign_output_estimate, gather_kernel!
using KernelAbstractions: KernelAbstractions, CPU
using JET
using Test

include("../helpers/eltypes.jl")

# Each launcher line analyses one function that launches a kernel, on the `CPU()` backend of
# KernelAbstractions. The element types are those that a test in `test/` outside `test/quality/`
# passes to the launcher. The `RegularArray` and `Batch{:FeedForward}` line takes its argument types
# from the doctest of `convert_input_and_batch_indices_to_array`, the only test that calls the
# launcher at that `DataLoader` type.
const TimeSeriesQP = DataLoader{
    Float64, @NamedTuple{q::Array{Float64, 3}, p::Array{Float64, 3}}, Nothing, :TimeSeries,
    Nothing}
const RegularArray = DataLoader{Float64, Array{Float64, 3}, Nothing, :RegularData, Nothing}
const Indices = Vector{Tuple{Int, Int}}
const A3{T} = Array{T, 3}
const RCM = (ReducedComplexityModeling,)

# JET drops the reports of a kernel body when it analyses the launcher, so each `@kernel` also gets a
# line that analyses the generated `cpu_<kernel>` function directly, at the `CompilerMetadata`
# context that the launcher builds. This uses internals of KernelAbstractions (`launch_config`,
# `mkcontext`, `blocks`, `Kernel.f`).
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
        indices = ones(Int, 2, 4)
        # test/data_loader/draw_batch_for_tensor_test.jl: the `(q, p)` loader of the verbatim call
        @test isempty(JET.get_reports(JET.report_opt(
            convert_input_and_batch_indices_to_array,
            (TimeSeriesQP, Batch{:Transformer}, Indices); target_modules = RCM)))
        # the one gather kernel of a `(q, p)` input: `gather` launches it once per tensor
        @test isempty(kernel_body_reports(gather_kernel!,
            (2, 3, 4), zeros(2, 3, 4), zeros(2, 8, 4), indices, 3))
        # the doctest of `convert_input_and_batch_indices_to_array`, a `:RegularData` loader without
        # an output
        @test isempty(JET.get_reports(JET.report_opt(
            convert_input_and_batch_indices_to_array,
            (RegularArray, Batch{:FeedForward}, Indices); target_modules = RCM)))
        # test/data_loader/draw_batch_for_tensor_test.jl: a `:TimeSeries` loader without an output,
        # in both precisions and at each of the two `Batch` kinds a caller builds without naming
        # one, `Batch(batch_size)` and `Batch(batch_size, seq_length)`
        for T in REAL_ELTYPES, BatchType in (Batch{:FeedForward}, Batch{:Transformer})

            @test isempty(JET.get_reports(JET.report_opt(
                convert_input_and_batch_indices_to_array,
                (DataLoader{T, A3{T}, Nothing, :TimeSeries, Nothing}, BatchType, Indices);
                target_modules = RCM)))
        end
        # the gather kernel, once per element type
        for T in REAL_ELTYPES
            @test isempty(kernel_body_reports(gather_kernel!,
                (2, 3, 4), zeros(T, 2, 3, 4), zeros(T, 2, 8, 4), indices, 3))
        end
        # input and output of kind `:TimeSeries`: no loader of the suite has this type.
        # `DataLoader(input, output)` builds `:RegularData`, and each `:TimeSeries` loader with an
        # output that a test builds by naming the type has an `Array{Int, 3}` output
        for (T, BatchType) in ((Float32, Batch{:Transformer}), (
            Float64, Batch{:FeedForward}))
            @test isempty(JET.get_reports(JET.report_opt(
                convert_input_and_batch_indices_to_array,
                (DataLoader{T, A3{T}, A3{T}, :TimeSeries, Int}, BatchType, Indices);
                target_modules = RCM)))
        end
        # the `Batch` functor under `@allocated` in test/data_loader/batch_index_set.jl, and at the
        # element types its other direct calls make: `Int` in test/data_loader/batch_functor.jl, and
        # the `:TimeSeries` `Int` of the doctest of `number_of_batches` above
        @test isempty(JET.get_reports(JET.report_opt(Batch(8),
            (DataLoader{Float32, A3{Float32}, Nothing, :TimeSeries, Nothing},);
            target_modules = RCM)))
        @test isempty(JET.get_reports(JET.report_opt(Batch(3),
            (DataLoader{Int, A3{Int}, Nothing, :TimeSeries, Nothing},);
            target_modules = RCM)))
        @test isempty(JET.get_reports(JET.report_opt(Batch(10, 16), (TimeSeriesQP,);
            target_modules = RCM)))
        # `Batch(batch_size, dl)` reads the loader's own two lengths, and
        # test/data_loader/draw_batch_for_tensor_test.jl calls it on a classifier's loader
        @test isempty(JET.get_reports(JET.report_opt(Batch(2),
            (DataLoader{Float32, A3{Float32}, A3{Int}, :RegularData, Int},);
            target_modules = RCM)))
        # ... and on a `:TimeSeries` loader whose output is as wide as its input, the other kind
        # that carries an output
        @test isempty(JET.get_reports(JET.report_opt(Batch(2),
            (DataLoader{Float32, A3{Float32}, A3{Float32}, :TimeSeries, Int},);
            target_modules = RCM)))

        # src/data_loader/tensor_assign.jl: `assign_output_estimate` in
        # test/data_loader/accuracy.jl, in both precisions
        for T in REAL_ELTYPES
            @test isempty(JET.get_reports(JET.report_opt(assign_output_estimate,
                (A3{T}, Int); target_modules = RCM)))
        end
    else
        @test_skip "JET does not work on Julia $(VERSION)"  # aviatesk/JET.jl#681
    end
end
