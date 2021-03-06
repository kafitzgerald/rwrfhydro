#' ---
#' title: "Precipitation Evaluation"
#' author: "Arezoo Rafieeinasab"
#' date: "`r Sys.Date()`"
#' output: rmarkdown::html_vignette
#' vignette: >
#'   %\VignetteIndexEntry{Vignette Title}
#'   %\VignetteEngine{knitr::rmarkdown}
#'   %\VignetteEncoding{UTF-8}
#' ---
#' # Background
#' 
#' Forcing could be stored in multiple files, either in input forcing files (such as *LDASIN* or *PRECIP_FORCING* files) or in the output files (*LDASOUT*). *LDASOUT* files may contain a variable called *ACCPRCP* storing the accumulated precipitation, and the rainfall depth can be obtained by subtracting two consecutive time steps. *LDASIN* and *PRECIP_FORCING* files usually store rain rate in *RAINRATE* and *precip_rate* variables. This vignette serve as a short explanation of how to retrieve data and perform some basic comparisons between two set of data.
#' 
#' Load the rwrfhydro package. 
## ----results='hide', message=FALSE, warning=FALSE------------------------
library(rwrfhydro)

#' 
#' # Import observed datasets
#' 
#' Functions to retrieve observation data for several observational network is provided in rwrfhydro.  GHCN-Daily and USCRN networks are introduced and used in this vignette. 
#' 
#' # USCRN
#' The US. Climate Reference Network (USCRN) is a network of monitoring stations equipped with research quality instruments. Beside precipitation, these gauges report temperature, soil moisture and soil temperature. The precipitation is measured every 5 minutes using three independent measurements in a weighing bucket gauge accompanied with a disdrometer reporting the presence or absence of precipitation. These gauges, in the cold climate, are equipped with heating tape around the throat of the weighing gauge to prevent the frozen precipitation from accumulating on the interior walls and capping the gauge. The redundancy in the measurements is to ensure the quality of the measurements. 
#' 
#' Data is provided in 4 different temporal resolution (subhourly, hourly, daily and monthly), and depending on the temporal resolution, the variables provided changes. For more infoamtion on the data and how to retrieve, refer to the the man page of `Get_USCRN`.
#' 
#' # GHCN-daily
#' Global Historical Climatology Network-Daily (GHCN-D) dataset contains daily data from around 80000 surface station in the world, which about two third of them are precipitation only (Menne et al. 2012). It is the most complete collection of U.S. daily data available (Menne et al. 2012). The dataset undergo an automated quality assurance which the details can be found in Durre et al. 2008; 2010. Data is available on [http://www1.ncdc.noaa.gov/pub/data/ghcn/daily](http://www1.ncdc.noaa.gov/pub/data/ghcn/daily) and is updated frequently. Data is available in two formats either categorized by gauge station or categorized by year. Accordingly, there are two function to pull GHCN-daily data from these two sources called `GetGhcn` and `GetGhcn2`.
#' 
#' ## Gauge selection
#' First step is to select the gauges you want to use for verification based on some criteria. GHCN-daily contains the precipitation data from different sources such as COOP or CoCoRaHS. The selection criteria can be country code, states if country is US, type of rain gauge network (for example CoCoRaHS), or a rectangle domain. 
#' 
## ----eval = FALSE--------------------------------------------------------
## #setInternet2(use=FALSE) # If using windows, you may need this.
## 
## # Return all the gauges within US from observation network of COOP (C) and CoCoRaHS (1)
## countryCodeList <- c("US")
## networkCodeList <- c("1","C")
## sg <- SelectGhcnGauges(countryCode=countryCodeList,
##                        networkCode=networkCodeList)
## str(sg)

#' 
#' The sg dataframe has all the information provided by NCDC about each gauge. For the rest of this vignette we will use only the domain of Fourmile Creek which is the case study provided. We use the rectangle domain containing Fourmile Creek, as the boundary to collect all the gauges information.
#' 
## ------------------------------------------------------------------------
sg <- SelectGhcnGauges(domain = TRUE, minLat = 40.0125, maxLat = 40.0682, 
                       minLon = -105.562, maxLon=-105.323)
str(sg)

