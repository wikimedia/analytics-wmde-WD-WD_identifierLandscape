#!/usr/bin/env Rscript

### ---------------------------------------------------------------------------
### --- WD_IdentifierLandscape_Data.R
### --- Author(s): Goran S. Milovanovic, Data Scientist, WMDE
### --- Developed under the contract between Goran Milovanovic PR Data Kolektiv
### --- and WMDE.
### --- Contact: goran.milovanovic_ext@wikimedia.de
### --- June 2020.
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
library(XML)
library(tidyverse)
library(data.table)
library(spam)
library(spam64)
# - note: GitHub repo dselivanov/text2vec@0.5.0
# - install_github('dselivanov/text2vec@0.5.0')
library(text2vec)
library(Rtsne)
library(igraph)
library(plotly)

# - to runtime Log:
print(paste("--- WD_IndentifierLandscape.R RUN STARTED ON:", 
            Sys.time(), sep = " "))
# - GENERAL TIMING:
generalT1 <- Sys.time()

# - to runtime Log:
print(paste("--- WD_IndentifierLandscape.R: Init.", 
            Sys.time(), sep = " "))

### --- Read WEIP paramereters
# - to runtime Log:
print(paste("--- WD_IndentifierLandscape.R: Read params.", 
            Sys.time(), sep = " "))
# - fPath: where the scripts is run from?
fPath <- as.character(commandArgs(trailingOnly = FALSE)[4])
fPath <- gsub("--file=", "", fPath, fixed = T)
fPath <- unlist(strsplit(fPath, split = "/", fixed = T))
fPath <- paste(
  paste(fPath[1:length(fPath) - 1], collapse = "/"),
  "/",
  sep = "")
params <- xmlParse(paste0(fPath, 
                          "WDIdentifiersLandscape_Config.xml"))
params <- xmlToList(params)

### --- Directories
# - to runtime Log:
print(paste("--- WD_IndentifierLandscape.R: dirTree.", 
            Sys.time(), sep = " "))
# - form paths:
dataDir <- params$general$dataDir
logDir <- params$general$logDir
analysisDir <- params$general$analysisDir
etl_hdfsDir <- params$general$etl_hdfsDir
# - production published-datasets:
publicDir <- params$general$publicDir
# - endpoint for Blazegraph GAS program  
endPointURL <- params$general$wdqs_endpoint

# - spark2-submit parameters:
paramsDeploy <- xmlParse(paste0(fPath, 
                          "WDIdentifiersLandscape_Config_Deploy.xml"))
paramsDeploy <- xmlToList(paramsDeploy)
sparkMaster <- paramsDeploy$spark$master
sparkDeployMode <- paramsDeploy$spark$deploy_mode
sparkNumExecutors <- paramsDeploy$spark$num_executors
sparkDriverMemory <- paramsDeploy$spark$driver_memory
sparkExecutorMemory <- paramsDeploy$spark$executor_memory
sparkExecutorCores <- paramsDeploy$spark$executor_cores
sparkConfigDynamic <- paramsDeploy$spark$config

