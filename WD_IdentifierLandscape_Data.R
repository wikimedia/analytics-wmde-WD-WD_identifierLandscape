
### ---------------------------------------------------------------------------
### --- WD_IdentifierLandscape_Data.R
### --- Author(s): Goran S. Milovanovic, Data Scientist, WMDE
### --- Developed under the contract between Goran Milovanovic PR Data Kolektiv
### --- and WMDE.
### --- Contact: goran.milovanovic_ext@wikimedia.de
### --- March 2019.
### ---------------------------------------------------------------------------
### --- COMMENT:
### --- R data wrangling and statistical procedures forWD JSON dumps in hdfs
### --- NOTE: launches WD_IdentifierLandscape_Data.py on WMF Analytics
### --- Cluster for ETL (Pyspark)
### ---------------------------------------------------------------------------
### ---------------------------------------------------------------------------
### --- LICENSE:
### ---------------------------------------------------------------------------
### --- GPL v2
### --- This file is part of the Wikidata External Identifiers Project (WEIP)
### ---
### --- WEIP is free software: you can redistribute it and/or modify
### --- it under the terms of the GNU General Public License as published by
### --- the Free Software Foundation, either version 2 of the License, or
### --- (at your option) any later version.
### ---
### --- WEIP is distributed in the hope that it will be useful,
### --- but WITHOUT ANY WARRANTY; without even the implied warranty of
### --- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
### --- GNU General Public License for more details.
### ---
### --- You should have received a copy of the GNU General Public License
### --- along with WEIP If not, see <http://www.gnu.org/licenses/>.
### ---------------------------------------------------------------------------

### --- Setup
library(httr)
library(jsonlite)
library(data.table)
library(dplyr)
library(XML)
library(spam)
library(spam64)
library(text2vec)
library(Rtsne)
library(htmltab)
library(stringr)

# - to runtime Log:
print(paste("--- WD_IndentifierLandscape.R RUN STARTED ON:", 
            Sys.time(), sep = " "))
# - GENERAL TIMING:
generalT1 <- Sys.time()

### --- Read WEIP paramereters
# - fPath: where the scripts is run from?
fPath <- as.character(commandArgs(trailingOnly = FALSE)[4])
fPath <- gsub("--file=", "", fPath, fixed = T)
fPath <- unlist(strsplit(fPath, split = "/", fixed = T))
fPath <- paste(
  paste(fPath[1:length(fPath) - 1], collapse = "/"),
  "/",
  sep = "")
params <- xmlParse(paste0(fPath, "WDIdentifiersLandscape_Config.xml"))
params <- xmlToList(params)

### --- Directories
# - form paths:
dataDir <- params$general$dataDir
logDir <- params$general$logDir
analysisDir <- params$general$analysisDir
# - production published-datasets:
publicDir <- params$general$publicDir
# - spark2-submit parameters:
sparkMaster <- params$spark$master
sparkDeployMode <- params$spark$deploy_mode
sparkNumExecutors <- params$spark$num_executors
sparkDriverMemory <- params$spark$driver_memory
sparkExecutorMemory <- params$spark$executor_memory
sparkExecutorCores <- params$spark$executor_cores
# - endpoint for Blazegraph GAS program  
endPointURL <- params$general$wdqs_endpoint

### --- Fetch all Wikidata external identifiers
# - Set proxy
Sys.setenv(
  http_proxy = params$general$http_proxy,
  https_proxy = params$general$https_proxy)
# - endPoint:
# - Fetch identifiers from SPARQL endpoint
# - Q19847637: Wikidata property for an identifier
query <- 'SELECT ?item ?itemLabel ?class ?classLabel {
  ?item wdt:P31/wdt:P279* wd:Q19847637 .
  ?item wdt:P31 ?class .
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
  }'
res <- GET(url = paste0(endPointURL, URLencode(query)))
# - External Identifers to a data.frame
if (res$status_code == 200) {
  # - fromJSON
  identifiers <- fromJSON(rawToChar(res$content), simplifyDataFrame = T)
  # clear:
  rm(res); gc()
}
identifiers <- data.frame(property = identifiers$results$bindings$item$value, 
                          label = identifiers$results$bindings$itemLabel$value,
                          class = identifiers$results$bindings$class$value, 
                          classLabel = identifiers$results$bindings$classLabel$value,
                          stringsAsFactors = F)
# - clean up identifiers$property, identifiers$class
identifiers$property <- gsub("http://www.wikidata.org/entity/", "", identifiers$property)
identifiers$class <- gsub("http://www.wikidata.org/entity/", "", identifiers$class)
# - store identifiers
write.csv(identifiers, paste0(analysisDir, "WD_ExternalIdentifiers_DataFrame.csv"))

