cd "/Users/pohwaran/Doctorate/Paper/DeGlobEnvCost/Data/Tariff/Raw"

*==================================================*
* Create a dataset sorted by 15 sectors, 44 exporters, 44 importers
*==================================================*

clear
set obs 36784 // 19*44*44
gen sector = ceil(_n/(44*44))
gen exporter = floor(mod(_n-1, 44*44)/44) + 1
gen importer = mod(_n-1, 44) + 1
save "TariffStructure.dta", replace

*==================================================*
* Prepare the dataset for the tariff data
*==================================================*

* Loop through each year from 2014 to 2023 to process tariff data for each year
forvalues i = 2014/2023 {
    import delimited "BilateralTariff_Cou44_Ind_15_25.csv", clear
    
    * Keep only the necessary variables for analysis
    keep reportername product partnername tradeyear weightedaverage importsvaluein1000usd
    
    * Sort by reporter name for merging
    sort reportername
    
    * Convert reporter names to numeric identifiers using CouMerge.dta
    merge m:1 reportername using CouMerge.dta
    drop _merge
    drop reportername
    
    * Rename variables to prepare for second merge - converting partner to importer
    rename partnername reportername
    rename Index importer
    
    * Sort by the new reporter name for second merge
    sort reportername
    
    * Convert partner names to numeric identifiers using CouMerge.dta
    merge m:1 reportername using CouMerge.dta
    drop if _merge != 3  // Keep only matched observations
    drop _merge
    drop reportername
    rename Index exporter
    
    * Sort data and keep only records for the current year in the loop
    sort tradeyear product exporter importer
    keep if tradeyear == `i'

    * Convert product codes to sector identifiers using SecMerge.dta
    merge m:1 product using SecMerge.dta
    drop _merge
    drop product
    drop if sector == .  // Remove observations with missing sector
    
    * Calculate weighted average tariff by sector-exporter-importer combination
    bys sector exporter importer: egen tariff = wtmean(weightedaverage), weight(importsvaluein1000usd)
    
    * Remove duplicates to have unique sector-exporter-importer observations
    duplicates drop sector exporter importer, force 
    
    * Keep only the key variables
    keep importer exporter sector tariff
    
    * Merge with the base dataset structure
    merge 1:1 sector exporter importer using "TariffStructure.dta", nogen
    
    * Set tariff to zero for domestic trade (same importer and exporter)
    replace tariff = 0 if importer == exporter
    
    * Sort data for consistency
    sort sector exporter importer
    
    * Rename tariff variable to include year and save the annual dataset
    rename tariff tariff_`= `i' - 2000'
    save "Tariff_Importer_Sector_Exporter_`=`i'-2000'.dta", replace
}

* Append the datasets
use "Tariff_Importer_Sector_Exporter_14.dta", clear
forvalues i = 15/23 {
    merge 1:1 sector exporter importer using "Tariff_Importer_Sector_Exporter_`i'.dta", nogen
    sort sector exporter importer
}

egen missing_count = rowmiss(tariff_*)
forvalues i = 14/23 {
    replace tariff_`i' = 0 if missing_count == 10
}

* Create a single year variable and reshape to long format for interpolation
reshape long tariff_, i(sector exporter importer) j(year)
rename tariff_ tariff

* Interpolate missing values for each sector-exporter-importer combination
bys sector exporter importer: ipolate tariff year, generate(tariff_interpolated) epolate

* Replace missing values with interpolated values
replace tariff = tariff_interpolated if missing(tariff)
drop tariff_interpolated

* Reshape back to wide format
reshape wide tariff, i(sector exporter importer) j(year)

* Rename variables to original format
forvalues i = 14/23 {
    rename tariff`i' tariff_`i'
    replace tariff_`i' = 0 if (tariff_`i' == . | tariff_`i' < 0)
}

* Save the final dataset
save "Tariff_Importer_Sector_Exporter_14-23_ipolate.dta", replace
forvalues i = 14/23 {
    erase "Tariff_Importer_Sector_Exporter_`i'.dta"
}

*==================================================*
* End of TariffPrep.do
*==================================================*

forvalues i = 14/23 {
    use "Tariff_Importer_Sector_Exporter_14-23_ipolate.dta", clear
    keep sector exporter importer tariff_`i'
    save "Tariff_Importer_Sector_Exporter_`i'.dta", replace
}

*==================================================*
* check the tariff data from EU and ASEAN
*==================================================*

import delimited "Tariff_EU_ASEAN_Ind_15_25.csv", clear
keep reportername product tariffyear weightedaverage importsvaluein1000usd

* Convert product codes to sector identifiers using SecMerge.dta
merge m:1 product using SecMerge.dta
drop _merge
drop product
drop if sector == .  // Remove observations with missing sector

* Calculate weighted average tariff by sector-exporter-importer combination
bys tariffyear reportername sector: egen tariff = wtmean(weightedaverage), weight(importsvaluein1000usd)
duplicates drop tariffyear sector reportername, force 
drop importsvaluein1000usd weightedaverage
reshape wide tariff, i(reportername sector) j(tariffyear)

gen tariffChange = tariff2023 / tariff2017