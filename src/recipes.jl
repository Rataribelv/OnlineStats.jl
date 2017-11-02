#-----------------------------------------------------------------------# Weight
@recipe function f(wt::Weight; nobs=50)
    xlab --> "Number of Observations"
    ylab --> "Weight Value"
    label --> OnlineStatsBase.name(wt)
    ylim --> (0, 1)
    w --> 2
    W = deepcopy(wt)
    v = zeros(nobs)
    for i in eachindex(v)
        OnlineStatsBase.updatecounter!(W)
        v[i] = OnlineStatsBase.weight(W)
    end
    v
end

#-----------------------------------------------------------------------# OnlineStat{0}
struct EmptyPlot end
@recipe function f(o::OnlineStat{0})
    title --> "$(name(o)): $(round.(value(o), 5))"
    legend --> false
    axis --> false
    grid --> false
    EmptyPlot()
end
@recipe f(::EmptyPlot) = zeros(0)

#-----------------------------------------------------------------------# OHistogram
@recipe function f(o::OHistogram)
    linetype --> :bar
    o.h.edges[1][1:(end-1)], o.h.weights
end

#-----------------------------------------------------------------------# (1, 0) residual plot
@recipe function f(o::OnlineStat{(1,0)}, x::AbstractMatrix, y::AbstractVector,
        dim::ObsDimension = Rows())
    ylab --> "Residual"
    xlab --> "Observation Index"
    legend --> false
    @series begin
        linetype --> :scatter
        ŷ = predict(o, x, dim)
        eachindex(y), y - ŷ
    end
    @series begin
        linetype --> :hline
        [0]
    end
end

@recipe function f(o::Series{(1,0)}, x::AbstractMatrix, y::AbstractVector)
    for stat in stats(o)
        @series begin stat end
    end
end

#-----------------------------------------------------------------------# IHistogram
@recipe function f(o::IHistogram)
    linetype --> :bar
    o.value, o.counts
end

#-----------------------------------------------------------------------# Series{0}
@recipe function f(s::Series)
    layout --> length(stats(s))
    for stat in stats(s)
        @series begin stat end
    end
end

#-----------------------------------------------------------------------# CovMatrix
@recipe function f(o::CovMatrix)
    seriestype --> :heatmap
    cov(o)
end