### --- Fetch all Wikidata external identifiers
# - to runtime Log:
print(paste("--- WD_IndentifierLandscape.R: WDQS: fetch identifiers.", 
            Sys.time(), sep = " "))
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
} else {
  # - to report:
  print("Fetching identifiers from WDQS failed.")
  print("Exiting.")
  quit(save = "no")
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
# - to runtime Log:
print(paste("--- WD_IndentifierLandscape.R: Store identifiers (analysisDir).", 
            Sys.time(), sep = " "))
write.csv(identifiers, 
          paste0(analysisDir, "WD_ExternalIdentifiers_DataFrame.csv"))

### --- Fetch the sub-classes of all
### -- Wikidata external identifier classes
# - to runtime Log:
print(paste("--- WD_IndentifierLandscape.R: WDQS: Fetch the sub-classes of all external identifier classes.", 
            Sys.time(), sep = " "))
weiClasses <- unique(identifiers$class)
weiClassesTable <- vector(mode = 'list', length = length(weiClasses))
for (i in 1:length(weiClasses)) {
  # - to runtime Log:
  print(paste0("Fetching sub-class: ", i, ". out of ", length(weiClasses), "."))
  query <- paste0('SELECT ?class ?classLabel { ?class wdt:P279/wdt:P279* wd:', 
                  weiClasses[i], 
                  ' . SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }}')
  res <- tryCatch({
    res <- GET(url = paste0(endPointURL, URLencode(query)))
  }, 
  error = function(condition){
    return(FALSE)
  },
  warning = function(condition) {
    return(FALSE)
  })
  if (!(class(res) == "logical")) {
    if (res$status_code == 200) {
      # - fromJSON
      wT <- fromJSON(rawToChar(res$content), simplifyDataFrame = T)
    }
    if (class(wT$results$bindings) == "data.frame") {
      weiClassesTable[[i]] <- data.frame(class = weiClasses[i], 
                                    subClass = gsub("http://www.wikidata.org/entity/", 
                                                      "", 
                                                    wT$results$bindings$class$value),
                                    subClassLabel = wT$results$bindings$classLabel$value,
                                    stringsAsFactors = F)
    } else {
      weiClassesTable[[i]] <- NULL
    }
  } else {
    weiClassesTable[[i]] <- NULL
  }
  Sys.sleep(1)
}
weiClassesTable <- rbindlist(weiClassesTable)
weiClassesTable <- 
  filter(weiClassesTable, 
         subClass %in% weiClasses)
# - store weiClassesTable
# - to runtime Log:
print(paste("--- WD_IndentifierLandscape.R: Store the sub-classes of all external identifier classes (analysisDir).", 
            Sys.time(), sep = " "))
write.csv(weiClassesTable, 
          paste0(analysisDir, "WD_ExternalIdentifiers_SubClasses.csv"))

### --- Run ETL Procedure from WD dump:
### --- WD_IdentifierLandscape_Data.py

# - toRuntime Log:
print(paste("--- WD_IndentifierLandscape.R: prepare ETL phase, clean dataDir: ", 
            Sys.time(), sep = " "))
file.remove(list.files(dataDir))

# - toRuntime Log:
print(paste("--- WD_IndentifierLandscape.R: prepare ETL phase, Kerberos init: ", 
            Sys.time(), sep = " "))
# - Kerberos init
system(command = 'sudo -u analytics-privatedata kerberos-run-command analytics-privatedata hdfs dfs -ls', 
       wait = T)

# - toRuntime Log:
print(paste("--- WD_IndentifierLandscape.R: Pyspark ETL, WD_IdentifierLandscape_Data.py: starts: ", 
            Sys.time(), sep = " "))

system(command = paste0('sudo -u analytics-privatedata spark2-submit ', 
                        sparkMaster, ' ',
                        sparkDeployMode, ' ', 
#                        sparkNumExecutors, ' ',
                        sparkDriverMemory, ' ',
                        sparkExecutorMemory, ' ',
                        sparkExecutorCores, ' ', 
                        '--conf spark.dynamicAllocation.maxExecutors=100 --conf spark.executor.extraJavaOptions=-Dlog4j.configuration=/etc/spark2/defaults/log4j.properties --conf spark.driver.extraJavaOptions=-Dlog4j.configuration=/etc/spark2/defaults/log4j.properties ',
                        paste0(fPath, 'WD_IdentifierLandscape_Data.py')),
       wait = T)

# - toRuntime Log:
print(paste("--- WD_IndentifierLandscape.R: Pyspark ETL, WD_IdentifierLandscape_Data.py: ends: ", 
            Sys.time(), sep = " "))

### --- Compose usage dataset
# - toRuntime Log:
print(paste("--- WD_IndentifierLandscape.R: Compose final usage dataset, copy from hdfs: starts: ", 
            Sys.time(), sep = " "))
if (length(list.files(dataDir)) > 1) {
  file.remove(paste0(dataDir, list.files(dataDir)))
}
# - copy splits from hdfs to local dataDir
# - from statements:
system(paste0('sudo -u analytics-privatedata kerberos-run-command analytics-privatedata hdfs dfs -ls ',
              etl_hdfsDir, 'wd_extId_data_stat_.csv > ', 
              dataDir, 'files.txt'), 
       wait = T)
files <- read.table(paste0(dataDir, 'files.txt'), skip = 1)
files <- as.character(files$V8)[2:length(as.character(files$V8))]
file.remove(paste0(dataDir, 'files.txt'))
for (i in 1:length(files)) {
  system(paste0('sudo -u analytics-privatedata kerberos-run-command analytics-privatedata hdfs dfs -text ', files[i], ' > ',  
                paste0(dataDir, "wd_exts_data_stat_", i, ".csv")), wait = T)
}
# - from references:
system(paste0('sudo -u analytics-privatedata kerberos-run-command analytics-privatedata hdfs dfs -ls ',
              etl_hdfsDir, 'wd_extId_data_ref_.csv > ', 
              dataDir, 'files.txt'), 
       wait = T)
files <- read.table(paste0(dataDir, 'files.txt'), skip = 1)
files <- as.character(files$V8)[2:length(as.character(files$V8))]
file.remove(paste0(dataDir, 'files.txt'))
for (i in 1:length(files)) {
  system(paste0('sudo -u analytics-privatedata kerberos-run-command analytics-privatedata hdfs dfs -text ', files[i], ' > ',  
                paste0(dataDir, "wd_exts_data_ref_", i, ".csv")), wait = T)
}
# - from qualifiers:
system(paste0('sudo -u analytics-privatedata kerberos-run-command analytics-privatedata hdfs dfs -ls ',
              etl_hdfsDir, 'wd_extId_data_qual_.csv > ', 
              dataDir, 'files.txt'), 
       wait = T)
files <- read.table(paste0(dataDir, 'files.txt'), skip = 1)
files <- as.character(files$V8)[2:length(as.character(files$V8))]
file.remove(paste0(dataDir, 'files.txt'))
for (i in 1:length(files)) {
  system(paste0('sudo -u analytics-privatedata kerberos-run-command analytics-privatedata hdfs dfs -text ', files[i], ' > ',  
                paste0(dataDir, "wd_exts_data_qual_", i, ".csv")), wait = T)
}
# - toRuntime Log:
print(paste("--- WD_IndentifierLandscape.R: Compose final usage dataset, copy from hdfs: ends: ", 
            Sys.time(), sep = " "))

### --- read splits: dataSet
# - toRuntime Log:
print(paste("--- WD_IndentifierLandscape.R: Load hdfs splits -> produce usage dataset, starts: ", 
            Sys.time(), sep = " "))
# - load
lF <- list.files(dataDir)
lF <- lF[grepl("data", lF)]
dataSet <- lapply(paste0(dataDir, lF), function(x) {fread(x, header = F)})
# - collect
dataSet <- rbindlist(dataSet)
colnames(dataSet) <- c('item', 'property')
# - toRuntime Log:
print(paste("--- WD_IndentifierLandscape.R: Load hdfs splits -> produce usage dataset, ends: ", 
            Sys.time(), sep = " "))
# - clean up item column
# - how many missing data in the item column
wMissItem <- which(is.na(dataSet$item))
nMissItem <- length(wMissItem)
print(paste0("Check, N missing items: ", nMissItem))
# - clean up property column
# - how many missing data in the property column
wMissProperty <- which(is.na(dataSet$property))
nMissProperty <- length(wMissProperty)
print(paste0("Check, N missing properties: ", nMissProperty))
# - clean up dataSet from NAs
rrow <- unique(c(wMissItem, wMissProperty))
if (length(rrow) > 0) {
  dataSet <- dataSet[-rrow, ]
}
# - remove duplicated rows, if any
dataSet <- dataSet[!duplicated(dataSet), ]

### --- Enrich identifiers data from final usage dataset
identifiers$used <- F
wUsed <- which(identifiers$property %in% unique(dataSet$property))
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
                         unique(rownames(dat))) 