#' 
#' ## GetGhcn
#' GHCN-daily data are archived for each individual gauge in a text file in http://www1.ncdc.noaa.gov/pub/data/ghcn/daily/all/. Precipitating can be downloaded for a single site or multiple ones by setting element to "PRCP" and specifying the desired start and end date. Notice, precipitation values are  converted from 10th of mm to mm.
#' 
## ----message=FALSE, warning=FALSE----------------------------------------
startDate <- "2013/01/01"
endDate <- "2013/09/30"
element <- "PRCP"
obsPrcp <- GetGhcn(sg$siteIds, element, startDate, endDate, parallel = FALSE)
str(obsPrcp)

#' 
#' ## GetGhcn2
#' NCDC also provides GHCN-daily categorized by year under http://www1.ncdc.noaa.gov/pub/data/ghcn/daily/by_year/. If the number of the gauges are high, `GetGhcn2` is much faster in retrieving data. It has the same arguments as `GetGhcn`.
#' 
#' 
#' # Import forcing/precipitation data used in WRF-Hydro model  
#' Forcing data used in WRF-Hydro modeling are usually stored in forcing files (such as LDASIN or PRECIP_FORCING files). Here we are going to use the data provided under "Fourmile_Creek" dataset.
#' 
#' Set a data path to the Fourmile Creek test case.
#' 
## ------------------------------------------------------------------------
fcPath <- '~/wrfHydroTestCases/Fourmile_Creek_testcase_v2.0'

#' 
#' First make a list of all the forcing files.
#' 
## ------------------------------------------------------------------------
forcingPath <- paste0(fcPath,"/FORCING")
files <- list.files(path = forcingPath, full.names = TRUE, pattern = glob2rx("201304*LDASIN_DOMAIN1"))

#' 
#' 
#' In order to be able to pull data from the netcdf files, one needs the location of the points in the geogrid domain file. However, only lat/lon locations of rain gauges are available if using `SelectGhcnGauges` function. Therefore, it is required to map lat/lon information to x/y information in geogrid in order to pull the data from the netcdf files. This can be done using `GetGeogridIndex` function in rwrfhydro. One needs to provide the address to geogrid file, the lat/lon info and the `GetGeogridIndex` function return a dataframe with two column `sn` (south-north) and `ew` (east-west). 
#' 
## ----message=FALSE, warning=FALSE----------------------------------------
geoFile <- paste0(fcPath,'/DOMAIN/geo_em_d01.Fourmile1km.nlcd11.nc')
rainGgaugeInds <- GetGeogridIndex(xy = data.frame(lon=sg$longitude, lat=sg$latitude),
                                  ncfile = geoFile)
sg <- cbind(sg,rainGgaugeInds)
head(sg)

#' 
#' Now we can pull data. One needs to prepare the file, var, and ind variables for `GetMultiNcdf` function (refer to Collect Output Data: GetMultiNcdf vignette . You can leave the stat as mean; since you are pulling data for single pixels,  means return the value of the pixel.
#' 
## ----message=FALSE, warning=FALSE----------------------------------------
flList <- list(forcing = files)
varList <- list(forcing = list(PRCP = 'RAINRATE'))
prcpIndex <- list()
for (i in 1:length(sg$siteIds)) {
  if (!is.na(sg$we[i]) & !is.na(sg$sn[i])) {
    prcpIndex[[as.character(sg$siteIds[i])]] <- list(start=c(sg$we[i], sg$sn[i],1),
                                                     end=c(sg$we[i], sg$sn[i],1), stat="mean")
  }
}
indList <-list(forcing = list(PRCP = prcpIndex))
prcpData <- GetMultiNcdf(file = flList, var = varList, ind = indList, parallel=FALSE)
head(prcpData)

#' 
#' `GetMultiNcdf` pulls the time information from the netcdf files, if the data is not prepared properly, and the time info is not available, it will return the name of the file instead. In that case, time should be retrieved from the file name which is save in column `POSIXct`. Since the `obsPrcp` data are converted to mm, we also convert the rainrate to rain depth in an hour.
#' 
## ------------------------------------------------------------------------
prcpData$value <- prcpData$value*3600

