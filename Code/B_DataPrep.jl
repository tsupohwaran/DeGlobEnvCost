#=================================================================#
# Prepare data for the paper
# Date: March 2025
# Author: Wu Chengjun, Central University of Finance and Economics
# OS: MacOS 15.3.2
# Version: 1.10.9
#=================================================================#

#==================================================#
# Load packages and functions
# !!!Path must be redefined by users!!!
#==================================================#

cd("/Users/pohwaran/Doctorate/Paper/DeGlobEnvCost")
include("Function/DGEC_LoadPkg.jl")
include("Function/DGEC_Function.jl")

#==================================================#
# Step1: Prepare ADB-MRIO, WIOD-EA, and WITS tariff data for convenience
#==================================================#

# Prepare ADB-MRIO from .xlsx to .jld2 for convenience
for year in [17, 23]
    # replace missiong values with 0.0 for type stable
    @eval $(Symbol("adb_$year")) = Matrix{Float64}(coalesce.(XLSX.readdata("Data/ADB/ADB_Cou73_$(year).xlsx", "ADB MRIO $(year + 2000)", "E8:DMH2570"), 0.0))
end
@save "Data/ADB/ADB_Cou73_Sec35.jld2" adb_17 adb_23

# Prepare WIOD-EA
wiodFiles = readdir(joinpath(pwd(), "Data/WIOD/Raw"), join=true);
QᶠTemp = Matrix{Float64}[]
for k in [1:36; 38:44; 37]  # Reordering to match original logic
    wiodName = wiodFiles[k]
    wiodData = Matrix{Float64}(readxl(wiodName, "2016!B2:O59"))'
    # Append to array
    if isempty(QᶠTemp)
        QᶠTemp = wiodData
    else
        QᶠTemp = hcat(QᶠTemp, wiodData)
    end
end
@save "Data/WIOD/WIOD_16.jld2" QᶠTemp

# Prepare World Bank WITS tariff data
for year in 14:23
    tariff = DataFrame(load("Data/Tariff/Raw/Tariff_Importer_Sector_Exporter_$(year).dta"))
    @eval $(Symbol("τ_$year")) = permutedims(reshape(Float64.(tariff[!, end]), 44, 44, 19), [1, 3, 2]) ./ 100 # importer, sector, exporter  
end

@save "Data/Tariff/Tariff_importer_Sector_Exporter_14-23.jld2" τ_14 τ_15 τ_16 τ_17 τ_18 τ_19 τ_20 τ_21 τ_22 τ_23

#==================================================#
# Step2: Prepare data for the model
# 1. DataPrep(year) -> inputData, vars, params
# 2. Solve the equilibrium data
# 3. Elimate the deficit
#==================================================#

# Raw data
for year in [17, 23]
    inputData, vars, params = DataPrep(year)
    @save "Data/Model/ModelDataRaw_$year.jld2" inputData vars params
end

# Get the equilibrium data by solving the model with no shock 
@load "Data/Model/ModelDataRaw_17.jld2" inputData vars params
inputData, vars, params = SolveModel(inputData, vars, params, ones(size(params.τʲ)), ones(size(params.τʲ)); deficit=true, numer=2)
inputData, vars, params = SolveModel(inputData, vars, params, ones(size(params.τʲ)), ones(size(params.τʲ)); numer=2)
@save "Data/Model/ModelData_17.jld2" inputData vars params

#==================================================#
# Estimate the bilateral trade cost (symetric)
#==================================================#

@load "Data/Tariff/Tariff_importer_Sector_Exporter_14-23.jld2" τ_17 τ_23
τ̂ʲ = τ_23 ./ τ_17;
τ̂ʲ[τ̂ʲ.==Inf] .= 1.0
τ̂ʲ[isnan.(τ̂ʲ)] .= 1.0
@save "Data/Model/TariffShock_17-23.jld2" τ̂ʲ

