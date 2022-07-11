"""
    Integrators for resolving the reduced models.
"""
abstract type AbstractIntegrator end

struct GeometricNumericalIntegrator <: AbstractIntegrator

end

struct SympNet <: AbstractIntegrator

end
