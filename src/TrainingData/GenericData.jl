abstract type GenericData <: TrainingData end 

struct VectorFieldData <: GenericData

end

struct TrajectoryData <: GenericData

end

struct InputOutputData <: GenericData

end
