cd "/Users/pohwaran/Doctorate/Paper/DeGlobEnvCost/Data/CEPII"
import delimited "Gravity_Cou_Cou_48-20.csv", varnames(1) clear

keep if year == 2020
drop if country_exists_o == 0 | country_exists_d == 0
duplicates drop iso3_o iso3_d, force
rename iso3_o iso3
merge m:1 iso3 using "CouMerge.dta", nogen
rename index cou_o
rename iso3 iso3_o
rename iso3_d iso3
sort iso3
merge m:1 iso3 using "CouMerge.dta", nogen
rename index cou_d
rename iso3 iso3_d
keep iso3_o iso3_d distw_harmonic cou_o cou_d tradeflow_baci
sort cou_o cou_d
replace cou_d = 44 if cou_d == .
replace cou_o = 44 if cou_o == .
save DistTemp.dta, replace

rename iso3_o iso3
rename iso3_d iso3_o
rename iso3 iso3_d
sort iso3_o iso3_d 
keep iso3_o iso3_d trade
rename tradeflow_baci trade 
save DistTemp2.dta, replace

use DistTemp.dta, clear
sort iso3_o iso3_d
merge 1:1 iso3_o iso3_d using DistTemp2.dta, nogen
gen totalTrade = tradeflow_baci + trade
sort cou_o cou_d 
bys cou_o cou_d: egen dist = wtmean(distw_harmonic), weight(totalTrade)
duplicates drop cou_o cou_d, force
keep cou_o cou_d dist
rename cou_o exporter
rename cou_d importer
replace dist = 0 if exporter == importer
save Distance.dta, replace

erase DistTemp.dta 
erase DistTemp2.dta