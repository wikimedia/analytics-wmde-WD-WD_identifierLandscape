### ---------------------------------------------------------------------------
### --- WD External Identifiers Dashboard, v. 1.0.0
### --- Script: ui.R
### ---------------------------------------------------------------------------

### ---------------------------------------------------------------------------
### --- WD_IdentifierLandscape_Data.R
### --- Author(s): Goran S. Milovanovic, Data Scientist, WMDE
### --- Developed under the contract between Goran Milovanovic PR Data Kolektiv
### --- and WMDE.
### --- Contact: goran.milovanovic_ext@wikimedia.de
### --- June 2020.
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

### --- general
library(shiny)
library(shinydashboard)
library(shinycssloaders)
### --- outputs
library(DT)
library(plotly)

# - options
options(warn = -1)

### --- User Interface w. {shinydashboard}

shinyUI(
  
  ### --- dashboardPage
  ### --------------------------------
  
  dashboardPage(skin = "black",
                
                ### --- dashboarHeader
                ### --------------------------------
                
                dashboardHeader(
                  # - Title
                  title = "WD Identifier Landscape",
                  titleWidth = 300
                ), 
                ### ---- END dashboardHeader
                
                ### --- dashboardSidebar
                ### --------------------------------
                
                dashboardSidebar(
                  sidebarMenu(
                    id = "tabsWDIdentifiers",
                    menuItem('Similarity Map',
                             tabName = 'similarityMap',
                             icon = icon('line-chart'),
                             selected = T
                             ),
                    menuItem('Overlap Network',
                             tabName = 'similarityGraph',
                             icon = icon('line-chart')
                    ),
                    menuItem('Tables',
                             tabName = 'tables',
                             icon = icon('barcode')
                             ),
                    menuItem(text = "Identifier Classes",
                             tabName = "identifierClusters",
                             icon = icon("line-chart")
                             ),
                    menuItem(text = "Particular Identifier", 
                             tabName = "particularIdentifier", 
                             icon = icon("line-chart")
                             
                    ),
                    menuItem(text = "Documentation",
                             tabName = "Documentation",
                             icon = icon("barcode")
                    )
                  )
                ),
                ### --- END dashboardSidebar
                
                ### --- dashboardBody
                ### --------------------------------
                
                dashboardBody(
                  
                  # - style
                  tags$head(tags$style(HTML('.content-wrapper, .right-side {
                                            background-color: #ffffff;
                                            }'))),
                  tags$style(type="text/css",
                             ".shiny-output-error { visibility: hidden; }",
                             ".shiny-output-error:before { visibility: hidden; }"
                  ),
                  
                  tabItems(
                    
                    ### --- TAB: Overview
                    ### --------------------------------
                    
                    tabItem(tabName = "overview"
                    ),
                    tabItem(tabName = "similarityMap",
                            fluidRow(
                              column(width = 8,
                                     HTML('<p style="font-size:80%;"align="left"><b>The Wikidata Identifiers Landscape</b> 
                                          keeps track of the WD external identifier <i>usage</i> and the <i>overlap of their usage</i> across the 
                                          WD items.<br> To get an insight into the dataset  browse the <b><i>Similarity Map</i></b> tab, which presents 
                                          a global overview of the overlap in the usage of WD identifiers, and the <b><i>Tables</i></b> section where the 
                                          respective data can be found. The <b><i>Overlap Network</i></b> tab visualizes all Wikidata external identifiers in 
                                          a network of nearest neighbors. On the <b><i>Identifier Classes</i></b> tab we present insights into the relationships 
                                          between the WD external identifiers belonging to the same class of WD identifiers. The <b><i>Particular Identifier</i></b> 
                                          tab provides insights into the data for any WD external identifier of choice.</i> tab. 
                                          <font color="blue"><b>Please be patient:</b> the dashboard needs to download the datasets and render the graphs upon initialiazitation.</font></p>'),
                                     htmlOutput('overview')
                                     ),
                              column(width = 4,
                                     HTML('<p style="font-size:80%;"align="right">
                                           <a href = "https://meta.wikimedia.org/wiki/Wikidata_Identifier_Landscape" target="_blank">Documentation</a><br>
                                            <a href = "https://analytics.wikimedia.org/published/datasets/wmde-analytics-engineering/Wikidata/WD_ExternalIdentifiers/" target = "_blank">Public datasets</a><br>
                                            <a href = "https://github.com/wikimedia/analytics-wmde-WD-WD_identifierLandscape" target = "_blank">GitHub</a><br>
                                          <a href = "https://wikitech.wikimedia.org/wiki/Wikidata_Identifier_Landscape" target = "_blank">Wikitech</a></p>'),
                                     htmlOutput('updateString')
                                     )
                              ),
                            fluidRow(
                              hr()
                            ),
                            fluidRow(
                              column(width = 4,
                                     selectizeInput("globalMap_selectCluster",
                                                    "Highlight Identifier Class:",
                                                    multiple = F,
                                                    choices = NULL,
                                                    selected = 'Wikidata property for authority control')
                              ),
                              column(width = 8,
                                     HTML('<p style="font-size:80%;"><b>WD External Identifiers Similarity Map.</b> <i>NOTE</i>: The selected class (<i>drop-down menu to the left</i>) of 
                                          identifiers will be highlighted. Each bubble represents an external identifier. 
                                          The size of the bubble (NOTE: <i>a logarithmic scale is used</i>) reflects how many WD items are described by the 
                                          respective identifier. Identifiers that have a large overlap across the WD items that they describe 
                                          are grouped together. Use the tools next to the plot legend to explore the plot and hover over bubbles for details: 
                                          the identifier label and the number of WD items that make use of it.
                                          The similarity map is produced by a two-dimensional <a href = "https://en.wikipedia.org/wiki/T-distributed_stochastic_neighbor_embedding" 
                                          target = "_blank">t-distributed stochastic neighbor embedding (t-SNE)</a> of the <a href = "https://en.wikipedia.org/wiki/Jaccard_index" 
                                          target = "_blank">Jaccard distance</a> <i>identifier x identifier</i> matrix.</p>')
                                     )
                              ),
                            fluidRow(
                              column(width = 12,
                                     withSpinner(plotlyOutput("globalMap",
                                                              width = "100%",
                                                              height = "900px"))
                                     )
                              ),
                            fluidRow(
                              column(width = 1,
                                     br(),
                                     img(src = 'Wikidata-logo-en.png',
                                         align = "left")
                              ),
                              column(width = 11,
                                     hr(),
                                     HTML('<p style="font-size:80%;"><b>Wikidata Identifier Landscape :: WMDE 2020.</b><br></p>'),
                                     HTML('<p style="font-size:80%;"><b>Contact:</b> Goran S. Milovanovic, Data Scientist, WMDE<br>
                                          <b>e-mail:</b> goran.milovanovic_ext@wikimedia.de<br><b>IRC:</b> goransm</p>'),
                                     br(), br()
                                     )
                              )
                            ), ### --- END Tab similarityMap
                    tabItem(tabName = "tables",
                            fluidRow(
                               column(width = 6,
                                      HTML('<p style="font-size:80%;"><b>WD External Identifiers Overlap and Usage Data. </b>In the table to 
                                            the left (<i>Overlap Data</i>), select a WD External Identifier and the dashboard shows how many items does it share 
                                            with all other identifiers. In the table to the right (<i>Usage Data</i>) all WD External Identifiers are listed 
                                            alongside the number of items which they describe.<br> <b>N.B.</b> Having data on a particular identifier\'s usage i.e. the number of 
                                           WD items that use a particular identifier <i>does not necessarily imply</i> that the identifier has any overlap 
                                           with other identifiers.</p>'),
                                      hr()
                                      ), 
                               column(width = 6,
                                      HTML('<p style="font-size:80%;"align="right">
                                            <a href = "https://meta.wikimedia.org/wiki/Wikidata_Identifier_Landscape" target="_blank">Documentation</a><br>
                                            <a href = "https://analytics.wikimedia.org/published/datasets/wmde-analytics-engineering/Wikidata/WD_ExternalIdentifiers/" target = "_blank">Public datasets</a><br>
                                            <a href = "https://github.com/wikimedia/analytics-wmde-WD-WD_identifierLandscape" target = "_blank">GitHub</a><br>
                                           <a href = "https://wikitech.wikimedia.org/wiki/Wikidata_Identifier_Landscape" target = "_blank">Wikitech</a></p>')
                                      )
                            ),
                            fluidRow(
                              column(width = 12, 
                                     fluidRow(
                                       column(width = 6,
                                              h4('Overlap Data'),
                                              selectizeInput("selectId",
                                                             "Select Identifier:",
                                                             multiple = F,
                                                             choices = NULL)
                                              ),
                                       column(width = 6, 
                                              h4('Usage Data')
                                              )
                                     )
                                     )
                            ),
                            fluidRow(
                              column(width = 6, 
                                     withSpinner(DT::dataTableOutput('overlapDT', width = "100%"))
                                     ),
                              column(width = 6,
                                     withSpinner(DT::dataTableOutput('usageDT', width = "100%"))
                                     )
                            ),
                            fluidRow(
                              hr(),
                              column(width = 1,
                                     br(),
                                     img(src = 'Wikidata-logo-en.png',
                                         align = "left")
                              ),
                              column(width = 11,
                                     hr(),
                                     HTML('<p style="font-size:80%;"><b>Wikidata Identifier Landscape :: WMDE 2020.</b><br></p>'),
                                     HTML('<p style="font-size:80%;"><b>Contact:</b> Goran S. Milovanovic, Data Scientist, WMDE<br>
                                          <b>e-mail:</b> goran.milovanovic_ext@wikimedia.de<br><b>IRC:</b> goransm</p>'),
                                     br(), br()
                              )            
                            )
                    ), ### --- END Tab tables
                    tabItem(tabName = "similarityGraph",
                            fluidRow(
                              column(width = 6,
                                     HTML('<p style="font-size:80%;"><b>WD External Identifiers Overlap Network. </b>Each bubble in the network represents an 
                                          WD external identifier. Nearest neighbors in terms of the number of shared items (i.e. <i>overlap</i>) are connected: 
                                          each identifier points a link towards its own nearest neighbour. The size of the bubble corresponds to the total number 
                                          of items across which the respective identifier overlaps with other identifiers. Hover over the bubble to obtain the 
                                          details (<i>identifier ID</i> and the measure of total overal) on the respective identifier and use the toolbox 
                                          (in the top-right corner of the network) to zoom, pan, or download.<br>
                                          The <i>Fruchterman-Reingold</i> algorithm  in 
                                          <a href = "https://igraph.org/r/doc/layout_with_fr.html" target = "_blank">{igraph}</a> is used 
                                          to visualize the identifier network. <font color="blue"><b>Please be patient</b>: we are rendering a <b><i>huge</i></b> network of Wikidata identifieres.</font></p>'),
                                     hr()
                                     ), 
                              column(width = 6,
                                     HTML('<p style="font-size:80%;"align="right">
                                          <a href = "https://meta.wikimedia.org/wiki/Wikidata_Identifier_Landscape" target="_blank">Documentation</a><br>
                                          <a href = "https://analytics.wikimedia.org/published/datasets/wmde-analytics-engineering/Wikidata/WD_ExternalIdentifiers/" target = "_blank">Public datasets</a><br>
                                          <a href = "https://github.com/wikimedia/analytics-wmde-WD-WD_identifierLandscape" target = "_blank">GitHub</a><br>
                                          <a href = "https://wikitech.wikimedia.org/wiki/Wikidata_Identifier_Landscape" target = "_blank">Wikitech</a></p>')
                                     )
                              ),
                            fluidRow(
                              column(width = 12,
                                     withSpinner(plotlyOutput("similarityGraph",
                                                              width = "100%",
                                                              height = "900px"))
                                     )
                            ),
                            fluidRow(
                              hr(),
                              column(width = 1,
                                     br(),
                                     img(src = 'Wikidata-logo-en.png',
                                         align = "left")
                              ),
                              column(width = 11,
                                     hr(),
                                     HTML('<p style="font-size:80%;"><b>Wikidata Identifier Landscape :: WMDE 2020.</b><br></p>'),
                                     HTML('<p style="font-size:80%;"><b>Contact:</b> Goran S. Milovanovic, Data Scientist, WMDE<br>
                                          <b>e-mail:</b> goran.milovanovic_ext@wikimedia.de<br><b>IRC:</b> goransm</p>'),
                                     br(), br()
                                     )
                              )
                            ), ### --- END Tab similarityGraph
                    tabItem(tabName = "identifierClusters",
                            fluidRow(
                              column(width = 8,
                                     HTML('<p style="font-size:80%;"align="left"><b>External Identifiers Wikidata Classes. </b>WD external identifiers 
                                          belong (in terms of <i>P31 (Instance of)</i>) to one or more <b>WD identifier classes</b>. Here you can 
                                          generate a network of identifiers from any WD identifier class and inspect its neighborhood structure. 
                                          Neighbors are those identifiers that share a large number of items that they describe.
                                          Each bubble represents an identifier, and each identifier is connected to its nearest neighbors 
                                          (<i>note:</i> their neighbors do not necessarily belong to the same class). Hover over the bubbles to 
                                          reveal the respective identifiers. The <i>Fruchterman-Reingold</i> algorithm  in 
                                          <a href = "https://igraph.org/r/doc/layout_with_fr.html" target = "_blank">{igraph}</a> is used 
                                          to visualize the identifier network. For identifier classes that encompass a large number of identifiers 
                                          you will most probably need to zoom into the dense region of the graph in order to discover its structure.
                                          The table to the right lists all WD external identifiers that belong (in a sense of: <b>P31 Instance of</b>) 
                                          to the selected class.</p>')
                                     ),
                              column(width = 4,
                                     HTML('<p style="font-size:80%;"align="right">
                                          <a href = "https://meta.wikimedia.org/wiki/Wikidata_Identifier_Landscape" target="_blank">Documentation</a><br>
                                          <a href = "https://analytics.wikimedia.org/published/datasets/wmde-analytics-engineering/Wikidata/WD_ExternalIdentifiers/" target = "_blank">Public datasets</a><br>
                                          <a href = "https://github.com/wikimedia/analytics-wmde-WD-WD_identifierLandscape" target = "_blank">GitHub</a><br>
                                          <a href = "https://wikitech.wikimedia.org/wiki/Wikidata_Identifier_Landscape" target = "_blank">Wikitech</a></p>')
                                     )
                              ),
                            fluidRow(
                              hr()
                            ),
                            fluidRow(
                              column(width = 4,
                                     selectizeInput("selectClass",
                                                    "Select Identifier Class:",
                                                    multiple = F,
                                                    choices = NULL)
                              ),
                              column(width = 8
                                     )
                              ),
                            fluidRow(
                              column(width = 8,
                                     withSpinner(plotlyOutput("localSimilarityGraph",
                                                              width = "100%",
                                                              height = "500px")
                                                 )
                              ),
                              column(width = 4, 
                                     withSpinner(DT::dataTableOutput('identifierClassList', width = "100%")
                                                 )
                              )
                            ),
                            fluidRow(
                              column(width = 1,
                                     br(),
                                     img(src = 'Wikidata-logo-en.png',
                                         align = "left")
                              ),
                              column(width = 11,
                                     hr(),
                                     HTML('<p style="font-size:80%;"><b>Wikidata Identifier Landscape :: WMDE 2020.</b><br></p>'),
                                     HTML('<p style="font-size:80%;"><b>Contact:</b> Goran S. Milovanovic, Data Scientist, WMDE<br>
                                          <b>e-mail:</b> goran.milovanovic_ext@wikimedia.de<br><b>IRC:</b> goransm</p>'),
                                     br(), br()
                              )
                            )
                    ), ### --- END Tab identifierClusters
                    tabItem(tabName = "particularIdentifier",
                            fluidRow(
                              column(width = 6,
                                     HTML('<p style="font-size:80%;"align="left"><b>Wikidata External Identifiers.</b> 
                                          Select a particular WD external identifier from a drop-down menu and the 
                                          dashboard will generate a concise info on the type of resources that it 
                                          describes and an (approximate) set of  exemplar WD items or classes. If there is 
                                          enough overlap between the selected identifier and other WD identifiers, a 
                                          network of its neighbors (and their neighbors, to provide some context) will 
                                          be generated. The <i>Fruchterman-Reingold</i> algorithm  in 
                                          <a href = "https://igraph.org/r/doc/layout_with_fr.html" target = "_blank">{igraph}</a> is 
                                          used to visualize the identifier network. The table on the right lists several examples of WD items that 
                                          are described by the selected identifier, alongside the value assigned to them 
                                          and a list of classes (in a sense of <i>P31 Instance of </i>) they belong to. <b>N.B.</b> 
                                          It is possible that the current dashboard update does not have enough data to visualize 
                                          the neighbourhood structure for particular identifiers - especially for the ones less frequently used.</p>')
                                     ),
                              column(width = 6,
                                     HTML('<p style="font-size:80%;"align="right">
                                          <a href = "https://meta.wikimedia.org/wiki/Wikidata_Identifier_Landscape" target="_blank">Documentation</a><br>
                                          <a href = "https://analytics.wikimedia.org/published/datasets/wmde-analytics-engineering/Wikidata/WD_ExternalIdentifiers/" target = "_blank">Public datasets</a><br>
                                          <a href = "https://github.com/wikimedia/analytics-wmde-WD-WD_identifierLandscape" target = "_blank">GitHub</a><br>
                                          <a href = "https://wikitech.wikimedia.org/wiki/Wikidata_Identifier_Landscape" target = "_blank">Wikitech</a></p>')
                                     )
                                     ),
                            fluidRow(
                              hr()
                            ),
                            fluidRow(
                              column(width = 4,
                                     selectizeInput("selectIdentifier",
                                                    "Select Identifier:",
                                                    multiple = F,
                                                    choices = NULL)
                              )
                            ),
                            fluidRow(
                              column(width = 12, 
                                     hr()
                                     ),
                              column(width = 6,
                                     fluidRow(
                                       column(width = 12, 
                                              htmlOutput('identifierReport'))
                                       ),
                                     fluidRow(
                                       column(width = 12,
                                              withSpinner(plotlyOutput("identifierSimilarityGraph",
                                                                       width = "100%",
                                                                       height = "500px")
                                                          )
                                              )
                                       )
                                     ),
                              column(width = 6,
                                     h4('Typical usage of this identifier (Examples)'),
                                     HTML('<p style="font-size:80%;"align="left">The result is based on the first 100 triples fetched 
                                          from WDQS (i.e. LIMIT 100).</p>'),
                                     withSpinner(DT::dataTableOutput("examplesDT",
                                                              width = "100%")
                                     )   
                              )
                            ),
                            fluidRow(
                              column(width = 1,
                                     br(),
                                     img(src = 'Wikidata-logo-en.png',
                                         align = "left")
                              ),
                              column(width = 11,
                                     hr(),
                                     HTML('<p style="font-size:80%;"><b>Wikidata Identifier Landscape :: WMDE 2020.</b><br></p>'),
                                     HTML('<p style="font-size:80%;"><b>Contact:</b> Goran S. Milovanovic, Data Scientist, WMDE<br>
                                          <b>e-mail:</b> goran.milovanovic_ext@wikimedia.de<br><b>IRC:</b> goransm</p>'),
                                     br(), br()
                              )
                            )
                    ), ### --- END Tab particularIdentifier,
                    tabItem(tabName = "Documentation",
                            fluidRow(
                              column(width = 8,
                                     HTML('<h2>Wikidata Identifier Landscape</h2>
                                          <hr>
                                          <h4>Introduction<h4>
                                          <br>
                                          <p style="font-size:80%;">This dashboard is developed by <a href = "https://wikimedia.de/" target = "_blank">WMDE</a> in response to the <a href = "https://phabricator.wikimedia.org/T204440" target = "_blank">
                                          analyze and visualize the identifier landscape of Wikidata</a> Phabricator task.</p>
                                          <p style="font-size:80%;">The WD Identifier Landscape dashboard relies on the dataset obtained by performing ETL from <a href = "https://en.wikipedia.org/wiki/Apache_Spark" 
                                          target = "_blank">Apache Spark</a> w. <a href = "https://spark.apache.org/docs/2.2.1/api/python/pyspark.html" target = "_blank">Pyspark</a> against the 
                                          <a href = "https://phabricator.wikimedia.org/T209655" target = "_blank">copy of the Wikidata dump in 
                                          HDFS</a> (WMF Data Lake) and post-processed in <a href = "https://en.wikipedia.org/wiki/R_(programming_language)" target = "_blank">R</a>. All machine 
                                          learning procedures are performed in <a href = "https://en.wikipedia.org/wiki/R_(programming_language)" target = "_blank">R</a> (the t-SNE dimensionality 
                                          reduction is handled by <a href = "https://cran.r-project.org/web/packages/Rtsne/index.html" target = "_blank">{Rtsne}</a>).</p>
                                          <p style="font-size:80%;">The goal of this dashboard is to provide insight into the structure of the overlap in usage of various 
                                          <a href = "https://www.wikidata.org/wiki/Wikidata:Identifiers" target = "_blank">WD external identifiers</a>. Several means of 
                                          data visualization are employed in that cause, relying on <a href = "https://plot.ly/r/" target = "_blank">{plotly}</a> 
                                          to visualize semantic maps and networks.</p>
                                          <p style="font-size:80%;"><b>N.B.</b> All presented results that rely on overlap in identifier usage across the WD items are relative to the 
                                          latest version of the WD Dump processed and copied to the 
                                          <a href = "https://wikitech.wikimedia.org/wiki/Analytics/Data_Lake" target = "_blank">WMD Data Lake</a> 
                                          (see: <a href = "https://phabricator.wikimedia.org/T209655" target = "_blank">Phabricator</a>). The identifier usage statistics (i.e. 
                                          the number of WD items that use a particular identifier) are fetched from <a href = "https://query.wikidata.org/" target = "_blank">WDQS</a>.</p>
                                          <hr>
                                          <h4>Dashboard Functionality</h4>
                                          <br>
                                          <p style="font-size:90%;"><b>Visualizations.</b> Visualizing the overlap structure of the WD external identifiers is a challenging task. In order to provide 
                                          an as thorough as possible insight into the similarity in usage of various identifiers across the WD items, we employ several different approaches to data visualization. 
                                          The landing, <b>Similarity Map</b> tab, presents a two-dimensional map in which each WD external identifier (that is used at all) is represented by a bubble. 
                                          In this map, distance between the identifiers represents the similarity in their usage: the higher the overlap across the WD items which are described by 
                                          a particular pair of identifiers - the closer the respective bubbles stand in the map. 
                                          The size of each bubble corresponds to the number of items that the respective identifier describes. Since any WD external identifier can fall in more than one 
                                          WD class of identifiers, we have avoided setting the color scheme to mark identifiers belonging to the same WD class in the map. Our approach was to let user select a particular class 
                                          of identifiers of interest and then color the respective bubbles in the map to ease recognition.</p>
                                          <p style="font-size:90%;">A more straightforward (and probably more popular) approach to visualize datasets as the one at hand is to employ graphs. 
                                          On the <b>Overlap Network</b> each identifier is again represented by a bubble and points towards its nearest neighbor: the identifier with which it shares 
                                          the highest number of items that they both describe. The size of the bubble in this visualization does not represent the number of items described by a 
                                          particular identifier, but the extent of its total overlap with other identifiers, making the hubs in the network easier to spot.</p>
                                          <p style="font-size:90%;">The <b>Tables tab</b> enables the user to browse for specific identifiers and inspect the exact extent of their overlap with all 
                                          other WD external identifiers. Another table is produced under the same tab: one providing for the counts of items described by all considered identifiers.</p>
                                          <p style="font-size:90%;">As already explained, WD external identifiers belong to one or more WD identifier classes. The <b>Identifier Classes</b>
                                          tab provides a browser of these classes, generates a local neighborhood similarity structure (based on an overlap in identifier usage) for all the 
                                          identifiers found in the selected class, and lists all of the class identifiers. Similarly, the <b>Particular Identifier</b> tab provides information about 
                                          a particular WD external identifier: its local neighborhood structure, and a set of exemplar uses of that identifier (represented by a selection of items that
                                          it describes, the WD classes (in a sense of <a href = "" target="_blank">instance of (P31)</a>) to which these items belong, and the values of the selected identifier associated to them).</p>'
                                          )
                            ),
                            column(width = 1),
                            column(width = 3,
                                   HTML('<p style="font-size:80%;"align="right">
                                        <a href = "https://meta.wikimedia.org/wiki/Wikidata_Identifier_Landscape" target="_blank">Documentation</a><br>
                                        <a href = "https://analytics.wikimedia.org/published/datasets/wmde-analytics-engineering/Wikidata/WD_ExternalIdentifiers/" target = "_blank">Public datasets</a><br>
                                        <a href = "https://github.com/wikimedia/analytics-wmde-WD-WD_identifierLandscape" target = "_blank">GitHub</a><br>
                                        <a href = "https://wikitech.wikimedia.org/wiki/Wikidata_Identifier_Landscape" target = "_blank">Wikitech</a></p>')
                                   )
                                   ),
                            fluidRow(
                              hr(),
                              column(width = 1,
                                     br(),
                                     img(src = 'Wikidata-logo-en.png',
                                         align = "left")
                              ),
                              column(width = 11,
                                     hr(),
                                     HTML('<p style="font-size:80%;"><b>Wikidata Identifier Landscape :: WMDE 2020.</b><br></p>'),
                                     HTML('<p style="font-size:80%;"><b>Contact:</b> Goran S. Milovanovic, Data Scientist, WMDE<br>
                                          <b>e-mail:</b> goran.milovanovic_ext@wikimedia.de<br><b>IRC:</b> goransm</p>'),
                                     br(), br()
                                     )
                              )
                            ) ### --- END documentation
                
                ) ### --- end tabItems
                
                ) ### --- END dashboardBody
                
                ) ### --- END dashboardPage
  
  ) # END shinyUI

