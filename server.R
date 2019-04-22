### ---------------------------------------------------------------------------
### --- WD External Identifiers Dashboard, v. 0.0.1
### --- Script: server.R, v. 0.0.1
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
### --- general
library(shiny)
library(XML)
library(data.table)
library(DT)
library(stringr)
library(tidyr)
library(dplyr)
library(httr)
library(jsonlite)
### --- compute
library(igraph)
library(plotly)

### --- Server (Session) Scope
### --------------------------------

### --- Config File
params <- xmlParse('config_WD_ExternalIdentifiersDashboard.xml')
params <- xmlToList(params)

### --- shinyServer
shinyServer(function(input, output, session) {
  
  ### --- DATA
  
  withProgress(message = 'Load datasets.', detail = "Please be patient.", value = 0, {
  
    incProgress(1/10, detail = "WD_ExternalIdentifiers_DataFrame")
    ### --- fetch WD_ExternalIdentifiers_DataFrame.csv
    wd_IdentifiersFrame <- fread(paste0(params$dashboardDataDir,
                                           'WD_ExternalIdentifiers_DataFrame.csv'))
    wd_IdentifiersFrame$V1 <- NULL
    
    
    incProgress(1/10, detail = "WD_ExternalIdentifiers_Graph")
    ### --- fetch WD_ExternalIdentifiers_Graph.csv
    wd_Graph <- readRDS(paste0(params$dashboardDataDir,
                               'WD_ExternalIdentifiers_Graph.Rds'))
    
    incProgress(2/10, detail = "WD_ExternalIdentifiers_SubClasses")
    ### --- fetch WD_ExternalIdentifiers_tsneMap.csv
    wd_SubClasses <- fread(paste0(params$dashboardDataDir,
                                        'WD_ExternalIdentifiers_SubClasses.csv'))
    wd_SubClasses$V1 <- NULL
    
    incProgress(3/10, detail = "WD_ExternalIdentifiers_tsneMap")
    ### --- fetch WD_ExternalIdentifiers_tsneMap.csv
    wd_Map <- fread(paste0(params$dashboardDataDir,
                           'WD_ExternalIdentifiers_tsneMap.csv'))
    wd_Map$V1 <- NULL
    
    incProgress(4/10, detail = "WD_ExternalIdentifiers_Co-Occurence")
    ### --- fetch WD_ExternalIdentifiers_Co-Occurence.csv
    wd_CoOccurence <- fread(paste0(params$dashboardDataDir,
                           'WD_ExternalIdentifiers_Co-Occurence.csv'))
    wd_CoOccurence$V1 <- NULL
    
    incProgress(5/10, detail = "WD_ExternalIdentifiers_JaccardDistance")
    ### --- fetch WD_ExternalIdentifiers_JaccardDistance.csv
    wd_Jaccard <- fread(paste0(params$dashboardDataDir,
                                   'WD_ExternalIdentifiers_JaccardDistance.csv'))
    wd_Jaccard$V1 <- NULL
    
    incProgress(6/10, detail = "WD_ExternalIdentifiers_Stats")
    ### --- fetch WD_ExternalIdentifiers_Stats.csv
    wd_Stats <- fread(paste0(params$dashboardDataDir,
                             'WD_ExternalIdentifiers_Stats.csv'))
    wd_Stats$V1 <- NULL
    
    incProgress(7/10, detail = "WD_ExternalIdentifiers_Usage")
    ### --- fetch WD_ExternalIdentifiers_Usage.csv
    wd_Usage <- fread(paste0(params$dashboardDataDir,
                             'WD_ExternalIdentifiers_Usage.csv'))
    wd_Usage$V1 <- NULL
    
    
    incProgress(8/10, detail = "WD_IdentifierConnected")
    # ### --- fetch WD_identifierConnected.csv
    identifierConnected <- fread(paste0(params$dashboardDataDir,
                                        'WD_IdentifierConnected.csv'))
    identifierConnected$V1 <- NULL
    
    incProgress(9/10, detail = "WD_identifierConnected10")
    ### --- fetch WD_identifierConnected10.csv
    identifierConnected10 <- fread(paste0(params$dashboardDataDir,
                                          'WD_identifierConnected10.csv'))
    identifierConnected10$V1 <- NULL
    
    
    incProgress(10/10, detail = "Update Info.")
    ### --- Fetch update info
    updateInfo <- fread(paste0(params$dashboardDataDir,
                               'WD_ExtIdentifiers_UpdateInfo.csv'))
    updateInfo$V1 <- NULL
    
  })
  
  ### --- CONSTANTS
  usedClassLabels <- unique(wd_Usage$classLabel)
  identifiers <- wd_IdentifiersFrame %>% 
    select(property, label, used)
  identifiers <- identifiers[!duplicated(identifiers), ]
  colnames(identifiers) <- c('identifier', 'identifierLabel', 'identifierUsed')
  
  ### --- OUTPUTS
  
  ### --- output: updateString
  output$updateString <- renderText({
    return(paste('<p style="font-size:80%;"align="right"><b>Updated on: </b><i>', updateInfo$Time, '</i></p>', sep = ""))
  })
  
  ### --- output: overview
  output$overview <- renderText({
    return(
      paste0('<p style="font-size:80%;"align="left">',
             '<b>Overview of external identifiers in Wikidata.</b> There are currently <b>', wd_Stats$N_total_identifiers, 
             '</b> external identifiers in Wikidata, of which <b>',
             wd_Stats$N_identifiers_used, ' (',
             round(wd_Stats$N_identifiers_used/wd_Stats$N_total_identifiers*100, 2),
             '%)</b> are used to describe <b>', wd_Stats$N_items_w_identifiers, '</b> items. ',
             'The identifiers themselves belong to <b>', wd_Stats$N_total_identifier_classes, 
             '</b> classes of which <b>', wd_Stats$N_total_identifier_classes_used, ' (', 
             round(wd_Stats$N_total_identifier_classes_used/wd_Stats$N_total_identifier_classes*100, 2),
             '%)</b> are currently used. The following analyses are based on <b>',
             wd_Stats$N_item_identifier_pairs, '</b> item-identifier pairs.',
             '</p>'
             )
      )
  })
  
  ### ----------------------------------
  ### --- TAB: Overview
  ### ----------------------------------
  
  ### ----------------------------------
  ### --- TAB: Similarity Map
  ### ----------------------------------
  
  ### --- SELECT: update select 'globalMap_selectCluster'
  updateSelectizeInput(session,
                       'globalMap_selectCluster',
                       choices = usedClassLabels,
                       selected = 'Wikidata property for authority control',
                       server = TRUE)
  
  ### --- output$globalMap
  output$globalMap <- renderPlotly({
    
    # plotFrame
    plotFrame <- wd_Map %>% 
      select(D1, D2, label, usage)
    plotFrame$Selected = 'Other'
    selectedIds <- 
      unique(wd_IdentifiersFrame$property[wd_IdentifiersFrame$classLabel %in% input$globalMap_selectCluster])
    selectedIdsLabels <- 
      unique(wd_IdentifiersFrame$label[wd_IdentifiersFrame$property %in% selectedIds])
    plotFrame$Selected[plotFrame$label %in% selectedIdsLabels] = input$globalMap_selectCluster
    idsFrame <- data.frame(sId = identifiers$identifier,
                           sIdlabels = identifiers$identifierLabel,
                           stringsAsFactors = F)
    plotFrame <- left_join(plotFrame, idsFrame, 
                           by = c('label' = 'sIdlabels'))
    plotFrame$Id <- paste0(plotFrame$label, " (", plotFrame$sId, ")")
    plotFrame <- plotFrame[-which(is.na(plotFrame$sId)), ]
    plotFrame$size <- log(plotFrame$usage)
    
    # - plotly
    ax <- list(
      title = "",
      zeroline = FALSE,
      showline = FALSE,
      showticklabels = FALSE,
      showgrid = FALSE
    )
    colorVec <- c("grey90", "steelblue")
    colorVec <- setNames(colorVec, levels(plotFrame$Selected))
    plot_ly(data = plotFrame,
            x = ~D1, y = ~D2, 
            mode = "markers",
            color = ~Selected,
            size = ~size,
            colors = colorVec,
            sizes = c(.1, 75),
            text = paste0(plotFrame$label, " (", plotFrame$usage, ")"),
            hoverinfo = "text") %>%
      layout(yaxis = ax,
             xaxis = ax) %>% 
      plotly::config(displayModeBar = TRUE, 
                     displaylogo = FALSE, 
                     collaborate = FALSE, 
                     modeBarButtonsToRemove = list(
                       'lasso2d', 
                       'select2d', 
                       'toggleSpikelines', 
                       'hoverClosestCartesian', 
                       'hoverCompareCartesian', 
                       'autoScale2d'
                     ))
    
  }) %>% withProgress(message = 'Generating plot',
                      min = 0,
                      max = 1,
                      value = 1, {incProgress(amount = 1)})
  
  ### ----------------------------------
  ### --- TAB: Similarity Graph
  ### ----------------------------------
  
  output$similarityGraph <- renderPlotly({
    
    withProgress(message = 'Generating Network.', detail = "Please be patient.", value = 0, {
      
      incProgress(1/7, detail = "Prepare data structures.")
    
      idNet <- data.frame(from = identifierConnected$Outgoing,
                          to = identifierConnected$Incoming,
                          stringsAsFactors = F)
      idNet <- graph.data.frame(idNet,
                                vertices = NULL,
                                directed = T)
      
      # - Layout
      incProgress(2/7, detail = "Rendering graph. Please be patient.")
      L <- wd_Graph
      L <- as.data.frame(L)
      
      # - Attributes
      vs <- V(idNet)
      L$name <- vs$name
      es <- as.data.frame(get.edgelist(idNet))
      Nv <- length(vs)
      Ne <- dim(es)[1]
      Xn <- L[,1]
      Yn <- L[,2]
      a <- rowSums(select(wd_CoOccurence, -Identifier))
      f <- data.frame(summa = a, 
                      id = wd_CoOccurence$Identifier, 
                      stringsAsFactors = F) %>% 
        arrange(desc(summa))
      vsnames <- data.frame(id = vs$name, 
                            prop = str_extract(vs$name, "P[[:digit:]]+"),
                            stringsAsFactors = F)
      vsnames <- left_join(vsnames, f, by = c("prop" = "id"))
      vsnames$prop <- NULL
      # - {plotly}
      incProgress(3/7, detail = "Rendering graph. Please be patient.")
      network <- plot_ly(x = ~Xn, 
                         y = ~Yn, 
                         mode = "markers", 
                         text = paste0(vs$name, " (", vsnames$summa, ")"), 
                         size = vsnames$summa,
                         sizes = c(10, 300),
                         hoverinfo = "text")
      edge_shapes <- list()
      incProgress(4/7, detail = "Rendering graph. Please be patient.")
      for (i in 1:Ne) {
        v0 <- es[i, ]$V1
        v1 <- es[i, ]$V2
        edge_shape = list(
          type = "line",
          line = list(color = "#030303", width = 0.3),
          x0 = Xn[which(L$name == v0)],
          y0 = Yn[which(L$name == v0)],
          x1 = Xn[which(L$name == v1)],
          y1 = Yn[which(L$name == v1)]
        )
        edge_shapes[[i]] <- edge_shape
      }
      axis <- list(title = "", 
                   showgrid = FALSE, 
                   showticklabels = FALSE, 
                   zeroline = FALSE)
      incProgress(5/7, detail = "Rendering graph. Please be patient.")
      p <- layout(
        network,
        shapes = edge_shapes,
        xaxis = axis,
        yaxis = axis
      )
      incProgress(6/7, detail = "Rendering graph. Please be patient.")
      ggplotly(p) %>%
        plotly::config(displayModeBar = TRUE,
                       displaylogo = FALSE,
                       collaborate = FALSE,
                       modeBarButtonsToRemove = list(
                         'lasso2d',
                         'select2d',
                         'toggleSpikelines',
                         'hoverClosestCartesian',
                         'hoverCompareCartesian',
                         'autoScale2d'
                         ))
      })
    })
  
  
  ### ----------------------------------
  ### --- TAB: Tables
  ### ----------------------------------
  
  ### --- SELECT: update select 'selectId'
  updateSelectizeInput(session,
                       'selectId',
                       choices = unique(
                         paste0(wd_IdentifiersFrame$label, 
                                " (", 
                                wd_IdentifiersFrame$property,
                                ")"
                           )),
                       selected = 'GND ID (P227)',
                       server = TRUE)
  
  ### --- output$overviewDT
  output$overlapDT <- DT::renderDataTable({
    # - dFrame_overviewDT reactive:
    dFrame_overviewDT <- reactive({
      sel <- str_extract(input$selectId, "P[[:digit:]]+")
      
      dFrame <- wd_CoOccurence[wd_CoOccurence$Identifier %in% sel, ]
      dFrame <- stack(dFrame)
      if (dim(dFrame)[1] == 0) {
        dFrame <- data.frame(Identifier = input$selectId, 
                             Comment = 'No overlap data for this identifier.')
        return(dFrame)
        } else {
        dFrame <- dFrame[, c('ind', 'values')]
        colnames(dFrame) <- c('Identifier', dFrame[1, 2])
        dFrame <- dFrame[-1, ]
        dFrame <- dFrame[order(-as.numeric(dFrame[, 2])), ]
        labs <- select(wd_IdentifiersFrame, 
                       property, label)
        labs <- labs[!duplicated(labs), ]
        labs$label <- paste0(labs$label, " (", labs$property, ")")
        dFrame <- left_join(dFrame, labs, 
                            by = c('Identifier' = 'property'))
        dFrame$Identifier <- dFrame$label
        dFrame$label <- NULL
        return(dFrame)
        }
    })
    # - DT:
    datatable(dFrame_overviewDT(), 
              filter = 'top',
              options = list(
                pageLength = 50,
                width = '100%',
                columnDefs = list(list(className = 'dt-center', targets = "_all"))
              ),
              rownames = FALSE
    )
  }) %>% withProgress(message = 'Generating data',
                      min = 0,
                      max = 1,
                      value = 1, {incProgress(amount = 1)})
  
  ### --- output$usageDT
  output$usageDT <- DT::renderDataTable({
    dFrame <- wd_Usage %>% 
      select(label, property, usage) %>% 
      arrange(desc(usage))
    dFrame <- dFrame[!duplicated(dFrame), ]
    dFrame$Property <- paste0(dFrame$label, " (", dFrame$property, ")")
    dFrame <- select(dFrame, Property, usage)
    colnames(dFrame) <- c('Property', 'Usage')
    # - DT:
    datatable(dFrame, 
              filter = 'top',
              options = list(
                pageLength = 50,
                width = '100%',
                columnDefs = list(list(className = 'dt-center', targets = "_all"))
              ),
              rownames = FALSE
    )
  }) %>% withProgress(message = 'Generating data',
                      min = 0,
                      max = 1,
                      value = 1, {incProgress(amount = 1)})
  
  
  ### ----------------------------------
  ### --- TAB: Identifier Classes
  ### ----------------------------------
  
  ### --- SELECT: update select 'selectClass'
  updateSelectizeInput(session,
                       'selectClass',
                       choices = 
                         unique(wd_IdentifiersFrame$classLabel),
                       selected = 'Wikidata property related to encyclopedias',
                       server = TRUE)
  
  ### --- output: localSimilarityGraph
  output$localSimilarityGraph <- renderPlotly({
    
    # - Visualize w. {igraph}

    selClass <- wd_IdentifiersFrame$class[which(wd_IdentifiersFrame$classLabel %in% input$selectClass)[1]]
    selClass <- c(input$selectClass,
                  wd_SubClasses$subClassLabel[wd_SubClasses$class %in% selClass])

    dSet <- wd_IdentifiersFrame[which(wd_IdentifiersFrame$classLabel %in% selClass), ]

    if (!is.null(dSet)) {
    
      dSet <- dSet %>%
        select(property, label)
      dSet <- paste0(dSet$label, " (", dSet$property, ")")
      idNet <- identifierConnected %>% 
        filter(Outgoing %in% dSet)
      
      idNet <- data.frame(from = idNet$Outgoing,
                          to = idNet$Incoming,
                          stringsAsFactors = F)
      idNet <- graph.data.frame(idNet,
                                vertices = NULL,
                                directed = T)
      
      # - network layout
      L <- layout_with_fr(idNet, grid = "nogrid")
      L <- as.data.frame(L)
      
      vs <- V(idNet)
      L$name <- vs$name
      es <- as.data.frame(get.edgelist(idNet))
      
      Nv <- length(vs)
      Ne <- dim(es)[1]
      
      Xn <- L[,1]
      Yn <- L[,2]
      
      a <- rowSums(select(wd_CoOccurence, -Identifier))
      f <- data.frame(summa = a, 
                      id = wd_CoOccurence$Identifier, 
                      stringsAsFactors = F) %>% 
        arrange(desc(summa))
      vsnames <- data.frame(id = vs$name, 
                            prop = str_extract(vs$name, "P[[:digit:]]+"),
                            stringsAsFactors = F)
      vsnames <- left_join(vsnames, f, by = c("prop" = "id"))
      vsnames$prop <- NULL
      
      graphColors <- rep('Other', 
                         times = length(vs$name))
      wClass <- which(vs$name %in% dSet)
      graphColors[wClass] <- 'In this WD class'
      
      network <- plot_ly(x = ~Xn, 
                         y = ~Yn, 
                         mode = "markers", 
                         color = graphColors, 
                         text = vs$name, 
                         size = vsnames$summa,
                         sizes = c(50, 300),
                         hoverinfo = "text")
      
      edge_shapes <- list()
      for (i in 1:Ne) {
        v0 <- es[i, ]$V1
        v1 <- es[i, ]$V2
        
        edge_shape = list(
          type = "line",
          line = list(color = "#030303", width = 0.3),
          x0 = Xn[which(L$name == v0)],
          y0 = Yn[which(L$name == v0)],
          x1 = Xn[which(L$name == v1)],
          y1 = Yn[which(L$name == v1)]
        )
        
        edge_shapes[[i]] <- edge_shape
      }
      
      axis <- list(title = "", 
                   showgrid = FALSE, 
                   showticklabels = FALSE, 
                   zeroline = FALSE)
      
      p <- layout(
        network,
        shapes = edge_shapes,
        xaxis = axis,
        yaxis = axis
      )
      
      ggplotly(p) %>% 
        plotly::config(displayModeBar = TRUE, 
                       displaylogo = FALSE, 
                       collaborate = FALSE, 
                       modeBarButtonsToRemove = list(
                         'lasso2d', 
                         'select2d', 
                         'toggleSpikelines', 
                         'hoverClosestCartesian', 
                         'hoverCompareCartesian', 
                         'autoScale2d'
                       ))
    } else {
      NULL
    }
  }) %>% withProgress(message = 'Generating plot',
                      min = 0,
                      max = 1,
                      value = 1, {incProgress(amount = 1)})
  
  # - output: identifierClassList
  output$identifierClassList <- DT::renderDataTable({
    dFrame <- wd_IdentifiersFrame %>% 
      filter(classLabel %in% input$selectClass)
    
    colnames(dFrame)[1] <- 'rn'
    dFrame <- dFrame %>% 
      select(property, label, used)
    dFrame$url <- paste0('<a href = "https://www.wikidata.org/wiki/Property:', 
                         dFrame$property, 
                         '" target="_blank">')
    dFrame$Identifier <- paste0(dFrame$label, " (", dFrame$property, ")")
    dFrame$Identifier <- paste0(dFrame$url, dFrame$Identifier, '</a>')
    dFrame <- select(dFrame, Identifier)
    
    # - DT:
    datatable(dFrame, 
              escape = F,
              filter = 'top',
              options = list(
                pageLength = 10,
                width = '100%',
                columnDefs = list(list(className = 'dt-center', targets = "_all"))
              ),
              rownames = FALSE
    )
  }) %>% withProgress(message = 'Generating data',
                      min = 0,
                      max = 1,
                      value = 1, {incProgress(amount = 1)})
  
  ### ----------------------------------
  ### --- TAB: Particular Identifier
  ### ----------------------------------
  
  ### --- SELECT: update select 'selectIdentifier'
  updateSelectizeInput(session,
                       'selectIdentifier',
                       choices = 
                         unique(wd_IdentifiersFrame$label),
                       selected = 'GND ID',
                       server = TRUE)
  
  ### --- output:identifierSimilarityGraph
  output$identifierSimilarityGraph <- renderPlotly({
    
    # - Visualize w. {igraph}
    dSet <- wd_IdentifiersFrame[which(wd_IdentifiersFrame$label %in% input$selectIdentifier), ]
  
    if (!is.null(dSet)) {
      
      dSet <- dSet %>%
        select(property, label)
      dSet <- paste0(dSet$label, " (", dSet$property, ")")[1]
      idNet1 <- identifierConnected10 %>% 
        filter(Outgoing %in% dSet)
      friends <- idNet1$Incoming
      idNet2 <- identifierConnected10 %>% 
        filter(Outgoing %in% friends)
      idNet <- rbind(idNet1, idNet2)
      
      idNet <- data.frame(from = idNet$Outgoing,
                          to = idNet$Incoming,
                          stringsAsFactors = F)
      idNet <- graph.data.frame(idNet,
                                vertices = NULL,
                                directed = T)
      
      # - network layout
      L <- layout_with_fr(idNet, grid = "nogrid")
      L <- as.data.frame(L)
      
      vs <- V(idNet)
      L$name <- vs$name
      es <- as.data.frame(get.edgelist(idNet))
      
      Nv <- length(vs)
      Ne <- dim(es)[1]
      
      Xn <- L[,1]
      Yn <- L[,2]
      
      a <- rowSums(select(wd_CoOccurence, -Identifier))
      f <- data.frame(summa = a, 
                      id = wd_CoOccurence$Identifier, 
                      stringsAsFactors = F) %>% 
        arrange(desc(summa))
      vsnames <- data.frame(id = vs$name, 
                            prop = str_extract(vs$name, "P[[:digit:]]+"),
                            stringsAsFactors = F)
      vsnames <- left_join(vsnames, f, by = c("prop" = "id"))
      vsnames$prop <- NULL
      graphColors <- rep('Other', 
                         times = length(vs$name))
      wClass <- which(vs$name %in% dSet)
      graphColors[wClass] <- 'Selected Identifier'
      
      network <- plot_ly(x = ~Xn, 
                         y = ~Yn, 
                         mode = "markers", 
                         color = graphColors, 
                         text = vs$name, 
                         size = vsnames$summa,
                         sizes = c(50, 300),
                         hoverinfo = "text")
      
      edge_shapes <- list()
      for (i in 1:Ne) {
        v0 <- es[i, ]$V1
        v1 <- es[i, ]$V2
        
        edge_shape = list(
          type = "line",
          line = list(color = "#030303", width = 0.3),
          x0 = Xn[which(L$name == v0)],
          y0 = Yn[which(L$name == v0)],
          x1 = Xn[which(L$name == v1)],
          y1 = Yn[which(L$name == v1)]
        )
        
        edge_shapes[[i]] <- edge_shape
      }
      
      axis <- list(title = "", 
                   showgrid = FALSE, 
                   showticklabels = FALSE, 
                   zeroline = FALSE)
      
      p <- layout(
        network,
        shapes = edge_shapes,
        xaxis = axis,
        yaxis = axis
      )
      
      ggplotly(p) %>% 
        plotly::config(displayModeBar = TRUE, 
                       displaylogo = FALSE, 
                       collaborate = FALSE, 
                       modeBarButtonsToRemove = list(
                         'lasso2d', 
                         'select2d', 
                         'toggleSpikelines', 
                         'hoverClosestCartesian', 
                         'hoverCompareCartesian', 
                         'autoScale2d'
                       ))
    } else {
      NULL
    }
  }) %>% withProgress(message = 'Generating plot',
                      min = 0,
                      max = 1,
                      value = 1, {incProgress(amount = 1)})
  
  ### --- output$identifierReport
  output$identifierReport <- renderText({
    
    dSet <- wd_IdentifiersFrame[which(wd_IdentifiersFrame$label %in% input$selectIdentifier), ]
    
    # - test
    dSet <- wd_IdentifiersFrame[which(wd_IdentifiersFrame$label %in% 'National Heritage List for England number'), ]
    
    prop <- dSet$property[1]
    APIquery <- paste0('https://www.wikidata.org/w/api.php?action=wbgetentities&ids=', 
                       prop, 
                       '&props=labels%7Cdescriptions%7Cclaims%7Csitelinks/urls&languages=az&languagefallback=&sitefilter=azwiki&formatversion=2&format=json')
    res <- GET(url = URLencode(APIquery))
    # - External Identifers to a data.frame
    if (res$status_code == 200) {
      # - fromJSON
      pStatements <- fromJSON(rawToChar(res$content), simplifyDataFrame = T)
    }
    
    # - number of statements
    pStatements <- length(pStatements$entities[[1]]$claims)
    
    # - classes:
    idClasses <- unique(paste0(dSet$classLabel, " (", dSet$class, ")"))
    idC <- str_extract(idClasses, "Q[[:digit:]]+")
    idClasses <- paste0('<a href = "https://www.wikidata.org/wiki/', idC, 
                       '" target="_blank">', idClasses, "</a>")
    idClasses <- paste(idClasses, collapse = ", ")
    
    # - uses
    dSet <- dSet %>%
      select(property, label)
    if (dim(dSet)[1] == 0) {
      idUses = 'This WD external identifier is not used.' 
    } else {
      nUse <- wd_Usage[which(wd_Usage$property %in% unique(dSet$property)), ]
      nUse <- nUse$usage[1]
      idUses <- paste0('This WD external identifier is used to describe ', nUse, ' WD item(s).') 
    }
    # - overlapInfo
    dSet <- paste0(dSet$label, " (", dSet$property, ")")[1]
    idNet1 <- identifierConnected10 %>%
      filter(Outgoing %in% dSet)
    if (dim(idNet1)[1] == 0) {
      overlapInfo <- "<font color=\"blue\">There is not enough data to compute the overlap graph for this identifier.</font>"
    } else {
      overlapInfo <- ''
    }
    # - statements info
    if (length(pStatements) > 0) {
      statementsInfo <- paste0("Wikidata has <b>", pStatements, "</b> statements on this identifier.")
    } else {
      statementsInfo <- "Wikidata has no statements on this identifier."
    }
    # - usageInfo
    usageInfo <- wd_Usage$usage[wd_Usage$label %in% input$selectIdentifier][1]
    if (!is.na(usageInfo)) {
      usageInfo <- paste0('This identifier is used by <b>', usageInfo, '</b> WD items.')
    } else {
      usageInfo <- ''
      }
    
    # - output string
    paste0('<p style="font-size:80%;"align="left"><b>Identifier info.</b> ', 
           "This identifier belongs to the following WD identifier classes: ", 
           paste(idClasses, collapse = ", ", sep = " "), 
           " . " , overlapInfo, '<br>', statementsInfo, ' ', usageInfo,
           '</p>')
    
  })
  
  #### --- output$examplesDT
  output$examplesDT <- DT::renderDataTable({
    
    withProgress(message = 'Contacting WDQS.', detail = "Please be patient.", value = 0, {
      
      incProgress(1/3, detail = "Please be patient.")
      # - WDQS endpoint
      endPointURL <- params$wdqsEndpoint
      # - Which identifier are we looking for?
      prop <- wd_IdentifiersFrame[which(wd_IdentifiersFrame$label %in% input$selectIdentifier), ]
      prop <- prop$property[1]
      query <- paste0('SELECT ?item ?itemLabel ?class ?classLabel ?value { 
        ?item wdt:', prop, ' ?value .
        ?item wdt:P31 ?class .
        SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
      } LIMIT 100')
      res <- GET(url = paste0(endPointURL, URLencode(query)))
      # - External Identifers to a data.frame
      if (res$status_code == 200) {
        # - fromJSON
        example <- fromJSON(rawToChar(res$content), simplifyDataFrame = T)
      }
      incProgress(2/3, detail = "Wrangling.")
      example <- data.frame(item = example$results$bindings$item$value,
                            itemLabel = example$results$bindings$itemLabel$value,
                            class = example$results$bindings$class$value,
                            classLabel = example$results$bindings$classLabel$value,
                            value = example$results$bindings$value$value,
                            stringsAsFactors = F)
      exClass <- lapply(unique(example$item), function(x) {
        d <- example[which(example$item %in% x), ]
        dClass <- d$class
        dClassLabel <- d$classLabel
        dClass <- paste0('<a href = "', dClass, '" target = "_blank">', 
                         dClassLabel, 
                         '</a>')
        dClass <- data.frame(classes = paste(dClass, collapse = ", "), 
                             stringsAsFactors = F)
        dClass$item <- x
        dClass
      })
      exClass <- rbindlist(exClass)
      example <- example %>% 
        select(item, itemLabel, value)
      example <- example[!duplicated(example), ]
      example <- left_join(example, exClass, by = "item")
      example$itemId <- str_extract(example$item, "Q[[:digit:]]+")
      example$item <- paste0('<a href = "', example$item, '" target = "_blank">', 
                             paste0(example$itemLabel, " (", example$itemId, ")"), 
                             '</a>')
      dFrame <- example %>% select(
        item, value, classes)
        colnames(dFrame) <- str_to_title(colnames(dFrame))
        incProgress(3/3, detail = "Done.")
    })
        
    
    # - DT:
    datatable(dFrame, 
              escape = F,
              filter = 'top',
              options = list(
                pageLength = 10,
                width = '100%',
                columnDefs = list(list(className = 'dt-center', targets = "_all"))
              ),
              rownames = FALSE
    )
  }) %>% withProgress(message = 'Generating data',
                      min = 0,
                      max = 1,
                      value = 1, {incProgress(amount = 1)})
  
  
  }) ### --- END shinyServer

