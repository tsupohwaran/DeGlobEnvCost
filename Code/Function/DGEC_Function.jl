#==================================================#
# The main function of the paper
# Date: March 2025
# Author: Wu Chengjun, Central University of Finance and Economics
# OS: MacOS 15.3.2
# Version: 1.10.9
#==================================================#

# For convenience. This function is used to sum over the specified dimensions and drop them.
sumsqueeze(A; dims) = dropdims(sum(A, dims=dims), dims=dims)

# For convenience. This function is used to check if there are any invalid elements (NaN, Missing, Inf) in the array and
# return the positions of these elements.
function CheckElements(array)
    # Check for NaN elements
    nan_mask = isnan.(array)
    nan_count = sum(nan_mask)
    
    # Find positions of NaN elements
    nan_positions = findall(nan_mask)
    
    # Check for missing elements
    missing_mask = ismissing.(array)
    missing_count = sum(missing_mask)
    
    # Check for Inf elements
    inf_mask = isinf.(array)
    inf_count = sum(inf_mask)
    
    # Find positions of Inf elements
    inf_positions = findall(inf_mask)
    
    # Print results
    if nan_count > 0
        println("Found $nan_count NaN elements in the array")
        println("NaN positions: $nan_positions")
    else
        println("No NaN elements found in the array")
    end
    
    if missing_count > 0
        println("Found $missing_count missing elements in the array")
    else
        println("No missing elements found in the array")
    end
    
    if inf_count > 0
        println("Found $inf_count Inf elements in the array")
        println("Inf positions: $inf_positions")
    else
        println("No Inf elements found in the array")
    end
    
    return (nan_count == 0 && missing_count == 0 && inf_count == 0)
end

