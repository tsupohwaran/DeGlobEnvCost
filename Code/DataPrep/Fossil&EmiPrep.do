*==================================================*
* Fossil Fuel Production Data Preparation
*==================================================*

cd "/Users/pohwaran/Doctorate/Paper/DeGlobEnvCost/Data/Energy/Raw"

foreach v in Coal Oil Gas {
    import delimited "`v'Prod_Cou_80-23.csv", varnames(3) clear
    drop v1 
    local i = 1
    foreach var of varlist * {
        rename `var' v`i'
        local i = `i' + 1
    }
    rename v1 couName
    replace couName = subinstr(couName, "        ", "", 1)
    replace couName = subinstr(couName, "    ", "", 1)
    local t = 1980
    foreach var of varlist v* {
        rename `var'  `v'_`t'
        local t = `t' + 1
    }
    reshape long `v'_, i(couName) j(year)
    rename `v'_ `v'
    destring `v', force replace
    save "`v'Temp.dta", replace
    forvalues i = 1980/2023{
        use "`v'Temp.dta", clear
        keep if year == `i'
        sort couName
        merge 1:1 couName using "CouMerge.dta"
        drop if index == .
        drop _merge
        sort index
        gen `v'Share = `v' / `v'[_N]
        egen row = sum(`v'Share)
        replace row = row - 1
        replace `v'Share = 1 - row if _n == _N
        drop row `v'
        save "`v'_`i'.dta", replace
    }
    erase "`v'Temp.dta" 
}

forvalues i = 1980/2023{
    use "Coal_`i'.dta", clear
    foreach v in  Oil Gas {
        merge 1:1 index using "`v'_`i'.dta", nogen
        drop year
        save "FossilShare_`=`i'-2000'.dta", replace
    }
    export excel using "../FossilProd_80-23.xlsx", sheet("`i'") sheetreplace firstrow(variables)
    erase "FossilShare_`=`i'-2000'.dta"
}

foreach v in Coal Oil Gas {
    forvalues i = 1980/2023{
        erase "`v'_`i'.dta"
    }
}

*==================================================*
* Fossil Fuel Emission Data Preparation
*==================================================*

cd "/Users/pohwaran/Doctorate/Paper/DeGlobEnvCost/Data/Emission/Raw"

foreach v in Coal Oil Gas {
    import delimited "`v'Emi_Cou_80-23.csv", varnames(3) clear
    drop v1 
    local i = 1
    foreach var of varlist * {
        rename `var' v`i'
        local i = `i' + 1
    }
    rename v1 couName
    replace couName = subinstr(couName, "        ", "", 1)
    replace couName = subinstr(couName, "    ", "", 1)
    local t = 1949
    foreach var of varlist v* {
        rename `var'  `v'Emi_`t'
        local t = `t' + 1
    }
    destring `v'*, force replace
    reshape long `v'Emi_, i(couName) j(year)
    rename `v'Emi_ `v'Emi
    save "`v'Temp.dta", replace
    forvalues i = 1980/2023{
        use "`v'Temp.dta", clear
        keep if year == `i'
        sort couName
        merge 1:1 couName using "../../Energy/Raw/CouMerge.dta"
        drop if index == .
        drop _merge
        sort index
        egen row = sum(`v'Emi)
        replace `v'Emi = `v'Emi * 2 - row if _n == _N
        drop row
        save "`v'_`i'.dta", replace 
    }
    erase "`v'Temp.dta" 
}

forvalues i = 1980/2023{
    use "Coal_`i'.dta", clear
    foreach v in  Oil Gas {
        merge 1:1 index using "`v'_`i'.dta", nogen
        drop year
        save "FossilEmi_`=`i'-2000'.dta", replace
    }
    order couName index CoalEmi OilEmi GasEmi
    export excel using "../FossilEmi_80-23.xlsx", sheet("`i'") sheetreplace firstrow(variables)
    erase "FossilEmi_`=`i'-2000'.dta"
}

foreach v in Coal Oil Gas {
    forvalues i = 1980/2023{
        erase "`v'_`i'.dta"
    }
}

*==================================================*
* Fossil Fuel Consumption Data Preparation
*==================================================*

foreach v in Coal Oil Gas {
    import delimited "`v'Consum_Cou_80-23.csv", varnames(3) clear
    drop v1 
    local i = 1
    foreach var of varlist * {
        rename `var' v`i'
        local i = `i' + 1
    }
    rename v1 couName
    replace couName = subinstr(couName, "        ", "", 1)
    replace couName = subinstr(couName, "    ", "", 1)
    local t = 1980
    foreach var of varlist v* {
        rename `var'  `v'Consum_`t'
        local t = `t' + 1
    }
    destring `v'*, force replace
    reshape long `v'Consum_, i(couName) j(year)
    rename `v'Consum_ `v'Consum
    save "`v'Temp.dta", replace
    forvalues i = 1980/2023{
        use "`v'Temp.dta", clear
        keep if year == `i'
        sort couName
        merge 1:1 couName using "../../Energy/Raw/CouMerge.dta"
        drop if index == .
        drop _merge
        sort index
        egen row = sum(`v'Consum)
        replace `v'Consum = `v'Consum * 2 - row if _n == _N
        drop row
        save "`v'_`i'.dta", replace 
    }
    erase "`v'Temp.dta" 
}

forvalues i = 1980/2023{
    use "Coal_`i'.dta", clear
    foreach v in  Oil Gas {
        merge 1:1 index using "`v'_`i'.dta", nogen
        drop year
        save "FossilConsum_`=`i'-2000'.dta", replace
    }
    order couName index CoalConsum OilConsum GasConsum
    export excel using "../FossilConsum_80-23.xlsx", sheet("`i'") sheetreplace firstrow(variables)
    erase "FossilConsum_`=`i'-2000'.dta"
}

foreach v in Coal Oil Gas {
    forvalues i = 1980/2023{
        erase "`v'_`i'.dta"
    }
}

*==================================================*
* Economy-sector emission data preparation (unit: million tonnes)
*==================================================*

import delimited "Emission_Cou_Sec_95-20.csv", varnames(1) clear
save "Emission_Cou_Sec_95-20.dta", replace

forvalues i = 1995/2020{
    use "Emission_Cou_Sec_95-20.dta", clear
    sort ref_area
    merge m:1 ref_area using "CouMerge.dta"
    drop if _merge != 3
    drop _merge
    sort activity
    merge m:1 activity using "SecMerge.dta"
    drop if _merge != 3
    drop _merge
    rename obs_value emission
    rename time_period year
    keep country sector emission year
    keep if year == `i'
    bys country sector: egen row = sum(emission)
    replace emission = row
    drop row year
    duplicates drop country sector, force
    bys sector: egen emiTotal = sum(emission)
    replace emission = 2 * emission - emiTotal if country == 44
    drop emiTotal
    sort country sector
    order country sector emission
    export excel using "../Emission_Sec_Cou_95-20.xlsx", sheet("`i'") sheetreplace firstrow(variables)
}
