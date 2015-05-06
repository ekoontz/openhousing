##Hyperlinks to necessary data
# 1)state and county id-name maps (copy data into new file: "stateCntyCodes.txt")
#http://www.census.gov/econ/cbp/download/georef02.txt

# 2)zcta to county map (option 1)
#http://www.census.gov/geo/maps-data/data/zcta_rel_download.html


##set working directory
wDir = "~/Open Oakland/Exploring Oakland/Data"
setwd(wDir)

##Load Libraries
library(stringr)
library(zipcode)


#get state and county id-name maps
#http://www.census.gov/econ/cbp/download/georef02.txt
stateCntyCodes = read.table("stateCntyCodes.txt", sep = ",", colClasses = c("character"), 
    header = TRUE)
head(stateCntyCodes)


#get zcta to county map
#http://www.census.gov/geo/maps-data/data/zcta_rel_download.html
zipCnty = read.table("zcta_county_rel_10.txt", sep = ",", colClasses = c("character"), 
    header = TRUE)
head(zipCnty)


# get zip to city map - from package zipcode
data(zipcode)
head(zipcode)


# merge zip-city with zip-county-state
zipMap = merge(zipCnty[, c("ZCTA5", "STATE", "COUNTY")], zipcode[, c("zip", 
    "city")], by.x = "ZCTA5", by.y = "zip")

	
# get names of county and state
zipMap2 = merge(zipMap, stateCntyCodes, by.x = c("STATE", "COUNTY"), by.y = c("fipstate", 
    "fipscty"))
zipMap2$stname = sapply(zipMap2$ctyname, function(x) str_split(x, ",")[[1]][2])
head(zipMap2)


# save the dataset
save(zipMap2, file = "zipCityCountyStateMap.Rda")