### --- Run ETL Procedure from WD dump:
### --- WD_IdentifierLandscape_Data.py

# - toRuntime Log:
# - to runtime Log:
print(paste("--- WD_IndentifierLandscape.py Pyspark ETL Procedurs STARTED ON:", 
            Sys.time(), sep = " "))

# - clean dataDir
setwd(dataDir)
file.remove(list.files())

system(command = paste0('export USER=goransm && nice -10 spark2-submit ', 
                        sparkMaster, ' ',
                        sparkDeployMode, ' ', 
                        sparkNumExecutors, ' ',
                        sparkDriverMemory, ' ',
                        sparkExecutorMemory, ' ',
                        sparkExecutorCores, ' ',
                        paste0(fPath, 'WD_IdentifierLandscape_Data.py')),
       wait = T)

### --- Compose final usage dataset
# - to runtime Log:
print(paste("--- Collect Final Data Set STARTED ON:", 
            Sys.time(), sep = " "))
# - read splits: dataSet
# - load
setwd(dataDir)
dataSet <- lapply(list.files(), fread)
# - collect
dataSet <- rbindlist(dataSet, fill = T, use.names = T)
colnames(dataSet) <- c('item', 'property')
# - clean up item column
# - how many missing data in the item column
wMissItem <- which(is.na(dataSet$item))
nMissItem <- length(wMissItem)
print(paste0("Check, N missing items: ", nMissItem))
dataSet$item <- gsub("Row(id='", "", dataSet$item, fixed = T)
dataSet$item <- gsub("'", "", dataSet$item, fixed = T)
dataSet$item <- gsub("\"", "", dataSet$item, fixed = T)
dataSet$item <- as.numeric(dataSet$item)
# - how many missing data in the item column
wMissItem <- which(is.na(dataSet$item))
nMissItem <- length(wMissItem)
print(paste0("Check, N missing items: ", nMissItem))
# - clean up property column
# - how many missing data in the property column
wMissProperty <- which(is.na(dataSet$property))
nMissProperty <- length(wMissProperty)
print(paste0("Check, N missing properties: ", nMissProperty))
dataSet$property <- gsub("property='", "", dataSet$property, fixed = T)
dataSet$property <- gsub("')\"", "", dataSet$property, fixed = T)
dataSet$property <- as.numeric(dataSet$property)
wMissProperty <- which(is.na(dataSet$property))
nMissProperty <- length(wMissProperty)
print(paste0("Check, N missing properties: ", nMissProperty))
# - clean up from NAs
rrow <- unique(c(wMissItem, wMissProperty))
if (length(rrow) > 0) {
  dataSet <- dataSet[-rrow, ]
}
# - remove duplicated rows
dataSet <- dataSet[!duplicated(dataSet)]
# - store clean dataSet
write.csv(dataSet, 
          paste0(dataDir, 'extIdentifiersData_Long.csv'))

### --- Enrich identifiers data from final usage dataset
identifiers$used <- F
wUsed <- which(gsub("P", "", identifiers$property) %in% 
                 unique(dataSet$property))
identifiers$used[wUsed] <- T
# - store identifiers
write.csv(identifiers, 
          paste0(analysisDir, "WD_ExternalIdentifiers_DataFrame.csv"))

### --- compute similarity structure between identifiers
### --- NOTE: keep track of essential statistics
# - to runtime Log:
print(paste("--- Compute Global Jaccard Similarity Matrix STARTED ON:", 
            Sys.time(), sep = " "))
# - stats list:
stats <- list()
# - stats: N item-identifier pairs
stats$N_item_identifier_pairs <- dim(dataSet)[1]
# - contingency table:
dat <- xtabs(~ property + item, 
             data = dataSet, 
             sparse = T)
# - stats: N of used identifiers
stats$N_identifiers_used <- dim(dat)[1]
# - stats: N of items w. external identifiers
stats$N_items_w_identifiers <- dim(dat)[2]
# - stats: N total number of external identifiers
stats$N_total_identifiers <- length(unique(identifiers$property))
# - stats: N total number of identifier classes
stats$N_total_identifier_classes <- length(unique(identifiers$class))
# - stats: N total number of identifier classes used
wPropertyUsed <- which(unique(identifiers$property) %in% 
                         unique(paste0("P", rownames(dat)))) 
classesUsed <- unique(identifiers$class[wPropertyUsed])
stats$N_total_identifier_classes_used <- length(classesUsed)
# - compute identifier usage
identifierUsage <- dataSet %>% 
  group_by(property) %>% 
  summarise(usage = n())
identifierUsage$property <- paste0("P", identifierUsage$property)
# - joing identifier usage w. identifiers to obtain classes
identifierUsage <- left_join(identifierUsage, identifiers, 
                             by = "property")