classesUsed <- unique(identifiers$class[wPropertyUsed])
stats$N_total_identifier_classes_used <- length(classesUsed)
# - compute identifier usage
identifierUsage <- dataSet %>% 
  group_by(property) %>% 
  summarise(usage = n())
# - clean up: dataSet
rm(dataSet); gc()
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
# - sum of co-occurences for each identifier
co_identifier <- rowSums(co_occur)
# - store identifier co-occurences
write.csv(co_occur, 
          paste0(analysisDir, "WD_ExternalIdentifiers_Co-Occurence.csv"))

# - comput Jaccard Similarity Matrix
t1 <- Sys.time()
print(paste0("Jaccard distance matrix, start: ", Sys.time()))
distMatrix <- text2vec::sim2(x = dat, y = NULL,
                             method = "jaccard",
                             norm = "none")
print(paste0("Jaccard distance matrix in: ", Sys.time() - t1))
rm(dat); gc()

# - Jaccard similarity index to Jaccard distance
distMatrix <- as.matrix(1 - distMatrix)
diag(distMatrix) <- 0
distMatrix <- as.data.frame(distMatrix)
rownames(distMatrix) <- rownames(distMatrix)
colnames(distMatrix) <- colnames(distMatrix)
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
print(paste("--- tSNE on Jaccard Similarity Matrix starts:", 
            Sys.time(), sep = " "))
# - matrix
m <- dplyr::select(distMatrix, -label, -coOccur, -usage)
# - tSNE dimensionality reduction
t1 <- Sys.time()
tsneMap <- Rtsne(as.matrix(m),
                 theta = 0,
                 is_distance = T,
                 tsne_perplexity = 10, 
                 max_iter = 5000, 
                 verbose = T)
# - to runtime Log:
print(paste0("tSNE done in: ", Sys.time() - t1))
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
# - to runtime Log:
print(paste("--- tSNE on Jaccard Similarity Matrix ends:", 
            Sys.time(), sep = " "))
print(paste0("--- tSNE on Jaccard Similarity Matrix done in: ", Sys.time() - t1))

### --- Pre-process for the WD Identifier Landscape
# - to runtime Log:
print(paste("--- Pre-process for the WD Identifier Landscape now:", 
            Sys.time(), sep = " "))
