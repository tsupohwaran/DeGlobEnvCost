*==================================================*
* Average bilateral trade data from 2013-2017
* HS 2012
* Source: CEPII-BACI
*==================================================*

cd "/Users/pohwaran/Doctorate/Paper/DeGlobEnvCost/Data/CEPII/"

forv year = 13/17{
    import delimited "BACI_HS07_Y`=`year'+2000'_V202501.csv", clear
    ren t year
    ren i exporter
    ren j importer
    ren k product
    ren v value_raw
    drop q
    save "Trade_Imp_Sec_Exp_`year'.dta", replace
}

use "Trade_Imp_Sec_Exp_13.dta", clear
forv year = 14/17{
    append using "Trade_Imp_Sec_Exp_`year'.dta"
}
bys importer exporter product: egen value = sum(value_raw)
gduplicates drop importer exporter product, force
drop value_raw year
sort importer exporter product
save "TotalTrade_HS12_Imp_Sec_Exp_13-17.dta", replace

save "TotalTrade_HS06_Imp_Sec_Exp_13-17.dta", replace


import delimited "BACI_HS17_Y2017_V202501.csv", clear
drop year

save "Trade_Imp_Sec_Exp_17.dta", replace

* merge country code iso3
ren importer cou_code
sort cou_code
merge m:1 cou_code using "Country_ISO3.dta"
ren cou_iso3 importer
drop if _m != 3
drop _m cou_code

ren exporter cou_code
sort cou_code
merge m:1 cou_code using "Country_ISO3.dta"
ren cou_iso3 exporter
drop if _m != 3
drop _m cou_code
sort importer exporter product