identifierUsage$used <- NULL
# - store identifierUsage
write.csv(identifierUsage, 
          paste0(analysisDir, "WD_ExternalIdentifiers_Usage.csv"))
# - compute co-occurences
co_occur <- crossprod.spam(t(dat), y = NULL)
co_occur <- as.matrix(co_occur)
diag(co_occur) <- 0
colnames(co_occur) <- paste0("P", colnames(co_occur))
rownames(co_occur) <- paste0("P", rownames(co_occur))
# - sum of co-occurences for each identifier
co_identifier <- rowSums(co_occur)
# - store identifier co-occurences
write.csv(co_occur, 
          paste0(analysisDir, "WD_ExternalIdentifiers_Co-Occurence.csv"))
# - comput Jaccard Similarity Matrix
t1 <- Sys.time()
distMatrix <- sim2(x = dat, y = NULL, 
                   method = "jaccard", 
                   norm = "none")
print(paste0("Jaccard distance matrix in: ", Sys.time() - t1))
rm(dat); gc()
distMatrix <- as.matrix(1 - distMatrix)
distMatrix <- as.data.frame(distMatrix)
rownames(distMatrix) <- paste0("P", rownames(distMatrix))
colnames(distMatrix) <- paste0("P", colnames(distMatrix))
distMatrix$coOccur <- co_identifier
idUse <- select(identifierUsage, property, usage)
idUse <- idUse[!duplicated(idUse), ]
distMatrix$usage <- idUse$usage
# - add identifier labels
idLabs <- select(identifierUsage, property, label)
idLabs <- idLabs[!duplicated(idLabs), ]
distMatrix$label <- idLabs$label
# - store distMatrix
write.csv(distMatrix, 
          paste0(analysisDir, 
                 "WD_ExternalIdentifiers_JaccardDistance.csv")
          )

### --- produce 2D tSNE identifier map
# - to runtime Log:
print(paste("--- tSNE on Jaccard Similarity Matrix STARTED ON:", 
            Sys.time(), sep = " "))
# - matrix
m <- dplyr::select(distMatrix, -label, -coOccur, -usage)
# - tSNE dimensionality reduction
tsneMap <- Rtsne(m,
                 theta = 0,
                 is_distance = T,
                 tsne_perplexity = 10, 
                 max_iter = 10000)
tsneMap <- tsneMap$Y
colnames(tsneMap) <- c('D1', 'D2')
tsneMap <- cbind(tsneMap, select(distMatrix, label, coOccur, usage))
tsneMap$property <- rownames(distMatrix)
tsneMap <- arrange(tsneMap, desc(usage))
# - store tsneMap
write.csv(tsneMap, 
          paste0(analysisDir, 
                 "WD_ExternalIdentifiers_tsneMap.csv")
)

### --- Exact identifier usage dataset:
prop <- unique(identifiers$property)
prop <- data.frame(property = prop, 
                   stringsAsFactors = F)
### --- fetch property usage data from:
### --- scrape: https://www.wikidata.org/wiki/Wikidata:Database_reports/List_of_properties/all
url <- "https://www.wikidata.org/wiki/Wikidata:Database_reports/List_of_properties/all"
listProps <- htmltab(doc = url, which = 1)
listProps$ID <- str_extract(listProps$ID, "P[[:digit:]]+")
prop <- left_join(prop, select(listProps, ID, label, Count), 
                  by = c('property' = 'ID'))
prop$Count <- gsub(",", "", prop$Count, fixed = T)
prop$Count <- as.numeric(prop$Count)
# - store propCounts
write.csv(prop, paste0(analysisDir, "WD_ExternalIdentifiers_Property_ItemsMarked.csv"))

### --- Final operations
# - to runtime Log:
print(paste("--- WD_IndentifierLandscape.R RUN COMPLETED ON: ", 
            Sys.time(), sep = " "))
# - GENERAL TIMING:
print(paste("--- WD_IndentifierLandscape.R TOTAL RUNTIME: ", 
            Sys.time() - generalT1, sep = " "))

# - UPDATE INFO:
updateInfo <- data.frame(Time = Sys.time())
write.csv(updateInfo, paste0(analysisDir, 'WD_ExtIdentifiers_UpdateInfo.csv'))

### --- Copy the datasets to publicDir
print(paste("--- Copy datasets to public directory: ", 
            Sys.time(), sep = " "))
# - form stats
stats <- as.data.frame(stats)
write.csv(stats, 
          paste0(analysisDir, 
                 "WD_ExternalIdentifiers_Stats.csv")
)
# - copy
system(command = 
         paste0('cp ', analysisDir, '* ' , publicDir),
       wait = T)
# - to runtime Log:
print(paste("--- DONE: ", 
            Sys.time(), sep = " "))




