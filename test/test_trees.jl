@testset "FastTree" begin 
    data = rand(10^4, 5), rand(1:4, 10^4)
    @testset "FastNode" begin 
        o = FastNode(5, 4)
        series(data, o)
        @test nobs(o) == 10^4
        @test OnlineStats.nkeys(o) == 4 
        @test OnlineStats.nvars(o) == 5
        c = data[2]
        trueprobs = [sum(c .== 1), sum(c .== 2), sum(c .== 3), sum(c .== 4)] ./ length(c)
        @test probs(o) == trueprobs
        @test classify(o) == findmax(probs(o))[2]
    end
    o = FastTree(5, 4; splitsize=200)
    s = series(data, o)
    yhat = classify(o, data[1])
    @test mean(yhat .== data[2]) > .25
    @test yhat' == classify(o, data[1]', Cols())
    @test OnlineStats.nkeys(o) == 4
    @test OnlineStats.nvars(o) == 5

    @testset "FastForest" begin 
        o = FastForest(5, 4; splitsize=500)
        s = series(data, o)
        yhat = classify(o, data[1])
        votes = predict(o, data[1])
        @test size(votes) == (10^4, 4)
        @test predict(o, data[1])' ≈ predict(o, data[1]', Cols())
        @test classify(o, data[1])' ≈ classify(o, data[1]', Cols())
        @test length(predict(o, randn(5))) == 4
        @test classify(o, randn(5)) in 1:4
    end
end


@testset "NBTree" begin 
    data = rand(10^4, 5), rand(1:4, 10^4)
    series(data, NBTree(Int, 5Hist(20); splitsize=10))
end