#!/opt/R/bin/Rscript
## arguments are
## 1: queryTime: character, the dateId denoting the query time.
## 2  inPath:    character, the path for the input files. 
## 2: outPath:   character, the directory where the output is to be placed.
suppressPackageStartupMessages(library(rwrfhydro))

args <- commandArgs(TRUE)

## arg 1: huc
queryTime <- args[1]

## arg 2: inPath
inPath <- args[2]
if(!file.exists(inPath)) {
  warning(paste0('inPath DNE: ',inPath))
  return(NULL)
}

## arg 2: outPath
outPath <- args[3]
if(!file.exists(outPath)) {
  warning(paste0('outPath DNE: ',outPath))
  return(NULL)
}

queryFiles <- list.files(path=inPath, pattern=queryTime, 
                         full.name=TRUE)
if(!length(queryFiles)) {
  write("There were no real time files to process!", stderr())
}

suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(doMC))
registerDoMC(16)

oldest <- as.POSIXct('2015-04-15 00:00:00', tz='UTC')
nearest <- 60
#options(warn=1)
ret1 <- MkUsgsTimeSlice( queryFiles, outPath=outPath, 
                         nearest=nearest, oldest=oldest )


## a message for standard out diagnostics
print(ret1)