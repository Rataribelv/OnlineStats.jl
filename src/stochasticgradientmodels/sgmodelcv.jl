#--------------------------------------------------------# Type and Constructors
"""
Automatically tune the penalty parameter for an SGModel by finding the best fit
to the test data.

`SGModelCV(o::SGModel, xtest, ytest; decay = .7)`

Each call to `update!(o::SGModelCV, x, y)` updates the penalty parameter λ by
choosing the parameter which provides the best prediction on `y`:

- `λ - 1 / nobs(o) ^ decay`
- `λ`
- `λ + 1 / nobs(o) ^ decay`
"""
type SGModelCV <: StochasticGradientStat
    o::SGModel
    o_l::SGModel    # low
    o_h::SGModel    # high
    η::Float64      # constant part of decay rate
    decay::Float64  # decay rate for λ
    xtest::AMatF
    ytest::AVecF
    burnin::Int
    function SGModelCV(o::SGModel, xtest, ytest; η = .1, decay = .7, burnin = 1000)
        @assert 0 < decay <= 1
        new(o, copy(o), copy(o), η, decay, xtest, ytest, burnin)
    end
end

#----------------------------------------------------------------------# update!
# NoPenalty
function updateλ!{A <: SGAlgorithm, M <: ModelDefinition}(
        o::SGModel{A, M, NoPenalty},
        o_l::SGModel{A, M, NoPenalty},
        o_h::SGModel{A, M, NoPenalty},
        x::AVecF, y::Float64, decay::Float64)
    update!(o, x, y)
end

# L2Penalty and L1Penalty
function updateλ!(o::SGModel, o_l::SGModel, o_h::SGModel, x::AVecF, y::Float64, xtest, ytest, η::Float64, decay::Float64)
    # alter λ for o_l and o_h
    γ = η / (nobs(o) + 1) ^ decay
    o_l.penalty.λ = max(0.0, o_l.penalty.λ - γ)
    o_h.penalty.λ += γ

    # update all three models
    update!(o, x, y)
    update!(o_l, x, y)
    update!(o_h, x, y)

    # Find best model for test data
    ŷ = predict(o, xtest)
    ŷ_l = predict(o_l, xtest)
    ŷ_h = predict(o_h, xtest)
    v = vcat(rmse(ŷ_l, ytest), rmse(ŷ, ytest), rmse(ŷ_h, ytest))
    _, j = findmin(v)

    if j == 1 # o_l is winner
        o.penalty.λ = o_l.penalty.λ
        o_h.penalty.λ = o_l.penalty.λ
    elseif j == 2 # o is winner
        o_l.penalty.λ = o.penalty.λ
        o_h.penalty.λ = o.penalty.λ
    else # o_h is winner
        o_l.penalty.λ = o_h.penalty.λ
        o.penalty.λ = o_h.penalty.λ
    end
end

function update!(o::SGModelCV, x::AVecF, y::Float64)
    if nobs(o) < o.burnin
        update!(o.o, x, y)
        update!(o.o_l, x, y)
        update!(o.o_h, x, y)
    else
        updateλ!(o.o, o.o_l, o.o_h, x, y, o.xtest, o.ytest, o.η, o.decay)
    end
end

rmse(yhat, y) = mean(abs2(yhat - y))

#------------------------------------------------------------------------# state
statenames(o::SGModelCV) = [:β, :penalty, :nobs]
state(o::SGModelCV) = Any[coef(o), copy(o.o.penalty), nobs(o)]
whatisλ(o::SGModelCV) = o.o.penalty.λ

StatsBase.coef(o::SGModelCV) = coef(o.o)
StatsBase.nobs(o::SGModelCV) = nobs(o.o)
StatsBase.predict(o::SGModelCV, x) = predict(o.o, x)

function Base.show(io::IO, o::SGModelCV)
    println(io, "Cross-Validated SGModel:")
    show(o.o)
end



# Testing
if false
    function linearmodeldata(n, p)
        x = randn(n, p)
        β = (collect(1:p) - .5*p) / p
        y = x*β + randn(n)
        (β, x, y)
    end
    n,p = 10_000, 10
    β,x,y = linearmodeldata(n,p)

    o = OnlineStats.SGModel(p, penalty = OnlineStats.L2Penalty(.1), algorithm = OnlineStats.RDA())
    ocv = OnlineStats.SGModelCV(o, decay = .9)
    v = OnlineStats.tracefit!(ocv, 100, x, y)
    OnlineStats.traceplot(v, x -> vcat(OnlineStats.whatisλ(x)))
end