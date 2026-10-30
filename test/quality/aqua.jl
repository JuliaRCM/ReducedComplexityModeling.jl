using ReducedComplexityModeling
using Aqua
using Test

@testset "Aqua" begin
    Aqua.test_all(ReducedComplexityModeling)
end

# The names that GeometricMachineLearning and ReducedBasisMethods reach: public, so that a check of
# their imports finds nothing non-public, and documented.
@testset "the names other packages call are public and documented" begin
    for name in (:ParametricDataLoader, :number_of_batches, :accuracy, :assign_output_estimate,
        :convert_input_and_batch_indices_to_array, :data_tensors_from_geometric_solution,
        :map_to_type, :map_to_new_backend, :save_parameters, :read_parameters, :_create_group)
        @test Base.ispublic(ReducedComplexityModeling, name)
        @test Docs.hasdoc(ReducedComplexityModeling, name)
    end
end
