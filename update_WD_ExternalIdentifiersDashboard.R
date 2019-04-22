### ---------------------------------------------------------------------------
### --- WD External Identifiers Dashboard, v. 0.0.1
### --- Script: update_WD_ExternalIdentifiersDashboard.R, v. 0.0.1
### ---------------------------------------------------------------------------

### ---------------------------------------------------------------------------
### --- WD_IdentifierLandscape_Data.R
### --- Author(s): Goran S. Milovanovic, Data Scientist, WMDE
### --- Developed under the contract between Goran Milovanovic PR Data Kolektiv
### --- and WMDE.
### --- Contact: goran.milovanovic_ext@wikimedia.de
### --- March 2019.
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
library(XML)
library(data.table)
library(dplyr)

### --- functions
get_WDCM_table <- function(url_dir, filename, row_names) {
  read.csv(paste0(url_dir, filename), 
           header = T, 
           stringsAsFactors = F,
           check.names = F)
}

### --- Config File
params <- xmlParse('config_WD_ExternalIdentifiersDashboard.xml')
params <- xmlToList(params)

### --- fetch WD_ExternalIdentifiers_DataFrame.csv
print(paste0("Fetching: ", "WD_ExternalIdentifiers_DataFrame.csv"))
wd_IdentifiersFrame <- get_WDCM_table(params$publicDir, 
                                      'WD_ExternalIdentifiers_DataFrame.csv', 
                                      row_names = F)
colnames(wd_IdentifiersFrame)[1] <- 'rn'
wd_IdentifiersFrame <- dplyr::filter(wd_IdentifiersFrame, 
                              grepl("^Wikidata", wd_IdentifiersFrame$classLabel))
write.csv(wd_IdentifiersFrame, paste0(params$dashboardDataDir, 
                                      "WD_ExternalIdentifiers_DataFrame.csv"))

### --- fetch WD_ExternalIdentifiers_Graph.Rds
print(paste0("Fetching: ", "WD_ExternalIdentifiers_Graph.Rds"))
wd_Graph <- readRDS(gzcon(url(paste0(params$publicDir, 
                                     "WD_ExternalIdentifiers_Graph.Rds"))))
saveRDS(wd_Graph, paste0(params$dashboardDataDir,
                         "WD_ExternalIdentifiers_Graph.Rds"))

### --- fetch wd_SubClasses
print(paste0("Fetching: ", "WD_ExternalIdentifiers_SubClasses.csv"))
wd_SubClasses <- get_WDCM_table(params$publicDir,
                                'WD_ExternalIdentifiers_SubClasses.csv',
                                row_names = F)
colnames(wd_SubClasses)[1] <- 'rn'
write.csv(wd_SubClasses, paste0(params$dashboardDataDir, 
                           "WD_ExternalIdentifiers_SubClasses.csv"))

### --- fetch WD_ExternalIdentifiers_tsneMap.csv
print(paste0("Fetching: ", "WD_ExternalIdentifiers_tsneMap.csv"))
wd_Map <- get_WDCM_table(params$publicDir,
                         'WD_ExternalIdentifiers_tsneMap.csv',
                         row_names = F)
write.csv(wd_Map, paste0(params$dashboardDataDir,
                         "WD_ExternalIdentifiers_tsneMap.csv"))

### --- fetch WD_ExternalIdentifiers_Co-Occurence.csv
print(paste0("Fetching: ", "WD_ExternalIdentifiers_Co-Occurence.csv"))
wd_CoOccurence <- get_WDCM_table(params$publicDir,
                                 'WD_ExternalIdentifiers_Co-Occurence.csv',
                                 row_names = F)
colnames(wd_CoOccurence)[1] <- 'Identifier'
write.csv(wd_CoOccurence, paste0(params$dashboardDataDir,
                         "WD_ExternalIdentifiers_Co-Occurence.csv"))

### --- fetch WD_ExternalIdentifiers_JaccardDistance.csv
print(paste0("Fetching: ", "WD_ExternalIdentifiers_JaccardDistance.csv"))
wd_Jaccard <- get_WDCM_table(params$publicDir,
                             'WD_ExternalIdentifiers_JaccardDistance.csv',
                             row_names = F)
write.csv(wd_Jaccard, paste0(params$dashboardDataDir,
                             "WD_ExternalIdentifiers_JaccardDistance.csv"))

### --- fetch WD_ExternalIdentifiers_Stats.csv
print(paste0("Fetching: ", "WD_ExternalIdentifiers_Stats.csv"))
wd_Stats <- get_WDCM_table(params$publicDir,
                           'WD_ExternalIdentifiers_Stats.csv',
                           row_names = F)
write.csv(wd_Stats, paste0(params$dashboardDataDir,
                           "WD_ExternalIdentifiers_Stats.csv"))

### --- fetch WD_ExternalIdentifiers_Usage.csv
print(paste0("Fetching: ", "WD_ExternalIdentifiers_Usage.csv"))
wd_Usage <- get_WDCM_table(params$publicDir,
                           'WD_ExternalIdentifiers_Usage.csv',
                           row_names = F)
# - add use column to wd_IndentifiersFrame
wd_IdentifiersFrame$used <- wd_IdentifiersFrame$property %in% wd_Usage$property
write.csv(wd_Usage, paste0(params$dashboardDataDir,
                           "WD_ExternalIdentifiers_Usage.csv"))

### --- fetch WD_identifierConnected.csv
print(paste0("Fetching: ", "WD_IdentifierConnected.csv"))
identifierConnected <- get_WDCM_table(params$publicDir,
                                      'WD_IdentifierConnected.csv',
                                      row_names = F)
colnames(identifierConnected)[1] <- 'rn'
write.csv(identifierConnected, paste0(params$dashboardDataDir,
                                      "WD_IdentifierConnected.csv"))

### --- fetch WD_identifierConnected10.csv
print(paste0("Fetching: ", "WD_identifierConnected10.csv"))
identifierConnected10 <- get_WDCM_table(params$publicDir,
                                        'WD_identifierConnected10.csv',
                                        row_names = F)
colnames(identifierConnected10)[1] <- 'rn'
write.csv(identifierConnected10, paste0(params$dashboardDataDir,
                                        "WD_identifierConnected10.csv"))

### --- Fetch update info
print(paste0("Fetching: ", "WD_ExtIdentifiers_UpdateInfo.csv"))
updateInfo <- get_WDCM_table(params$publicDir,
                             'WD_ExtIdentifiers_UpdateInfo.csv',
                             row_names = F) 
write.csv(updateInfo, paste0(params$dashboardDataDir,
                             "WD_ExtIdentifiers_UpdateInfo.csv"))

