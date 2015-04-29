
#-------------------------------------------------------# Type and Constructors
type Mean{W<:Weighting} <: ScalarStat
    μ::Float64
    n::Int64
    weighting::W
end

function Mean{T<:Real}(y::Vector{T}, wgt::Weighting = default(Weighting))
    o = Mean(wgt)
    update!(o, y)
    o
end

Mean(y::Float64, wgt::Weighting = default(Weighting)) = Mean([y], wgt)
Mean(wgt::Weighting = default(Weighting)) = Mean(0., 0, wgt)


#-----------------------------------------------------------------------# state

statenames(o::Mean) = [:μ, :nobs]
state(o::Mean) = [mean(o), nobs(o)]

Base.mean(o::Mean) = o.μ

#---------------------------------------------------------------------# update!

function update!(o::Mean, y::Float64)
    o.μ = smooth(o.μ, y, weight(o))
    o.n += 1
    return
end

#------------------------------------------------------------------------# Base


# Base.copy(o::Mean) = Mean(o.μ, o.n, o.weighting)

function Base.empty!(o::Mean)
    o.μ = 0.
    o.n = 0
    return
end

function Base.merge!(o1::Mean, o2::Mean)
    λ = mergeweight(o1, o2)
    o1.μ = smooth(o1.μ, o2.μ, λ)
    o1.n += nobs(o2)
    o1
end