for year in [17, 23]
    πʲ_local = load("Data/Model/ModelDataRaw_$year.jld2")["vars"].πʲ
    @eval $(Symbol("κʲ_$year")) = stack(($(πʲ_local)[:, i, :] .* $(πʲ_local)[:, i, :]' ./
                                         (diag($(πʲ_local)[:, i, :]) .* diag($(πʲ_local)[:, i, :])')) .^ -0.1 for i in axes($(πʲ_local), 2)) |>
                                  x -> permutedims(x, [1, 3, 2])
    @eval$(Symbol("κʲ_$year"))[isnan.($(Symbol("κʲ_$year")))] .= 1.0
    @eval$(Symbol("κʲ_$year"))[$(Symbol("κʲ_$year")).==Inf] .= 1.0
    @eval$(Symbol("κʲ_$year"))[$(Symbol("κʲ_$year")).==0.0] .= 1.0
end

κ̂ʲ_sym = κʲ_23 ./ κʲ_17; # 500 inf and 587 NaN elements
@save "Data/Model/TradeCostSym.jld2" κ̂ʲ_sym κʲ_17 κʲ_23

# Load Mni for year 17 to use as weights
Mni_17 = load("Data/Model/ModelDataRaw_17.jld2")["inputData"].Mni
for i = 1:44
    Mni_17[i, :, i] .= 0.0
end

# EU free trade 
for j = 17:43
    for t = 17:43
        Mni_17[j, :, t] .= 0.0
    end
end

weights = Mni_17 ./ sum(Mni_17, dims=(2, 3))
weights_world = Mni_17 ./ sum(Mni_17)
weights_eu = Mni_17[17:43, :, :] ./ sum(Mni_17[17:43, :, :])
for year in [17, 23]
    # Weighted average of τ
    @eval $(Symbol("τ_wgtav_$year")) = sumsqueeze($(Symbol("τ_$year")) .* weights, dims=(2, 3)) * 100
    @eval $(Symbol("τ_wgtav_world_$year")) = sum($(Symbol("τ_$year")) .* weights_world) * 100
    @eval $(Symbol("τ_wgtav_eu_$year")) = sum($(Symbol("τ_$year"))[17:43, :, :] .* weights_eu) * 100
    @eval $(Symbol("τ_wgtav_$year")) = [$(Symbol("τ_wgtav_world_$year")); $(Symbol("τ_wgtav_$year"))[9];
        $(Symbol("τ_wgtav_$year"))[16]; $(Symbol("τ_wgtav_eu_$year"))]
    # Weighted average of κ
    @eval $(Symbol("κʲ_wgtav_$year")) = sumsqueeze($(Symbol("κʲ_$year")) .* weights, dims=(2, 3))
    @eval $(Symbol("κʲ_wgtav_world_$year")) = sum($(Symbol("κʲ_$year")) .* weights_world)
    @eval $(Symbol("κʲ_wgtav_eu_$year")) = sum($(Symbol("κʲ_$year"))[17:43, :, :] .* weights_eu)
    @eval $(Symbol("κʲ_wgtav_$year")) = [$(Symbol("κʲ_wgtav_world_$year")); $(Symbol("κʲ_wgtav_$year"))[9];
        $(Symbol("κʲ_wgtav_$year"))[16]; $(Symbol("κʲ_wgtav_eu_$year"))]
end

for year in [17, 23]
    # Maximum τ
    @eval $(Symbol("τ_max_$year")) = dropdims(maximum($(Symbol("τ_$year")), dims=(2, 3)) * 100, dims=(2, 3))
    @eval $(Symbol("τ_max_world_$year")) = maximum($(Symbol("τ_$year"))) * 100
    @eval $(Symbol("τ_max_eu_$year")) = maximum($(Symbol("τ_$year"))[17:43, :, :]) * 100
    @eval $(Symbol("τ_max_$year")) = [$(Symbol("τ_max_world_$year")); $(Symbol("τ_max_$year"))[9];
        $(Symbol("τ_max_$year"))[16]; $(Symbol("τ_max_eu_$year"))]

    # Maximum κ
    @eval $(Symbol("κ_max_$year")) = dropdims(maximum($(Symbol("κʲ_$year")), dims=(2, 3)), dims=(2, 3))
    @eval $(Symbol("κ_max_world_$year")) = maximum($(Symbol("κʲ_$year")))
    @eval $(Symbol("κ_max_eu_$year")) = maximum($(Symbol("κʲ_$year"))[17:43, :, :])
    @eval $(Symbol("κ_max_$year")) = [$(Symbol("κ_max_world_$year")); $(Symbol("κ_max_$year"))[9];
        $(Symbol("κ_max_$year"))[16]; $(Symbol("κ_max_eu_$year"))]
end

dlnŵ, dlnp̂ᶠ, dlnÔʷ, dlnÔₙ, dlnÔᵉᵘ = SolveModel(inputData, vars, params, κ̂ʲ_sym, τ̂ʲ)
@save "Result/TradeCostWorld_17-23.jld2" dlnŵ dlnp̂ᶠ dlnÔʷ dlnÔₙ dlnÔᵉᵘ

#==================================================#
# Estimate the bilateral trade cost (asymetric)
#==================================================#

for year in [17, 23]
    πʲ_local = load("Data/Model/ModelDataRaw_$year.jld2")["vars"].πʲ
    @eval $(Symbol("πʲ_norm_$year")) = stack(reshape($(πʲ_local)[:, i, :] ./
                                       diag($(πʲ_local)[:, i, :])', 44 * 44) for i in axes($(πʲ_local), 2)) |>
                                       x -> reshape(x, 44 * 44 * 19)
    @eval $(Symbol("πʲ_norm_$year"))[$(Symbol("πʲ_norm_$year")).==Inf] .= 1.0
    @eval $(Symbol("πʲ_norm_$year"))[isnan.($(Symbol("πʲ_norm_$year")))] .= 1.0
    @eval $(Symbol("πʲ_norm_$year"))[$(Symbol("πʲ_norm_$year")).==0.0] .= 1.0
end

# Create a DataFrame with all combinations of sectors and countries
trade_df = DataFrame(
    sector=repeat(1:19, inner=44 * 44),
    exporter=repeat(repeat(1:44, inner=44), outer=19),
    importer=repeat(1:44, outer=19 * 44)
)

# Add πʲ_norm variables to the dataframe
trade_df.πʲ_norm_17 = πʲ_norm_17
trade_df.πʲ_norm_23 = πʲ_norm_23
dist_df = DataFrame(load("Data/CEPII/Distance.dta"))
asym_df = leftjoin(trade_df, dist_df, on=[:exporter, :importer])

# Run regressions and save results by sector
@load "Data/Model/TradeCostSym.jld2" κ̂ʲ_sym κʲ_17 κʲ_23
for year in [17, 23]
    κʲₙ = Matrix{Float64}[]
    for i in 1:19
        # Create the formula directly using string interpolation and Meta.parse
        formula = @eval @formula($(Meta.parse("log(πʲ_norm_$year) ~ log(dist + 1) + fe(exporter) + fe(importer)")))
        reg_result = reg(asym_df, formula, Vcov.robust(), subset=(asym_df.sector .== i), save=:all)
        feEx = unique(dropmissing(fe(reg_result)).fe_exporter)
        feIm = unique(dropmissing(fe(reg_result)).fe_importer)
        κʲₙTemp = exp.(-(feEx + feIm) ./ params.θʲ[i])'
        if isempty(κʲₙ)
            κʲₙ = κʲₙTemp
        else
            κʲₙ = vcat(κʲₙ, κʲₙTemp)
        end
    end
    
    # Store the κʲₙ for this year
    @eval $(Symbol("κʲₙ_$year")) = $κʲₙ

    # Calculate the κʲ
    @eval $(Symbol("κʲ_$year")) = $(Symbol("κʲ_$year")) .* (reshape($(Symbol("κʲₙ_$year")), 1, 19, 44) ./ reshape($(Symbol("κʲₙ_$year"))', 44, 19, 1)) .^ 0.5
end

κ̂ʲ_asym = κʲ_23 ./ κʲ_17
@save "Data/Model/TradeCostAsym.jld2" κ̂ʲ_asym κʲ_17 κʲ_23

#==================================================#
# Solve the model with asymetric trade cost
#==================================================#

include("Function/DGEC_Function.jl")

# Get the equilibrium data by solving the model with no shock 
@load "Data/Model/ModelDataRaw_17.jld2" inputData vars params
inputData, vars, params = SolveModel(inputData, vars, params, ones(size(params.τʲ)), ones(size(params.τʲ)); deficit=true, numer=3)
inputData, vars, params = SolveModel(inputData, vars, params, ones(size(params.τʲ)), ones(size(params.τʲ)); numer=3)
@save "Data/Model/ModelData_17.jld2" inputData vars params

# Conterfactual analysis
@load "Data/Model/ModelData_17.jld2" inputData vars params
@load "Data/Model/TradeCostAsym.jld2" κ̂ʲ_asym
@load "Data/Model/TariffShock_17-23.jld2" τ̂ʲ

# no change for non-trariff trade cost
# κ̂ʲ = (1 .+ params.τʲ .* τ̂ʲ) ./ (1 .+ params.τʲ); 
_, _, _, changes, check = SolveModel(inputData, vars, params, κ̂ʲ_asym, τ̂ʲ; numer = 2);

clipboard(changes.dlnÔʷ)
cliparray(changes.dlnÔₙ)