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
* AVEMFN
*==================================================*

use "AVEMFN/AVEMFN_Imp_Sec.dta", clear
ren productcode product
ren simpleaverage tariff_mfn

ren reporter_iso_n cou_code
merge m:1 cou_code using "Country_ISO3.dta"
ren cou_iso3 importer
drop if _m != 3
keep importer product tariff_mfn year nomencode
sort importer product year

forv i = 1988/2023{
    preserve
        keep if year == `i'
        drop year
        save "AVEMFN/AVEMFN_Imp_Sec_`=`i'-2000'.dta", replace
    restore
}

use "AVEMFN/AVEMFN_Imp_Sec_17.dta", clear
forv i = 2/5{
    preserve
        keep if nomencode == "H`i'"
        drop nomencode
        ren product product_old
        sort product_old
        save "AVEMFN/AVEMFN_Imp_Sec_H`i'_17.dta", replace
    restore
}

* H2
use "AVEMFN/AVEMFN_Imp_Sec_H2_17.dta", clear
sort product_old
merge 1:m product_old using "HS12toHS02.dta"
keep if _m == 3
drop product_old _m
sort product
save "AVEMFN/AVEMFN_Imp_Sec_H2_17.dta", replace

* H3
use "AVEMFN/AVEMFN_Imp_Sec_H3_17.dta", clear
sort product_old
merge m:m product_old using "HS12toHS07.dta"
keep if _m == 3
drop product_old _m
sort product
save "AVEMFN/AVEMFN_Imp_Sec_H3_17.dta, replace

* H5
use "AVEMFN/AVEMFN_Imp_Sec_H5_17.dta", clear
sort product_old
merge m:1 product_old using "HS17toHS12.dta"
keep if _m == 3
drop product_old _m
ren tariff_mfn tariff
bys importer product: egen tariff_mfn = mean(tariff)
drop tariff
sort importer product
save "AVEMFN/AVEMFN_Imp_Sec_H5_17.dta", replace

use "AVEMFN/AVEMFN_Imp_Sec_H2_17.dta", clear
forvalues i = 3/5 {
    append using "AVEMFN/AVEMFN_Imp_Sec_H`i'_17.dta"
}
replace product = product_old if product == .
drop product_old

*==================================================*
* HS code conversion
*==================================================*

foreach year in 2017 2022 {
    import delimited "../TradeCode/HS`=`year'-2000'toHS12.CSV", clear
    drop hs`year'productdescription hs2012productdescription
    rename hs`year'productcode product_old
    rename hs2012productcode product
    sort product_old
    save "HS`=`year'-2000'toHS12.dta", replace
}


import delimited "../TradeCode/HS12toHS07.CSV", clear
drop hs2012productdescription hs2007productdescription
ren hs2012productcode product
ren hs2007productcode product_old
sort product_old
save "HS12toHS07.dta", replace

import delimited "../TradeCode/HS12toHS02.CSV", clear
drop hs2012productdescription hs2002productdescription
ren hs2012productcode product
ren hs2002productcode product_old
sort product_old
save "HS12toHS02.dta", replace

*==================================================*
* Prepare the dataset for the tariff data
*==================================================*

* Loop through each year from 2015 to 2023 to process tariff data for each year
* Keep only the necessary variables for analysis
use "TariffRaw_Imp_Sec_Exp_17.dta", clear
keep if dutytype == "AHS"
drop if reportername == "European Union" // drop EU

keep reporter product partner weightedaverage nativenomen

ren product product_old
ren weightedaverage tariff

* merge importer's code
ren reporter cou_code
merge m:1 cou_code using "Country_ISO3.dta"
ren cou_iso3 importer
drop if _m != 3
drop cou_code _m

* merge exporter's code
ren partner cou_code
sort cou_code
merge m:1 cou_code using "Country_ISO3.dta"
ren cou_iso3 exporter
drop if _m != 3
drop cou_code _m

forv i = 3/5{
    preserve
        keep if nativenomen == "H`i'"
        drop nativenomen
        sort product_old
        save "TariffTemp_H`i'.dta", replace
    restore
}

use HS12toHS07.dta, clear
merge m:m product_old using "TariffTemp_H3.dta"
drop if _m != 3
drop product_old _m
sort importer exporter product
save TariffTemp_H3.dta, replace

* HS 2017
use "TariffTemp_H5.dta", clear
merge m:1 product_old using "HS17toHS12.dta"
drop if _m != 3
drop _m
sort importer exporter product_old

merge 1:1 importer exporter product_old using "../../CEPII/Trade_Imp_Sec_Exp_17.dta"
drop if _m == 2
replace value_raw = 0.00001 if value_raw == .
bys importer exporter product: egen tariff_new = wtmean(tariff), weight(value_raw)
drop if tariff_new == .
drop tariff _m value product_old
ren tariff_new tariff
duplicates drop importer exporter product, force
save "TariffTemp_H5.dta", replace

use "TariffTemp_H3.dta", clear
forvalues i = 4/5 {
    append using "TariffTemp_H`i'.dta"
}
replace product = product_old if product == .
drop product_old

sort importer exporter product
merge 1:1 importer exporter product using "../../CEPII/TotalTrade_HS12_Imp_Sec_Exp_13-17.dta"
ren _m _m1
sort importer product
merge m:1 importer product using "AVEMFN/AVEMFN_Imp_Sec_17.dta"
replace tariff = tariff_mfn if _m1 == 2 & tariff == .
replace value = 0.0001 if value == . & _m1 == 1

    
    
    * Sort by reporter name for merging
    sort reportername
    
    * Convert reporter names to numeric identifiers using CouMerge.dta
    merge m:1 reportername using CouMerge.dta
    replace Index = 44 if Index == .
    bys tariffyear partnername product: egen tariff = wtmean(weightedaverage) if _merge == 1, weight(importsvaluein1000usd)
    gduplicates drop tariffyear Index partnername product, force
    replace tariff = weightedaverage if tariff == .
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
    keep if tariffyear == `i'
    * Convert product codes to sector identifiers using SecMerge.dta
    merge m:1 product using SecMerge.dta
    drop _merge
    drop product
    drop if sector == .  // Remove observations with missing sector
    
    * Calculate weighted average tariff by sector-exporter-importer combination
    bys sector exporter importer: egen tariff_temp = wtmean(weightedaverage), weight(importsvaluein1000usd)
    replace tariff = tariff_temp

    * Remove duplicates to have unique sector-exporter-importer observations
    gduplicates drop sector exporter importer, force 
    
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
    restore

* Append the datasets
use "Tariff_Importer_Sector_Exporter_0.dta", clear
forvalues i = 1/23 {
    merge 1:1 sector exporter importer using "Tariff_Importer_Sector_Exporter_`i'.dta", nogen
    sort sector exporter importer
}

egen missing_count = rowmiss(tariff_*)
forvalues i = 0/23 {
    replace tariff_`i' = 0 if missing_count == 24
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
forvalues i = 0/23 {
    rename tariff`i' tariff_`i'
    replace tariff_`i' = 0 if tariff_`i' < 0
}

* Save the final dataset
save "Tariff_Importer_Sector_Exporter_00-23.dta", replace
forvalues i = 0/23 {
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
gen tariffChange_2017_2023 = tariff2023 / tariff2017
gen tariffChange_2015_2023 = tariff2023 / tariff2015
* Save the processed EU and ASEAN tariff data