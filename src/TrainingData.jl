abstract type TrainingData end

struct VectorFieldData <: TrainingData

end

struct TrajectoryData <: TrainingData

end

struct InputOutputData <: TrainingData

end

#-------------------------------------------------------
#- These have to go to the respective packages
struct ProjectionData <: TrainingData

end

struct AutoEncoderData <: TrainingData


end
#-------------------------------------------------------
struct GeometricIntegratorData <: TrainingData

end

struct GeometricIntegratorEnsembleData <: TrainingData

end

struct VlasovParticleMethodData <: TrainingData

end

struct VlasovVariationalIntegratorData <: TrainingData

ends
