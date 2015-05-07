##Install any needed packages using "install.packages('nameOfPackage')"
##Source of stolen Code: http://notesofdabbler.bitbucket.org/2013_12_censusBlog/censusHomeValueExplore_wdesc.html


##[Hyper]links to necessary data

# 1)shape file of zips in Oakland ('return to: main download page' -> 'layer type: zipcode tabulation areas'->
# '2010: California')
#http://www.census.gov/cgi-bin/geo/shapefiles2010/layers.cgi

# zipCityCountyStateMap.rda is created in the OaklandACSCensusZipSupport file
load("zipCityCountyStateMap.Rda")
head(zipMap2)

###LOAD LIBRARIES####
#set working directory 
wDir = "~/Open Oakland/Exploring Oakland/Data"
setwd(wDir)

#Load Libraries/Packages
library(XML)
library(RCurl)

library(stringr)
library(ggplot2)
library(maptools)

library(rgeos)

library(ggmap)
library(plyr)
library(RJSONIO)


####SET-UP Mapping Data####

# list of counties in the greater Oakland area
cntyList = c("Alameda County, CA")

# zipcodes in Alameda ('zipMap2' comes from above-"zipCityCountyStateMap.Rda")
zipOak=zipMap2[zipMap2$ctyname %in% cntyList,]
zipOak2=zipOak[!duplicated(zipOak$ZCTA5),]
head(zipOak2)

# get shape file of zips in Oakland
# http://www.census.gov/cgi-bin/geo/shapefiles2010/layers.cgi
zipShp = readShapePoly("tl_2010_06_zcta510.shp")
zipShp2=fortify(zipShp,region="ZCTA5CE10")

zipShp3=zipShp2[zipShp2$id %in% zipOak$ZCTA5,]

#preliminary map, to check base information
x=get_googlemap(center="Oakland",maptype=c("roadmap"))
p=ggmap(x)
p=p+geom_polygon(data=zipShp3,aes(x=long,y=lat,group=id),fill="blue",color="black",alpha=0.2)
print(p)

##Create a list of ZipCodes in Oakland
zipOakList = zipOak2$ZCTA5
zipOakList = data.frame(zipOakList,stringsAsFactors=FALSE)
names(zipOakList) = c("zip")

####START GETTING DATA TO MAP####

###2010 CENSUS DATA###
APIkey ="68c9ac687e1e210c4d44bfd6ade4b0c5d1c34e38" 

# state code (CA)
state=06

# function to retrieve data from 2010 US census data
getCensusData=function(APIkey,state,fieldnm, fieldName){
  resURL=paste("http://api.census.gov/data/2010/sf1?get=",fieldnm,
               "&for=zip+code+tabulation+area:*&in=state:",state,"&key=",
               APIkey,sep="")
  dfJSON=fromJSON(resURL)
  dfJSON=dfJSON[2:length(dfJSON)]
  dfJSON_zip=sapply(dfJSON,function(x) x[3])
  dfJSON_val=sapply(dfJSON,function(x) x[1])
  df=data.frame(dfJSON_zip,as.numeric(dfJSON_val))
  names(df)=c("zip", fieldName)
  return(df)
}

##Population and Race Data from US census 2010(Per State)##

#Total Population
fieldnm="P0030001" 
fieldName = "TotalPop"
dfTotPop=getCensusData(APIkey,state,fieldnm, fieldName)
names(dfTotPop)=c("zip","TotalPop")
head(dfTotPop)

#Black or African American alone/ or in combination with one or more other races
fieldnm="P0060003"  
fieldName = "BlackPop"
dfBlackPop=getCensusData(APIkey,state,fieldnm, fieldName)
names(dfBlackPop)=c("zip","BlackPop")
head(dfBlackPop)

#Find percent black
popZip = merge (dfTotPop, dfBlackPop,by=c("zip"),all.x=TRUE)
popZip <- transform(popZip, percentBlack = (BlackPop/TotalPop)*100)

head(popZip)



##MAP THE CENSUS##
popZip$percentBlackLvl=cut(popZip$percentBlack,
					breaks=c(-1,5,10,20,40,100),
					labels=c("<5","5-10","10-20","20-40",">40"))

zipShp3$rnum=seq(1,nrow(zipShp3))
zipPlt=merge(zipShp3,popZip,by.x=c("id"),by.y=c("zip"))
zipPlt=zipPlt[order(zipPlt$rnum),]

x=get_googlemap(center="oakland",maptype=c("roadmap"))
p = ggmap(x)
p = p + geom_polygon(data = zipPlt, aes(x=long,y=lat,group=id,fill=percentBlackLvl),color="black",alpha=0.2)
p = p + scale_fill_manual(values=rainbow(20)[c(4,8,12,16,20)])
p = p + labs(title="Percent Black by Zip Code")
p = p + theme(legend.title=element_blank(),plot.title=element_text(face="bold"))
print(p)



##2011 ACS DATA##

#Median Income(all states)
fieldnm="B19013_001E"
resURL=paste("http://api.census.gov/data/2011/acs5?get=",fieldnm,"&for=zip+code+tabulation+area:*&key=",
             APIkey,sep="")
dfInc=fromJSON(resURL)
dfInc=dfInc[2:length(dfInc)]
dfInc_zip=as.character(sapply(dfInc,function(x) x[2]))
dfInc_medinc=as.character(sapply(dfInc,function(x) x[1]))
dfInc2=data.frame(dfInc_zip,as.numeric(dfInc_medinc))


names(dfInc2)=c("zip","medInc")

#Remove NAs
dfInc2=dfInc2[!is.na(dfInc2$medInc),]
head(dfInc2)

#Use only Alameda/Oakland ZipCodes
zdata=merge(zipOakList,dfInc2,by=c("zip"),all.x=TRUE)


#Separate into buckets
zdata$medIncLvl=cut(zdata$medInc,
                    breaks=c(0,50000,75000,100000,120000),
                    labels=c("<50K","50-75K","75-100K",">100K"))
head(zdata)


ddply(zdata,c("medIncLvl"),summarize,minval=min(medInc),maxval=max(medInc))


zipShp3$rnum=seq(1,nrow(zipShp3))
zipPlt=merge(zipShp3,zdata,by.x=c("id"),by.y=c("zip"))
zipPlt=zipPlt[order(zipPlt$rnum),]


##MAP THE ACS##
#Get base map (for like the 3rd time in this script)
x=get_googlemap(center="oakland",maptype=c("roadmap"))


# cloreopleth map of median income
p2=ggmap(x)
p2=p2+geom_polygon(data=zipPlt,aes(x=long,y=lat,group=id,fill=medIncLvl),color="black",alpha=0.2)
p2=p2+scale_fill_manual(values=rainbow(20)[c(4,8,12,16,20)])
p2=p2+labs(title="Median Income by Zip Code (US census - ACS data)")
p2=p2+theme(legend.title=element_blank(),plot.title=element_text(face="bold"))
print(p2)

