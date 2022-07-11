abstract type AbstractModel end

"""
    Reduced Basis

Uses ModelOrderReduction methods from ReducedBasisMethods.jl
to represent the data in latent space.

"""
struct ReducedBasis <: AbstractModel

end

"""
    Autoencoders

Uses Variational Autoencoders to represent the data in its reduced state.
"""
struct AutoEncoder <: AbstractModel

end