#' 
#' ### Aggregating hourly data into daily.
#' 
#' Each GHCN gauge has a unique reporting time which the daily data is been calculated based on that. The reporting time is archived in the csv files and is retrieved when calling `GetGhcn2` function (you will not get the reporting time using `GetGhcn`). We need to add the reporting time for each point which would be the base for daily aggregation. If there will not be any `reportTime` in `sg` columns, then it uses the default which is 0700 AM. 
#' 
## ------------------------------------------------------------------------
if ("reportTime" %in% names(prcpData)) {
  sg$reportTime <- obsPrcp$reportTime[match(sg$siteIds, obsPrcp$siteIds)]
  sg$reportTime[which (sg$reportTime=="" | is.na(sg$reportTime))] <-700
}else{
  sg$reportTime<- 700
}

#' 
#' Call the `CalcDailyGhcn` function which takes the following steps: 
#' 
#' 1. It first search for a column called `timeZone` in the `sg` (selected gauges) dataframe. If the time zone has not been provided, it will call `GetTimeZone(sg)`. To `GetTimeZone` works, `sg` requires to have at least two fields of `latitude` and `longitude`.
#' 1. Having time zone for each gauge, the time offset will be obtained from the `tzLookup` data provided with rwrfhydro. Using the time offset, the UTC time of the precipitation will be converted to Local Standard Time (LST). This is the time convention, GHCN-D data report.
#' 1. The precipitation data will be aggregated based on the reporting time of individual gauge. After the `dailyData` is returned, you can remove the days which do not have full hours reports, `numberOfDataPoints` column has the number of hours that observation was available within a day.
#' 
## ------------------------------------------------------------------------
names(prcpData)[names(prcpData) == 'value'] <- 'DEL_ACCPRCP'
dailyData <- CalcDailyGhcn(sg = sg,prcp = prcpData)
head(dailyData)

#' 
#' ### Comparing daily QPE/QPF versus GHCN-D
#' 
#' Final step if to find the common data between the two dataset (precipitation time series (`dailyData`) and the observed GHCN-D (`obsPrcp`)). This can be very fast if using data.table.   
#' 
## ------------------------------------------------------------------------
#usind data.table merge
common <- data.table:::merge.data.table(data.table::as.data.table(dailyData),
                                        data.table::as.data.table(obsPrcp),
                                        by.x=c("ghcnDay","statArg"),
                                        by.y=c("Date","siteIds"))
head(common)

#' 
#' Call the `CalcStatCont` function and it returns all the requested statistics.  The default are `numPaired` (number of paired data), `meanObs` (mean of observation data), `meanMod` (mean of model/forecast data), `pearsonCor` (Pearson correlation coefficient), `RMSE` (root mean square error), and `multiBias` (multiplicative bias). Here we want to get the statistics for each gauge, therefore, we need to group the data for each gauge. This can be done by defining `groupBy` to be the column name having siteIds, here `statArg`.
#' 
## ----plot1, fig.width = 8, fig.height = 8, out.width='600', out.height='600'----
stat <- CalcStatCont(DT = common, obsCol = "dailyGhcn", modCol = "dailyPrcp" , 
                     obsMissing = -999.9, groupBy = "statArg")

# CalcStatCont will return a list having two elements of stat and plotList.
names(stat)

#To check the statistics 
stat$stat

#' 
#' If the `groupBy` is `NULL` then it will return four informative plots. 
#' 
## ----plot2, fig.width = 8, fig.height = 8, out.width='600', out.height='600'----
common2 <- common[statArg == unique(statArg)[1]]
stat <- CalcStatCont(DT = common2, obsCol = "dailyGhcn", modCol = "dailyPrcp", obsMissing = -999.9, title = common2$statArg)

#' 
#' You can choose among the four plots by changing the `plot.list` argument. 
#' 
## ----plot3, fig.width = 8, fig.height = 8, out.width='600', out.height='600'----
stat <- CalcStatCont(DT = common2, obsCol = "dailyGhcn", modCol = "dailyPrcp" , obsMissing = -999.9, plot.list = "scatterPlot")

