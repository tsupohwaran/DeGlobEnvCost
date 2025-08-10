@load "Data/Tariff/Tariff_importer_Sector_Exporter_14-23.jld2" τ_17 τ_23
τ̂ʲ = τ_23 ./ τ_17;
τ̂ʲ[τ̂ʲ.==Inf] .= 1.0
τ̂ʲ[isnan.(τ̂ʲ)] .= 1.0

# Load Mni for year 17 to use as weights
Mni_17 = load("Data/Model/ModelDataRaw_17.jld2")["inputData"].Mni
Mni_23 = load("Data/Model/ModelDataRaw_23.jld2")["inputData"].Mni
Mni_17 .- Mni_23
for i = 1:44
    Mni_17[i, :, i] .= 0.0
    Mni_23[i, :, i] .= 0.0
end

for j = 15:19
    Mni_17[:, j, :] .= 0.0
    Mni_23[:, j, :] .= 0.0
end

# EU free trade 
for j = 17:43
    for t = 17:43
        Mni_17[j, :, t] .= 0.0
        Mni_23[j, :, t] .= 0.0
    end
end

# Calculate weights
weights_17 = Mni_17 ./ sum(Mni_17, dims=2);
weights_23 = Mni_23 ./ sum(Mni_23, dims=2);
τ_wgtav_17 = sumsqueeze(τ_17 .* weights_17, dims=2);
τ_wgtav_23 = sumsqueeze(τ_23 .* weights_23, dims=2);
τ̂ʲ_wgtav = (τ_wgtav_23 ./ τ_wgtav_17 .- 1.0) * 100;
τ̂ʲ_wgtav[isnan.(τ̂ʲ_wgtav)] .= 0.0
τ̂ʲ_wgtav[τ̂ʲ_wgtav .== Inf] .= 0.0

cliparray(τ_17[16, :, 9]*100);
cliparray(τ_23[16, :, 9]*100);
clipboard(τ_wgtav_17[16, 9]);
clipboard(τ_wgtav_23[16, 9]);

cliparray(Mni_17[16, :, 9])
cliparray(Mni_23[16, :, 9])

# plot heatmap for τ̂ʲ_wgtav
# Define region names for better readability
region_names = vec(Matrix{String}(XLSX.readdata("Data/ADB/CouSecConvert_ADB.xlsx", "cou_list", "A1:A44")))

# Create heatmap
# First set diagonal elements to NaN to show them differently in the heatmap
τ̂ʲ_wgtav_plot = copy(τ̂ʲ_wgtav)
for i in 1:size(τ̂ʲ_wgtav_plot, 1)
    τ̂ʲ_wgtav_plot[i, i] = NaN
end

# Create the heatmap
p = heatmap(τ̂ʲ_wgtav_plot, 
    xticks=(1:44, region_names), yticks=(1:44, region_names),
    xrotation=90, size=(800, 700), dpi=300,
    color=:viridis, clim=(-10, 10),
    title="Change in Import Tariffs 2023 vs 2017 (%)",
    xlabel="Exporter", ylabel="Importer",
    nan_color=:white)

# Find the index where region_names equals specific countries
prc_index = findfirst(r -> r == "PRC", region_names)
usa_index = findfirst(r -> r == "USA", region_names)

# Add colorbar
plot!(p, colorbar_title="% Change", dpi=1000)

# Modify the axis tick colors for PRC
if !isnothing(prc_index)
    # Create the plot with standard settings
    plot!(p)
    
    # Add annotations to highlight PRC
    annotate!(prc_index, -2, text("*", :red, :center, 8))  # X-axis
    annotate!(-2.1, prc_index, text("*", :red, :center, 8))  # Y-axis
end

# Modify the axis tick colors for USA
if !isnothing(usa_index)
    # Add annotations to highlight USA
    annotate!(usa_index, -2, text("*", :blue, :center, 8))  # X-axis
    annotate!(-2.1, usa_index, text("*", :blue, :center, 8))  # Y-axis
end

# Save the plot with high resolution
savefig(p, "Figures/TariffChanges_17-23.png")

display(p)
