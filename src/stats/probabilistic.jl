#-----------------------------------------------------------------------------# CountMinSketch
# https://florian.github.io/count-min-sketch/
"""
    CountMinSketch(nhash=20)
"""
mutable struct CountMinSketch{T, I, H} <: OnlineStat{T} 
    sketch::Matrix{I}
    n::Int
    function CountMinSketch(T::Type, nhash::Integer=20; storagetype = Int, hashtype=UInt8)
        new{T, storagetype, hashtype}(zeros(storagetype, typemax(hashtype), nhash), 0)
    end
end
CountMinSketch(nhash::Integer=20, T::Type=Number; kw...) = CountMinSketch(T, nhash; kw...)

# value(::CountMinSketch) = nothing
value(::CountMinSketch{T}, val::S) where {T,S} = error("CountMinSketch is tracking $T but value of $S was requested.")

_index(value, j, hashtype) = (hash(value, UInt(j)) % hashtype) + 1

value(o::CountMinSketch{T,I,H}, val::T) where {T,I,H} = minimum(o.sketch[_index(val, j, H), j] for j in 1:size(o.sketch, 2))

function _fit!(o::CountMinSketch{T,I,H}, y) where {T,I,H}
    o.n += 1
    r, c = size(o.sketch)
    for j in 1:c 
        o.sketch[_index(y, j, H), j] += 1
    end
end

#-----------------------------------------------------------------------# HyperLogLog
# https://arxiv.org/pdf/1702.01284.pdf

"""
    HyperLogLog(T = Number)
    HyperLogLog{P}(T = Number)

Approximate count of distinct elements of a data stream of type `T`, using `2 ^ P`
"registers".  `P` must be an integer between 4 and 16 (default).

By default it returns the improved HyperLogLog cardinality estimator as defined by [^1].

The original HyperLogLog estimator [^2] can be retrieved with the option `original_estimator=true`.

# Example

    o = HyperLogLog()
    fit!(o, rand(1:100, 10^6))

    using Random
    o2 = HyperLogLog(String)
    fit!(o2, [randstring(20) for i in 1:1000])

    # by default the improved estimator is returned:
    value(o)
    # the original HyperLogLog estimator can be retrieved via:
    value(o; original_estimator=true)

# References

[^1] Improved estimator:
Otmar Ertl.
New cardinality estimation algorithms for HyperLogLog sketches.
<https://arxiv.org/abs/1702.01284>

[^2] Original estimator:
P. Flajolet, Éric Fusy, O. Gandouet, and F. Meunier.
Hyperloglog: The analysis of a near-optimal cardinality estimation algorithm.
*In Analysis of Algorithms (AOFA)*, pages 127–146, 2007.
"""
mutable struct HyperLogLog{p, T} <: OnlineStat{T}
    M::Vector{Int}
    n::Int
    function HyperLogLog{p}(T::Type=Number) where {p}
        4 ≤ p ≤ 16 || throw(ArgumentError("Number of registers must be in 4:16"))
        new{p,T}(zeros(Int, 2^p), 0)
    end
end
HyperLogLog(T::Type=Number) = HyperLogLog{16}(T)

function Base.show(io::IO, o::HyperLogLog{p,T}) where {p,T}
    print(io, "HyperLogLog{$p, $T}: n=$(nobs(o)) | value=", value(o))
end

function _fit!(o::HyperLogLog{p}, v) where {p}
    o.n += 1
    x = hash(v) % UInt32
    i = (x & mask(o)) + UInt32(1)
    w = (x & ~mask(o))
    nzeros = min(leading_zeros(w), 32 - p)
    o.M[i] = max(o.M[i], UInt32(nzeros + 1))
end

function value(o::HyperLogLog; original_estimator=false)
    original_estimator && return _original_estimator(o)
    _improved_estimator(o)
end

function _original_estimator(o::HyperLogLog)
    E = α(o) * _m(o) * _m(o) * inv(sum(x -> inv(2 ^ x), o.M))
    if E ≤ 5 * _m(o) / 2
        V = sum(==(0), o.M)
        return V == 0 ? E : _m(o) * log(_m(o) / V)
    elseif E ≤ 2 ^ 32 / 30
        return E
    else
        return -2 ^ 32 * log(1 - E / 2 ^ 32)
    end
end

function _improved_estimator(o::HyperLogLog)
    m = _m(o)
    C = _multiplicities(o)
    z = τ(1 - C[end] / m)
    for C_k = C[end-1:-1:2]
        z = (z + C_k) / 2
    end
    z += m * σ(C[1] / m)
    return m^2.0 / z / (2log(2))
end

function _merge!(o::HyperLogLog, o2::HyperLogLog)
    length(o.M) == length(o2.M) ||
        error("Merge failed. HyperLogLog objects have different number of registers.")
    o.n += o2.n
    for j in eachindex(o.M)
        @inbounds o.M[j] = max(o.M[j], o2.M[j])
    end
    o
end

function _multiplicities(o::HyperLogLog{p}) where p
    q = 32 - p
    C = zeros(Int, q + 2)
    for k = o.M
        C[k+1] += 1
    end
    return C
end

function σ(x::Float64)
    x == 1 && return Inf
    y, z = 1, x
    while true
        x = x^2
        z′ = z
        z = z + x*y
        z′ == z && return z
        y *= 2
    end
end

function τ(x::Float64)
    (x == 0 || x == 1) && return 0
    y, z = 1, 1 - x
    while true
        x = √x
        z′ = z
        y = 0.5y
        z = z - y*(1 - x)^2
        z′ == z && return z/3
    end
end

@generated _m(o::HyperLogLog{p}) where {p} = 2 ^ p

@generated mask(o::HyperLogLog{p}) where {p} = UInt32(2 ^ p - 1)

@generated α(o::HyperLogLog{4}) = 0.673
@generated α(o::HyperLogLog{5}) = 0.697
@generated α(o::HyperLogLog{6}) = 0.709
@generated α(o::HyperLogLog{p}) where {p} = 0.7213 / (1 + 1.079 / 2 ^ p)