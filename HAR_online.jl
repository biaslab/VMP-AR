using ForneyLab
import ARdata: daily_temperature, generate_data
import LinearAlgebra.I, LinearAlgebra.Symmetric
import ForneyLab: unsafeCov, unsafeMean
# order of AR model
ARorder = UInt16(10)
diagAR(dim) = Matrix{Float64}(I, dim, dim)
#coefs, x = generate_data(UInt64(10000), ARorder)
# Observations
x = daily_temperature("/Users/albertpod/Documents/Julia/VariationalBayes//daily-minimum-temperatures.csv", ARorder)
x = [reverse(x) for x in x]
y = [xi[1] for xi in x[2:end]] .+ rand()*0.000001
#y = x

# Building the model
g = FactorGraph()

# declare priors as random variables
@RV m_x_t_prev
@RV w_x_t_prev
@RV m_x_t
@RV w_x_t
@RV a_w_t
@RV b_w_t
@RV m_a_t
@RV w_a_t

@RV a ~ GaussianMeanPrecision(m_a_t, w_a_t)
@RV x_t_prev ~ GaussianMeanPrecision(m_x_t_prev, w_x_t_prev)
#@RV x_t ~ GaussianMeanPrecision(m_x_t, w_x_t)
#@RV x_t
@RV w ~ Gamma(a_w_t, b_w_t)
@RV x_t = AR(a, x_t_prev, w)
@RV n ~ GaussianMeanPrecision(0.0, 0.000001)
#@RV y_t = zeros(ARorder) + x_t
c = zeros(ARorder); c[1] = 1.0
@RV y_t = dot(c, x_t) + n
#GainEquality(y_t, x_t_prev, x_t, c)

# Placeholders for prior
placeholder(m_x_t_prev, :m_x_t_prev, dims=(ARorder,))
placeholder(w_x_t_prev, :w_x_t_prev, dims=(ARorder, ARorder))
#placeholder(m_x_t, :m_x_t, dims=(ARorder,))
#placeholder(w_x_t, :w_x_t, dims=(ARorder, ARorder))
placeholder(a_w_t, :a_w_t)
placeholder(b_w_t, :b_w_t)
placeholder(m_a_t, :m_a_t, dims=(ARorder,))
placeholder(w_a_t, :w_a_t, dims=(ARorder, ARorder))

# Placeholder for data
placeholder(y_t, :y_t)
#placeholder(x_t, :x_t, dims=(ARorder,))

ForneyLab.draw(g)

# Specify recognition factorization
q = RecognitionFactorization(a, x_t_prev, x_t, w, y_t, ids=[:A, :X_t_prev, :X_t, :W, :y_t])

# Inspect the subgraph for A
# ForneyLab.draw(q.recognition_factors[:A])

# Generate the variational update algorithms for each recognition factor
algo = variationalAlgorithm(q)

# Load algorithms
eval(Meta.parse(algo))
display(Meta.parse(algo))

# Define values for prior statistics
m_x_prev_0 = 0.5*rand(ARorder)
w_x_prev_0 = (10.0*diagAR(ARorder))
m_x_0 = 0.5*rand(ARorder)
w_x_0 = (10.0*diagAR(ARorder))
a_w_0 = 2
b_w_0 = 5
m_a_0 = 10.0*rand(ARorder)
w_a_0 = (10.0*diagAR(ARorder))

m_x_prev = Vector{Vector{Float64}}(undef, length(x))
w_x_prev = Vector{Array{Float64, 2}}(undef, length(x))
m_x = Vector{Vector{Float64}}(undef, length(x))
w_x = Vector{Array{Float64, 2}}(undef, length(x))
a_w = Vector{Float64}(undef, length(x))
b_w = Vector{Float64}(undef, length(x))
m_a = Vector{Vector{Float64}}(undef, length(x))
w_a = Vector{Array{Float64, 2}}(undef, length(x))

m_x_t_prev_min = m_x_prev_0
w_x_t_prev_min = w_x_prev_0
m_x_t_min = m_x_0
w_x_t_min = w_x_0
a_w_t_min = a_w_0
b_w_t_min = b_w_0
m_a_t_min = m_a_0
w_a_t_min = w_a_0

marginals = Dict()
n_its = 30
datasetRatio = 30

for t = 1:length(y)
    println("Observation # ", t)
    marginals[:a] = ProbabilityDistribution(Multivariate, GaussianMeanPrecision, m=m_a_t_min, w=w_a_t_min)
    marginals[:x_t_prev] = ProbabilityDistribution(Multivariate, GaussianMeanPrecision, m=m_x_t_prev_min, w=w_x_t_prev_min)
    marginals[:x_t] = ProbabilityDistribution(Multivariate, GaussianMeanPrecision, m=m_x_t_min, w=w_x_t_min)
    marginals[:w] = ProbabilityDistribution(Univariate, Gamma, a=a_w_t_min, b=b_w_t_min)
    for i = 1:n_its
        #println("Iteration # ", i)
        global m_x_t_prev_min, w_x_t_prev_min, m_x_t_min, w_x_t_min,
               a_w_t_min, b_w_t_min, m_a_t_min, w_a_t_min

        data = Dict(:y_t   => y[t],
                    :m_a_t => m_a_t_min,
                    :w_a_t => w_a_t_min,
                    :m_x_t_prev => m_x_t_prev_min,
                    :w_x_t_prev => w_x_t_prev_min,
                    #:m_x_t => m_x_t_min,
                    #:w_x_t => w_x_t_min,
                    :a_w_t => a_w_t_min,
                    :b_w_t => b_w_t_min)
        #display(data)
        stepA!(data, marginals)
        stepW!(data, marginals)
        #stepX_t!(data, marginals)
        stepX_t_prev!(data, marginals)
        # Extract posterior statistics
        #display(marginals[:a].params[:xi])
        #print(typeof(marginals[:a]))
        m_a[t] = unsafeMean(marginals[:a])
        w_a[t] = unsafeCov(marginals[:a])
        #display(mean(marginals[:x_t_min]))
        #μ, Σ = marginals[:a].params[:xi], marginals[:a].params[:w]
        #display(unsafeCov(marginals[:x_t]))
        #m_x[t] = marginals[:x_t].params[:xi]
        #w_x[t] = (Symmetric(marginals[:x_t].params[:w]))^-1
        m_x_prev[t] = unsafeMean(marginals[:x_t_prev])
        w_x_prev[t] = unsafeCov(marginals[:x_t_prev])
        a_w[t] = marginals[:w].params[:a]
        b_w[t] = marginals[:w].params[:b]
        # Store to buffer
        m_a_t_min = m_a[t]
        w_a_t_min = w_a[t]
        m_x_t_prev_min = m_x_prev[t]
        w_x_t_prev_min = w_x_prev[t]
        #m_x_t_min = m_x[t]
        #w_x_t_min = w_x[t]
        a_w_t_min = a_w[t]
        b_w_t_min = b_w[t]
    end
    #display(marginals)
end