### --- Dashboard
wd_IdentifiersFrame <- identifiers
ids <- wd_IdentifiersFrame %>% 
  select(property, label, used)
ids <- ids[!duplicated(ids), ]
colnames(ids) <- c('identifier', 'identifierLabel', 'identifierUsed')
identifierClass <- wd_IdentifiersFrame %>% 
  select(class, classLabel)
identifierClass <- identifierClass[!duplicated(identifierClass), ]
usedIdentifierLabels <- unique(wd_IdentifiersFrame$label[wd_IdentifiersFrame$used == T])
usedClassLabels <- unique(wd_IdentifiersFrame$classLabel[wd_IdentifiersFrame$used == T])
# - fix wd_CoOccurence
# - to runtime Log:
print(paste("--- fix wd_CoOccurence now:", 
            Sys.time(), sep = " "))
wd_CoOccurence <- co_occur
coOcCols <- data.frame(cols = colnames(wd_CoOccurence), 
                       stringsAsFactors = F)
coOcCols <- left_join(coOcCols, ids, 
                      by = c('cols' = 'identifier'))
coOcCols$identifierLabel[is.na(coOcCols$identifierLabel)] <- 
  coOcCols$cols[is.na(coOcCols$identifierLabel)]
coOcCols$identifierLabel <- paste0(coOcCols$identifierLabel, " (", coOcCols$cols, ")")
colnames(wd_CoOccurence) <- coOcCols$identifierLabel
wd_CoOccurence <- as.data.frame(wd_CoOccurence)
wd_CoOccurence$Identifier <- coOcCols$identifierLabel
# - identifierConnected for similarityGraph 
# - to runtime Log:
print(paste("--- produce identifierConnected for similarityGraph now:", 
            Sys.time(), sep = " "))
identifierConnected <- gather(wd_CoOccurence,
                              key = Code,
                              value = coOcur,
                              -Identifier) %>%
  arrange(Code, Identifier, desc(coOcur)) %>%
  filter(coOcur != 0)
iC <- lapply(unique(identifierConnected$Code), function(x){
  d <- identifierConnected[identifierConnected$Code == x, ]
  w <- which(d$coOcur == max(d$coOcur))
  d$Identifier[w]
})
names(iC) <- unique(identifierConnected$Code)
identifierConnected <- stack(iC)
colnames(identifierConnected) <- c('Incoming', 'Outgoing')
# - produce Identifier Landscape Graph
idNet <- data.frame(from = identifierConnected$Outgoing,
                    to = identifierConnected$Incoming,
                    stringsAsFactors = F)
idNet <- graph.data.frame(idNet,
                          vertices = NULL,
                          directed = T)
# - to runtime Log:
print(paste("--- Fruchterman and Reingold from idNet now:", 
            Sys.time(), sep = " "))
L <- layout_with_fr(idNet, grid = "nogrid")
# - store Identifier Landscape Graph
saveRDS(L, paste0(analysisDir,
                  "WD_ExternalIdentifiers_Graph.Rds"))
# - store Identifier Landscape Graph as.data.frame
L <- as.data.frame(L)
write.csv(L, paste0(analysisDir, 
                 "WD_ExternalIdentifiers_Graph.csv"))
# - store identifierConnected
write.csv(identifierConnected, 
          paste0(analysisDir, 
                 "WD_IdentifierConnected.csv"))

### --- Structure for identifier neighbourhood graphs
# - to runtime Log:
print(paste("--- Structure for identifier neighbourhood graphs now:", 
            Sys.time(), sep = " "))
identifierConnected10 <- gather(wd_CoOccurence,
                                key = Code,
                                value = coOcur,
                                -Identifier) %>%
  arrange(Code, Identifier, desc(coOcur)) %>%
  filter(coOcur != 0)
iC <- lapply(unique(identifierConnected10$Code), function(x){
  d <- identifierConnected10[identifierConnected10$Code == x, ]
  w <- which(d$coOcur %in% sort(d$coOcur, decreasing = T)[1:10])
  d$Identifier[w]
})
names(iC) <- unique(identifierConnected10$Code)
identifierConnected10 <- stack(iC)
colnames(identifierConnected10) <- c('Incoming', 'Outgoing')
# - store identifierConnected10
write.csv(identifierConnected10, 
          paste0(analysisDir, 
                  "WD_identifierConnected10.csv"))

### --- Final operations: copy to public dir
print(paste("--- Final operations: copy to public dir now:", 
            Sys.time(), sep = " "))

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
print(paste("--- WD_IndentifierLandscape.R RUN COMPLETED ON: ", 
            Sys.time(), sep = " "))

# - GENERAL TIMING:
print(paste("--- WD_IndentifierLandscape.R TOTAL RUNTIME: ", 
            Sys.time() - generalT1, sep = " "))

