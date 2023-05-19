/********************************************************************************/
clear 

// LOAD SR DATASET
cd "C:\Users\Henry\OneDrive\Documents\DATA SCIENCE TUTORIAL"
use "CRS_PVHH_Approved_02_10_2021.dta", clear

// Tabulate LGAs with relationship == 1
tab lga if relationship == 1 

// Set OBD period
local timeperiod = "CRS MAY2021 to JUNE2021"

// Set file path
local filepath = "C:\Users\Henry\OneDrive\Documents\DATA SCIENCE TUTORIAL\GITHUB"

// Set state name
local var = "CROSS RIVER"

preserve

// Extract household heads from NSR dataset
keep if interviewdate <= "2021-06-30"
tab lga if relationship == 1 

// Trim community names
replace community = trim(community)

// Confirm no future interview dates in the dataset
rename interviewdate oldinterviewdate
gen interviewdate = date(oldinterviewdate, "YMD")
gen month = month(interviewdate)
gen year = year(interviewdate)
gen day = day(interviewdate)

tab month year

// Correct April 31st error
count if day == 31 & month == 4
replace day = 30 if day == 31 & month == 4
tostring year month day, replace
gen strintdat = day + "/" + month + "/" + year
gen strintdat2 = date(strintdat, "DMY")
replace interviewdate = strintdat2
drop strintdat strintdat2 

// Generate total households uploaded per community
bysort state lga ward community: gen hhuploaded = _N

// Get first and last household in each community
destring hhno, gen(numhhno)
bysort state lga ward community: egen firsthhno = min(numhhno)
bysort state lga ward community: egen lasthhno = max(numhhno)

// Get first and last household date in each community
bysort state lga ward community: egen startdate = min(interviewdate)
bysort state lga ward community: egen enddate = max(interviewdate)
format startdate enddate %td

// Flag first name and last name of first and last households in each community
gen fnflag = 1 if numhhno == firsthhno
gen lnflag = 1 if numhhno == lasthhno

// Concatenate names
gen fullname = hhh_surname + " " + hhh_othername + " " + hhh_firstname 

// Get first and last household head names
gen firsthhhname = fullname if fnflag == 1 
gen lasthhhname = fullname if lnflag == 1  

// Fill in missing name values
bysort state lga ward community (firsthhhname): replace firsthhhname = firsthhhname[_N]
bysort state lga ward community (lasthhhname): replace lasthhhname = lasthhhname[_N]
bysort state lga ward community (firsthhref): replace firsthhref = firsthhref[_N]
bysort state lga ward community (lasthhref): replace lasthhref = lasthhref[_N]

// Generate ranges
gen namerange = firsthhhname + "..." + lasthhhname 
gen refrange = firsthhref + "..." + lasthhref 

// Summarize data
rename (namerange refrange) (hhhead hhrefno)
contract state lga ward community startdate enddate hhhead hhrefno hhuploaded 
drop _freq

order state lga ward community startdate enddate hhhead hhrefno hhuploaded 

capture: gen hhidentified = .

// Generate totals (optional)
bysort state: egen totalhouseholds = sum(hhuploaded)
bysort state: egen totallga = sum(lga)
bysort state: egen totalcommunity = sum(community)
bysort state: egen totalward = sum(ward)

// Generate output 2, Table 1
export excel state lga community startdate enddate hhidentified NumberOfHHsEnumerated totalhouseholds totalcommunity totallga using "`filepath' `var' _OBD_`timeperiod'.xls", sheet("T1") firstrow(variables) sheetreplace 

// Generate output 2, Table 3
export excel state lga community hhhead hhrefno NumberOfHHsEnumerated totalhouseholds totallga totalcommunity using "`filepath' `var' _OBD_`timeperiod'.xls", sheet("T3") firstrow(variables) sheetmodify

// Generate output 2, Table 2
collapse (sum) totalhouseholds totallga totalward NumberOfHHsEnumerated, by(state lga ward)
drop totalhouseholds totallga totalward 

bysort state: egen totalhouseholds = sum(NumberOfHHsEnumerated)
bysort state: egen totallga = nvals(lga)
bysort state: egen totalward = nvals(ward)

export excel state lga ward NumberOfHHsEnumerated totalhouseholds totallga totalward using "`filepath' `var' _OBD_`timeperiod'.xls", sheet("T2") firstrow(variables) sheetmodify

restore
