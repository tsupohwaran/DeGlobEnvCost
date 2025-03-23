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
dlnŵ, dlnp̂ᶠ = SolveModel(inputData, vars, params, ones(size(params.τʲ)); newData = true, displaySummary = true);


#==================================================#
# Estimate the bilateral trade cost (symetric)
#==================================================#



#==================================================#
# Estimate the bilateral trade cost (asymetric)
#==================================================#