# Prepare data for the model 
function DataPrep(year::Int64)

    #=================================================================#
    # IO parameter: ADB-MRIO current price version
    # Link: https://kidb.adb.org/globalization
    # We mapping ADB-MRIO to 44 countries (N) and 19 sectors (J+1)
    # 18 goods sectors including "other mining" (to be split out of fossil later) plus 1 fossil fuel sector
    # Variable suffix: J: goods sector; F: fossil fuel; H: household 
    #=================================================================#

    # Economic environment
    J = 19 # number of sectors
    N = 44 # number of countries
    K = 3 # kinds of fossil fuels

    # Locate the position of various data in ADB-MRIO
    J_old = 35 # old number of sectors
    N_old = 73 # old number of countries
    vaStart = 2 # start position of value added
    vaEnd = 7 # end position of value added
    go = 8 # position of gross output
    final = 5 # position of final demand

    # Load data
    adb = load("Data/ADB/ADB_Cou73_Sec35.jld2")["adb_$(year)"]
    sec35to20 = Matrix{Float64}(XLSX.readdata("Data/ADB/CouSecConvert_ADB.xlsx", "sec35to20", "B2:U36"))
    cou73to44 = Matrix{Float64}(XLSX.readdata("Data/ADB/CouSecConvert_ADB.xlsx", "cou73to44", "C2:AT74"))

    # Intermediate consumption
    interADB = adb[1:J_old*N_old, 1:J_old*N_old]
    interRaw = reshape(sec35to20' * reshape(interADB, J_old, N_old * J_old * N_old), (J + 1) * N_old * J_old, N_old) * cou73to44 |>
               x -> reshape(permutedims(reshape(x, J + 1, N_old, J_old, N), [2, 1, 4, 3]), N_old * (J + 1) * N, J_old) * sec35to20 |>
                    x -> cou73to44' * reshape(x, N_old, (J + 1) * N * (J + 1)) |>
                         x -> permutedims(reshape(x, N, (J + 1), N, (J + 1)), [2, 1, 4, 3])

    # Final consumption
    finalADB = adb[1:J_old*N_old, J_old*N_old+1:J_old*N_old+final*N_old]
    finalRaw = sec35to20' * reshape(sum(reshape(finalADB, J_old, N_old, final, N_old), dims=3), J_old, N_old * N_old) |>
               x -> reshape(x, (J + 1) * N_old, N_old) * cou73to44 |>
                    x -> reshape(permutedims(reshape(x, J + 1, N_old, N), [1, 3, 2]), (J + 1) * N, N_old) * cou73to44 |>
                         x -> permutedims(reshape(x, J + 1, N, N), [1, 3, 2])

    # Value added
    vaADB = sum(adb[J_old*N_old+vaStart:J_old*N_old+vaEnd, 1:J_old*N_old], dims=1)
    vaRaw = sec35to20' * reshape(vaADB, J_old, N_old) * cou73to44

    # Goss output
    goADB = adb[J_old*N_old+go, 1:J_old*N_old]
    goRaw = sec35to20' * reshape(goADB, J_old, N_old) * cou73to44

    # Check the balance of the IO table
    # Each row in checkADB should be 0
    goRow = sum(reshape(interRaw, (J + 1) * N, (J + 1) * N), dims=2) + sum(reshape(finalRaw, (J + 1) * N, N), dims=2)
    goCol = sum(reshape(interRaw, (J + 1) * N, (J + 1) * N), dims=1)' + reshape(vaRaw, (J + 1) * N)
    checkADB = [sum!([1.0], interRaw) - sum!([1.0], adb[1:J_old*N_old, 1:J_old*N_old]);
        sum!([1.0], finalRaw) - sum!([1.0], adb[1:J_old*N_old, J_old*N_old+1:J_old*N_old+final*N_old]);
        sum!([1.0], vaRaw) - sum!([1.0], sum(adb[J_old*N_old+vaStart:J_old*N_old+vaEnd, 1:J_old*N_old], dims=1));
        maximum(maximum(goRow - goCol));
        sum!([1.0], goRaw) - sum!([1.0], adb[J_old*N_old+go, 1:J_old*N_old])
    ]

    # Drop ref sector which accounts for the fossil fuels
    interJ = interRaw[1:J, :, 1:J, :]
    vaJ = vaRaw[1:J, :]
    goJ = goRaw[1:J, :]

    # Warning: sector 2 includes fossil fuels and other mining (om) now
    # om's factor share need to be drawn from GTAP
    # goods sector's factor share for om need to be recalculated from GTAP

    #=================================================================#
    # Split input from mining sector into fossil fuels and other mining (om) using GTAP11 (2017)
    # Link: https://www.gtap.agecon.purdue.edu/databases/v11/
    #=================================================================#

    # Mapping from GTAP11 to our economic environment (44 economies and 19 sectors)
    cou160to44 = Matrix{Float64}(XLSX.readdata("Data/GTAP/CouSecConvert_GTAP.xlsx", "cou160to44", "C2:AT161"))
    sec68to21 = Matrix{Float64}(XLSX.readdata("Data/GTAP/CouSecConvert_GTAP.xlsx", "sec68to21", "B2:V69"))

    # Load GTAP11 data for share of fossil fuels input in mining input (68 sectors * 160 economies)
    miningInputRawGTAP = stack(Matrix{Float64}(XLSX.readdata("Data/GTAP/InputFromMining_2017_Cou_Ind.xlsx", "$(i)", "B3:FE70")) +
                               Matrix{Float64}(XLSX.readdata("Data/GTAP/InputFromMining_2017_Cou_Ind.xlsx", "$(i)", "B74:FE141"))
                               for i in ["coal", "oil", "natgas", "othertmining"]) # 68 * 160 * 4
    miningInputGTAP = reshape(sec68to21' * reshape(miningInputRawGTAP, 68, 160 * 4), (J + 2), 160, 4) |>
                      x -> reshape(permutedims(x, [3, 1, 2]), 4 * (J + 2), 160) * cou160to44 |>
                           x -> reshape(x, 4, J + 2, N) # 4, J + 2, N
    FInputShare = dropdims(sum(miningInputGTAP[1:3, :, :], dims=1) ./ sum(miningInputGTAP, dims=1), dims=1)[1:J+1, :]
    FInputShare[isnan.(FInputShare)] .= 0.0  # Replace NaN values with 0.0 in the miningShare matrix

    # Expenditure in fossil fuels comes from raw fossil fuels in mining sector and refined fossil fuel sector
    miningInputJH = [sumsqueeze(interRaw[2, :, 1:J, :], dims=1);
        sum(finalRaw[2, :, :], dims=1)]
    refInputJH = [sumsqueeze(interRaw[J+1, :, 1:J, :], dims=1);
        sum(finalRaw[J+1, :, :], dims=1)]
    FInputJH = miningInputJH .* FInputShare + refInputJH

    #=================================================================#
    # Factor share for goods sector
    # ξʲ: share of value added in each sector j
    # ξᶠ : share of sector j's spending on fossil fuel f.
    # ξʲᵏ: share of sector k's spending on sector j's goods
    #=================================================================#

    # ξʲ: share of value added in om needs to be drawn from GTAP
    ξʲ = vaJ ./ goJ
    # om's spending share on goods sector needs to be drawn from GTAP
    inputForOM = sec68to21[1:65, 1:size(sec68to21, 2).!=J+1]' *
                 (Matrix{Float64}(XLSX.readdata("Data/GTAP/InputForOM_2017_Cou_Ind.xlsx", "intermediate", "B3:FE67")) +
                  Matrix{Float64}(XLSX.readdata("Data/GTAP/InputForOM_2017_Cou_Ind.xlsx", "intermediate", "B71:FE135"))) *
                 cou160to44 # J, N
    vaOM = cou160to44' * Matrix{Float64}(XLSX.readdata("Data/GTAP/InputForOM_2017_Cou_Ind.xlsx", "va", "B2:B161"))
    ξʲ[2, :] = 1 ./ (1 .+ sum(inputForOM, dims=1) ./ vaOM')

    # ξʲᵏ
    # share on om needs to be recalculated from GTAP
    xiJJ = reshape(sum(reshape(interJ, J, N, J * N), dims=2) ./ sum(reshape(interJ, J, N, J * N), dims=(1, 2)), J, J, N) # J, J, N
    omInputShare = (miningInputGTAP[4, :, :]./sumsqueeze(miningInputGTAP, dims=1))[1:J+1, :]
    omInputShare[isnan.(omInputShare)] .= 1.0
    xiJJ[2, :, :] = xiJJ[2, :, :] .* omInputShare[1:J, :]
    xiJJ[:, 2, :] = inputForOM[1:J, :] ./ sum(inputForOM[1:J, :], dims=1)
    xiJJ = xiJJ ./ sum(xiJJ, dims=1)
    ξFJ = FInputJH[1:J, :] ./ goJ # share of sector j's spending on total fossil fuels
    ξFJ[2, :] = inputForOM[J+1, :]' ./ (sum(inputForOM, dims=1) + vaOM') # share of om's spending on fossil fuels
    ξʲᵏ = permutedims(reshape(1 .- ξFJ .- ξʲ, 1, size(ξFJ)...) .* xiJJ, [2, 3, 1]) # input, economy, output 

    # ξᶠ = pᶠ * Qᶠ / sum(pᶠ * Qᶠ) * ξFJ
    # Quantity of fossil fuels consumption by economies-sectors (Qᶠ) can be drwan from WIOD-EA
    # Link: https://joint-research-centre.ec.europa.eu/scientific-activities-z/economic-environmental-and-social-effects-globalisation_en
    # Price of fossil fuels (pᶠ) can be drawn from World Bank. 
    # Link: https://thedocs.worldbank.org/en/doc/5d903e848db1d1b83e0ec8f744e55570-0350012021/related/CMO-Historical-Data-Annual.xlsx
    # Qᶠ
    @load "Data/WIOD/WIOD_16.jld2" QᶠTemp
    cou44to44 = Matrix{Float64}(XLSX.readdata("Data/WIOD/CouSecConvert_WIOD.xlsx", "cou44to44", "C2:AT45"))
    sec57to21 = Matrix{Float64}(XLSX.readdata("Data/WIOD/CouSecConvert_WIOD.xlsx", "sec57to21", "B2:V58"))
    QᶠTemp = reshape(QᶠTemp, 14, 58, N)[:, 1:end.!=57, :] # 57th is total consumption
    Qᶜ = QᶠTemp[1, :, :] # coal
    Qᵒ = QᶠTemp[2, :, :] + QᶠTemp[4, :, :] + QᶠTemp[5, :, :] + QᶠTemp[6, :, :] # oil
    Qᵍ = QᶠTemp[8, :, :] # gas
    Qᶠ = sec57to21' * reshape([Qᶜ; Qᵒ; Qᵍ], 57, K * N) |>
         x -> reshape(x, (J + 2) * K, N) * cou44to44 |>
              x -> permutedims(reshape(x, J + 2, K, N), [2, 1, 3])[:, 1:end.!=J+1, :] # K, J + 1, N
    # pᶠ
    # unit: mmBtu/USD
    # coal: 1 mt = 27.78 mmBtu (https://www.iea.org/data-and-statistics/data-tools/unit-converter)
    # oil: 1 bbl = 5.8 mmBtu (see attachment)
    # gas: 1 mmBtu = 1 mmBtu
    pᶠTemp = Matrix{Float64}(XLSX.readdata("Data/Energy/EnergyPrice_60-24.xlsx", "Annual Prices (Nominal)", "B65:J65"))
    pᶠ = [mean(pᶠTemp[5:6]) / 27.78; mean(pᶠTemp[1:4]) / 5.8; mean(pᶠTemp[7:9])]
    ξᶠʲ = (pᶠ.*Qᶠ./sum(pᶠ .* Qᶠ, dims=1))[:, 1:end-1, :] .* reshape(ξFJ, 1, size(ξFJ)...) # K, J, N

    #=================================================================#
    # Factor share for household sector (α)
    # αʲ: share of household's spending on each sector j
    # αᶠ : share of household's spending on fossil fuel f.
    #=================================================================#

    # αʲ
    finalTotal = sumsqueeze(finalRaw, dims=(1, 2))
    finalJ = sumsqueeze(finalRaw[1:J, :, :], dims=2)
    finalJ[2, :] = (finalJ[2, :] .* omInputShare[J+1, :])'
    finalF = sum(finalRaw[J+1, :, :], dims=1)' + sum(finalRaw[2, :, :], dims=1)' .* FInputShare[end, :]
    αʲ = finalJ ./ finalTotal'

    # αᶠ
    αᶠ = (pᶠ.*Qᶠ./sum(pᶠ .* Qᶠ, dims=1))[:, end, :] .* (finalF ./ finalTotal)' # K, N

    # update α
    α = cat(αʲ, αᶠ, dims=1) |> x -> x ./ sum(x, dims=1) # J + K, N
    αʲ = α[1:J, :]
    αᶠ = α[J+1:end, :]

    #=================================================================#
    # To calculate bilateral trade share (πʲ), we need bilateral expenditure (Xni)
    # Xni = Mni * (1 + τ)
    # Mni: bilateral trade flow from i to n; τ: bilateral sectoral tariff
    # Bilateral sectoral tariff (τ) can be drawn from World Bank WITS
    # Link: https://wits.worldbank.org/WITS/WITS/AdvanceQuery/TariffAndTradeAnalysis/AdvancedQueryDefinition.aspx?Page=TariffandTradeAnalysis
    #=================================================================#

    # Mni: imported by goods sector and household
    Mni = permutedims(sumsqueeze(interJ, dims=3), [3, 1, 2]) +
          permutedims(finalRaw[1:J, :, :], [3, 1, 2]) # importer, sector, exporter

    # Use GTAP11 data to seperate other mining from mining
    imMining = stack(cou160to44' * Matrix{Float64}(XLSX.readdata("Data/GTAP/ImportFromMining_2017_Cou_Cou.xlsx", "$(i)", "B2:FE161") * cou160to44)
                     for i in ["Coal", "Oil", "Gas", "OM"]) |>
               x -> permutedims(x, [3, 1, 2]) # 4, N, N
    imMiningShare = imMining[4, :, :] ./ sumsqueeze(imMining, dims=1)
    imMiningShare[isnan.(imMiningShare)] .= 1.0

    domMining = stack(sum(Matrix{Float64}(XLSX.readdata("Data/GTAP/InputFromMining_2017_Cou_Ind.xlsx", "$(i)", "B3:FE70") * cou160to44), dims=1)
                      for i in ["coal", "oil", "natgas", "othertmining"]) |>
                x -> dropdims(x, dims=1)' # 4, N
    domMiningShare = domMining[4, :] ./ sum(domMining, dims=1)' # N, 1
    for i in 1:N
        for j in 1:J
            if i == j
                imMiningShare[i, j] = domMiningShare[i]
            end
        end
    end
    Mni[:, 2, :] = Mni[:, 2, :] .* imMiningShare

    # Expenditure of n from i (Xni)
    τʲ = load("Data/Tariff/Tariff_Importer_Sector_Exporter_14-23.jld2")["τ_$(year)"]
    Xni = Mni .* (1 .+ τʲ)
    πʲ = Xni ./ sum(Xni, dims=3) # importer, sector, exporter

    # Update gross output (Yʲ) = ∑ₙ Xni / (1 + τ)
    Yʲ = sumsqueeze(Mni, dims=1) # J, N 

    #=================================================================#
    # Total income (In) = Labor income (Inˡ) + Fossil fuel endowment (Inᶠ) + Tariff revenue (Inᵗ) - Deficit (D)
    # D = Goods trade deficit (Dʲ) + Fossil fuel trade deficit (Dᶠ)
    #=================================================================#

    # Update Inˡ by gross output and value added share
    Inˡ = vec(sum(Yʲ .* ξʲ, dims=1))

    # To get Inᶠ, we assume that each economy owns constant share (Ξᶠ) of world's fossil fuel endowment
    # Ξᶠ: share of fossil fuel production in world
    # Link: https://www.eia.gov/international/data/world
    Ξᶠ = Matrix{Float64}(XLSX.readdata("Data/Energy/FossilProd_80-23.xlsx", "$(year + 2000)", "C2:E45"))' # K, N
    Inᶠ = Ξᶠ .* (sumsqueeze(reshape(Yʲ, 1, size(Yʲ)...) .* ξᶠʲ, dims=(2, 3)) + αᶠ * finalTotal) # K, N

    # Inᵗ
    Inᵗ = sumsqueeze(Mni .* τʲ, dims=(2, 3))

    # D
    Dʲ = sumsqueeze(Mni, dims=3)' - sumsqueeze(Mni, dims=1)
    Dᶠ = sumsqueeze(reshape(Yʲ, 1, size(Yʲ)...) .* ξᶠʲ, dims=2) - Inᶠ
    D = vec(sum(Dʲ, dims=1) + sum(Dᶠ, dims=1))

    # Total income
    In = Inˡ + vec(sum(Inᶠ, dims=1)) + Inᵗ - D

    #=================================================================#
    # Emission (Oₙ) comes from conbustion of fossil fuels (unit: MMtonnes CO₂)
    # Oʲ = ∑ᶠ(Yʲ * ξᶠʲ / pᶠ * νᶠʲₙ) 
    # νᶠʲ: emission factor of fossil fuel f in sector j for economy n
    #=================================================================#

    # Step 1: get νᶠ from EIA
    # Link: https://www.eia.gov/international/data/world
    νᶠ = Matrix{Float64}(XLSX.readdata("Data/Emission/FossilEmi_80-23.xlsx", "$(year + 2000)", "C2:E45"))' ./
         Matrix{Float64}(XLSX.readdata("Data/Emission/FossilConsum_80-23.xlsx", "$(year + 2000)", "C2:E45"))' # K, N

    # Replace NaN elements in νᶠ with the mean of non-NaN values in the same row
    for k in axes(νᶠ, 1)
        non_nan_values = filter(!isnan, νᶠ[k, :])
        row_mean = mean(non_nan_values)
        for n in axes(νᶠ, 2)
            if isnan(νᶠ[k, n])
                νᶠ[k, n] = row_mean
            end
        end
    end

    # Update fossil fuel consumption by sectors and household
    Xᶠʲʰ = cat(reshape(Yʲ, 1, size(Yʲ)...) .* ξᶠʲ, reshape(In' .* αᶠ, K, 1, N); dims=2) # K, J + 1, N
    OʲʰTemp = sumsqueeze(Xᶠʲʰ ./ pᶠ .* reshape(νᶠ, K, 1, N), dims=1) # J + 1, N
    OₙTemp = sumsqueeze(OʲʰTemp, dims=1)

    # Step 2: adjust νᶠ to make emission of each economy calculated by our data equal to their real emission from EIA
    # Link: https://www.eia.gov/international/data/world
    Oₙ = sumsqueeze(Matrix{Float64}(XLSX.readdata("Data/Emission/FossilEmi_80-23.xlsx", "$(year + 2000)", "C2:E45")), dims=2)
    νᶠ = νᶠ .* (Oₙ ./ OₙTemp)'

    # Step 3: adjust νᶠʲ to make sectoral emission share calculated by our data equal to the real from OECD
    # Link: https://www.oecd.org/en/data/datasets/greenhouse-gas-footprint-indicators.html
    OʲʰShareTemp = OʲʰTemp ./ sum(OʲʰTemp, dims=1) # J + 1, N
    OʲʰShareTemp[OʲʰShareTemp.==0.0] .= 1.0
    if year > 20
        OʲʰShare = Matrix{Float64}(XLSX.readdata("Data/Emission/Emission_Sec_Cou_95-20.xlsx", "2020", "C2:C881")) |>
                   x -> reshape(x, J + 1, N) |>
                        x -> x ./ sum(x, dims=1) # J + 1, N
    else
        OʲʰShare = Matrix{Float64}(XLSX.readdata("Data/Emission/Emission_Sec_Cou_95-20.xlsx", "$(year + 2000)", "C2:C881")) |>
                   x -> reshape(x, J + 1, N) |>
                        x -> x ./ sum(x, dims=1) # J + 1, N
    end
    νᶠʲ = reshape(νᶠ, K, 1, N) .* reshape(OʲʰShare ./ OʲʰShareTemp, 1, J + 1, N)
    Oʲʰ = sumsqueeze(Xᶠʲʰ ./ pᶠ .* νᶠʲ, dims=1) # J + 1, N

    #=================================================================#
    # Save data
    #=================================================================#

    # Data refers to those that are not needed for model solving but are required for calculating relative changes. 
    inputData = (; Mni, Yʲ, In, Oʲʰ)

    # Variables refers to those that needed for model solving and may be changed.
    vars = (; πʲ, Inˡ, Inᶠ, pᶠ)

    # Parameter
    ηᶠ = [3; 0.25; 0.6] # elasticity of fossil fuels supply
    θʲ = 5.0 * ones(J) # trade elasticity
    params = (; ξʲ, ξʲᵏ, ξᶠʲ, αʲ, αᶠ, # IO
        τʲ, D, # trade
        θʲ, ηᶠ, # elasticity
        νᶠʲ, # emission factor
        J, N, K # economic environment
    )

    return inputData, vars, params
end

# Generic function for convergence
function Converge(UpdateRule::Function, init::Array;
    tol=1e-6, maxIter=1e3,
    damp=0.4,
    power=false,
    displayGap=false,
    displaySummary=false)

    # Initialize the variables
    iter = 0
    XDiff = 1.0
    X = init
    newX = similar(X)

    # Start the loop
    while (iter < maxIter) && (XDiff > tol)
        iter += 1
        newX = UpdateRule(X)
        XDiff = maximum(abs.(newX .- X))
        X = power ? damp * X + (1 - damp) * X .* (newX ./ X) .^ 0.5 : damp * X .+ (1 - damp) * newX

        if displayGap
            println("Iteration: $iter, Gap: $XDiff")
        end
    end

    if displaySummary
        if iter < maxIter
            println("Successful convergence in $iter iterations.")
        else
            println("Maximum number of iterations reached.")
        end
    end

    return X
end

# Solve the equilibrium
function SolveModel(inputData::NamedTuple, vars::NamedTuple, params::NamedTuple, 
    κ̂ʲ::Array{Float64,3}, τ̂ʲ::Array{Float64,3}; 
    deficit=false,
    updateData=false, damp=0.8, tol=1e-6, maxIter=1e3, power=false,
    displayGap=false, displaySummary=false)

    # unpack the data
    (; Mni, Yʲ, In, Oʲʰ) = inputData
    (; πʲ, Inˡ, Inᶠ, pᶠ) = vars
    (; ξʲ, ξʲᵏ, ξᶠʲ, αʲ, αᶠ, τʲ, D, θʲ, ηᶠ, νᶠʲ, J, N, K) = params
    if deficit == false
        D = zeros(N)
    end

    # initial guess
    ŵ = ones(N)
    p̂ᶠ = ones(K)
    X₀ = hcat(ŵ, repeat(p̂ᶠ, 1, N)')

    # update rule
    function UpdateRule(X₀)
        ŵ₀ = X₀[:, 1]
        p̂ᶠ₀ = X₀[1, 2:end]

        # solve p̂ʲ, ĉ when we have ŵ, p̂ᶠ
        p̂ʲ, ĉʲ = PriceFunc(ŵ₀, p̂ᶠ₀, κ̂ʲ, ξʲ, ξʲᵏ, ξᶠʲ, πʲ, θʲ, J, N; damp=0.0)

        # update τ, π, In when we have p̂ʲ, ĉʲ
        τʲ′ = τʲ .* τ̂ʲ
        πʲ′ = πʲ .* (κ̂ʲ .* reshape(ĉʲ, 1, size(ĉʲ)...) ./ reshape(p̂ʲ', N, J, 1)) .^ reshape(-θʲ, 1, J, 1)
        Inˡ′ = Inˡ .* ŵ₀
        Inᶠ′ = Inᶠ .* p̂ᶠ₀ .^ (1 .+ ηᶠ)

        # solve Xʲ, Yʲ when we have p̂ʲ, ĉ
        Xʲ′, Yʲ′, In′, Mni′ = OutputFunc(ξʲᵏ, αʲ, πʲ′, τʲ′, Inˡ′, Inᶠ′, D, J, N)

        # new ŵ, p̂ᶜ
        ŵ₁ = sumsqueeze(ξʲ .* Yʲ′, dims = 1) ./ Inˡ
        # ŵ₁ = ŵ₁ ./ ŵ₁[N] # normalize RoW to 1
        # ŵ₁ = ŵ₁ ./ mean(ŵ₁)
        ŵ₁ = ŵ₁ ./ mean(In′)
        p̂ᶠ₁ = ((sumsqueeze(ξᶠʲ .* reshape(Yʲ′, 1, size(Yʲ)...), dims = (2, 3)) + αᶠ * In′) ./
                sum(Inᶠ, dims=2)) .^ (1 ./ (1 .+ ηᶠ))

        # check market clearing condition
        # check = CheckResult(J, N, K, ŵ₁, Xʲ′, Yʲ′, In′, Inˡ, Inˡ′, Inᶠ′, ξʲ, ξʲᵏ, ξᶠ, D, π′, τ′)
        X₁ = hcat(ŵ₁, repeat(p̂ᶠ₁, 1, N)')
        return X₁, τʲ′, πʲ′, Inˡ′, Inᶠ′, Xʲ′, Yʲ′, In′, Mni′
    end

    # convergence
    X = Converge(x -> UpdateRule(x)[1], X₀;
        tol=tol, maxIter=maxIter, damp=damp, power=power,
        displayGap=displayGap, displaySummary=displaySummary)
    X, τʲ′, πʲ′, Inˡ′, Inᶠ′, Xʲ′, Yʲ′, In′, Mni′ = UpdateRule(X)
    ŵ = X[:, 1]
    p̂ᶠ = X[1, 2:end]

    pᶠ′ = p̂ᶠ .* pᶠ
    Xᶠʲʰ′ = cat(reshape(Yʲ′, 1, size(Yʲ′)...) .* ξᶠʲ, reshape(In′' .* αᶠ, K, 1, N); dims=2)
    Oʲʰ′ = sumsqueeze(Xᶠʲʰ′ ./ pᶠ′ .* νᶠʲ, dims=1)
    Ôₙ = vec(sum(Oʲʰ′, dims = 1) ./ sum(Oʲʰ, dims = 1))
    Ôᵉᵘ = sum(Oʲʰ′[:, 17:43]) ./ sum(Oʲʰ[:, 17:43])
    Ôʷ = sum(Oʲʰ′) ./ sum(Oʲʰ)

    dlnÔₙ = (Ôₙ .- 1) * 100
    dlnÔᵉᵘ = (Ôᵉᵘ .- 1) * 100
    dlnÔʷ = (Ôʷ .- 1) * 100
    dlnŵ = (ŵ .- 1) * 100
    dlnp̂ᶠ = (p̂ᶠ .- 1) * 100

    if updateData == 1
        Mni = Mni′
        Yʲ = Yʲ′
        In = In′
        Oʲʰ = Oʲʰ′
        πʲ = πʲ′
        Inˡ = Inˡ′
        Inᶠ = Inᶠ′
        pᶠ = pᶠ′
        τʲ = τʲ′
        inputData = (; Mni, Yʲ, In, Oʲʰ)
        vars = (; πʲ, Inˡ, Inᶠ, pᶠ)
        params = (; ξʲ, ξʲᵏ, ξᶠʲ, αʲ, αᶠ, τʲ, D, θʲ, ηᶠ, νᶠʲ, J, N, K)

        return inputData, vars, params
    else
        return dlnŵ, dlnp̂ᶠ, dlnÔʷ, dlnÔₙ, dlnÔᵉᵘ
    end
end

# Solve the price inner loop
function PriceFunc(ŵ, p̂ᶠ, κ̂ʲ, ξʲ, ξʲᵏ, ξᶠʲ, πʲ, θʲ, J, N;
    tol=1e-8,
    maxIter=1e3,
    damp=0.0,
    power=false,
    displayGap=false,
    displaySummary=false)

    # initial guess
    p̂ʲ₀ = ones(J, N)

    # update rule
    function UpdateRule(p̂ʲ₀)
        lnĉ = ξʲ .* log.(ŵ)' + stack(ξʲᵏ[:, i, :] * log.(p̂ʲ₀[:, i]) for i in 1:N) + sumsqueeze(ξᶠʲ .* log.(p̂ᶠ), dims=1)
        ĉ = exp.(lnĉ)
        p̂ʲ₁ = sumsqueeze(πʲ .* (reshape(ĉ, 1, size(ĉ)...) .* κ̂ʲ) .^ reshape(-θʲ, 1, J, 1), dims=3)' .^ (-1 ./ θʲ)
        return p̂ʲ₁, ĉ
    end

    # convergence
    X = Converge(x -> UpdateRule(x)[1], p̂ʲ₀; tol=tol, maxIter=maxIter, damp=damp, power=power,
        displayGap=displayGap, displaySummary=displaySummary)

    return UpdateRule(X)
end

# Solve the expenditure inner loop
function OutputFunc(ξʲᵏ, αʲ, πʲ′, τʲ′, Inˡ′, Inᶠ′, D, J, N;
    tol = 1e-8, 
    maxIter = 1e3,
    damp = 0.0,
    power = false,
    displayGap = false,
    displaySummary = false)
    
    # initial guess
    Xʲ′ = zeros(J, N);

    # update rule
    function UpdateRule(Xʲ′₀)
        Mni′ = repeat(Xʲ′₀', 1, 1, N) .* πʲ′ ./ (1 .+ τʲ′)
        Yʲ′ = sumsqueeze(Mni′, dims = 1);
        Inᵗ′ = vec(sum(Mni′ .* τʲ′, dims = (2, 3)));
        In′ = Inˡ′ + sum(Inᶠ′, dims = 1)' + Inᵗ′ + D;
        Xʲ′₁ = stack(ξʲᵏ[:, i, :]' * Yʲ′[:, i] for i in 1:N) + αʲ .* In′'

        return Xʲ′₁, Yʲ′, In′, Mni′
    end

    # convergence
    X = Converge(x -> UpdateRule(x)[1], Xʲ′; tol = tol, maxIter = maxIter, damp = damp, power = power, 
    displayGap = displayGap, displaySummary = displaySummary);

    return UpdateRule(X)
end