#' 
#' You can also calculate conditional statistics by defining the boundaries you are interested in. For example, here we calculate the statistics conditioned on the observation to be greater than 1 mm. 
#' 
## ----plot4, fig.width = 8, fig.height = 8, out.width='600', out.height='600'----
stat <- CalcStatCont(DT = common2, obsCol = "dailyGhcn", modCol = "dailyPrcp" , 
                     obsCondRange = c(1, Inf), plot.list = "scatterPlot")

#' 
#' ### Calculate statistics over RFCs
#' 
#' Sometime the verification result at the gauge location is not desired and we want to find the performance of a model over a domain or polygon. If you want to calculate statistics over RFC's, then use `GetRfc` function. One can find out a gauge (point) falls in which RFC using `GetRfc`. You simply feed a dataframe having at least two columns of `latitude` and `longitude` and this functions adds a column to a dataframe with RFC name.
#' 
## ------------------------------------------------------------------------
# add rfc name
sg <- GetRfc(sg)

# check what is been added
head(sg)

#' 
#' Now, add a column to the `common` data having the `rfc` information for each data. And calculate the statistics based on grouping by RFC. 
#' 
## ------------------------------------------------------------------------
# merge the common data.table with the sg data.frame
common <- data.table:::merge.data.table(common,data.table::as.data.table(sg[, c("siteIds", "rfc")]),
                                        by.x=c("statArg"),
                                        by.y=c("siteIds"))

# calculate statistics using grouping by rfc
stat <- CalcStatCont(DT = common, obsCol = "dailyGhcn", modCol = "dailyPrcp" , 
                     groupBy = "rfc", obsMissing = -999.9, plot.it = FALSE)

stat$stat

#' 
#' As you see above, all the gauges belong to one rfc (`MBRFC`), therefore there will be only one category.
#' 
#' ### Calculate statistics over polygons
#' 
#' One can calculate the statistics over any desired polygon shapefile. First, you need to use `GetPoly` function to find each point falls into which polygon. `GetPoly` takes a dataframe containing at least two fields of `latitude` and `longitude`, overlays the points with a `SpatialPolygonDataFrame` and return the requested attribute from the polygon. You can use the available `SpatialPolygon*` loaded into memory or provide the address to the location of a polygon shapefile and the name of the shapefile. 
#' The clipped HUC12 shapefile is provided with the test case. The northeast of the clipped polygon covers partially the Fourmile Creek domain. Here, we ty to find the corresponding polygon to each gauge and calculate the statistics over those polygons. 
#' 
## ----results="hide", message=FALSE, warning=FALSE------------------------
# add HUC12 ids
polygonAddress <- paste0(path.expand(fcPath), "/polygons")
sg <- GetPoly (sg,  polygonAddress = polygonAddress,
               polygonShapeFile = "clipped_huc12",
               join="HUC12")

# check what is been added
head(sg)

# merge the common data.table with the sg data.frame
common <- data.table:::merge.data.table(common,data.table::as.data.table(sg[, c("siteIds","HUC12")]),
                                        by.x=c("statArg"),
                                        by.y=c("siteIds"))

# calculate statistics using grouping by HUC12
stat <- CalcStatCont(DT = common, obsCol = "dailyGhcn", modCol = "dailyPrcp", 
                     obsMissing = -999.9, groupBy = "HUC12", plot.it = FALSE)
stat$stat

#' 
#' All the gauges with available data belong to one HUC12, therefore there is only one category.
#' 
#' ### Calculate categorical statistics
#' 
#' You can also calculate some of the categorical statistics using `CalcStatCategorical` function. It accepts both categorical variable and continuous ones.
#' If the data is actually categorical, variable `category` should be defined. The elements in `category` will be used as `YES` and `NO` in contingency table. If the data is numeric, then a set of thresholds should be defined. Values exceeding the threshold would be flagged as `YES` and the values below the threshold are considered `NO`. 
#' You can choose from the available statistics by changing the `statList` argument. By default, it calculates the Hit Rate (H), False Alarm Ratio (FAR) and Critical Success Index (CSI). 
#' The grouping option is similar to `CalcStatCont`.
#' 
## ------------------------------------------------------------------------
# calculate categorical statistics
stat <- CalcStatCategorical(DT = common, obsCol = "dailyGhcn", modCol = "dailyPrcp", 
                            obsMissing = -999.9, groupBy = "statArg", threshold = c(1,5))
stat

