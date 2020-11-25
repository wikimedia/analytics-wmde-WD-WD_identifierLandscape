
### ---------------------------------------------------------------------------
### --- WD_IdentifierLandscape_Data.py
### --- Authors: Goran S. Milovanovic, Data Scientist, WMDE
### --- Developed under the contract between Goran Milovanovic PR Data Kolektiv
### --- and WMDE.
### --- Contact: goran.milovanovic_ext@wikimedia.de
### --- June 2020.
### ---------------------------------------------------------------------------
### --- COMMENT:
### --- Pyspark ETL procedures for the WD JSON dumps in hdfs
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
### --- along with WEIP. If not, see <http://www.gnu.org/licenses/>.
### ---------------------------------------------------------------------------
### ---------------------------------------------------------------------------
### --- Script: WD_IdentifierLandscape_Data.py
### ---------------------------------------------------------------------------
### --- DESCRIPTION:
### --- WD_IdentifierLandscape_Data.py performs ETL procedures
### --- over the Wikidata JSON dumps in hdfs, production
### --- to produce the dataset to visualize the identifier landscape of
### --- Wikidata.
### ---------------------------------------------------------------------------

### --- Modules
import pyspark
from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import rank, col, explode, regexp_extract
import numpy as np
import pandas as pd
import csv
from sys import stdin
import sys
from itertools import compress
import datetime
import xml.etree.ElementTree as ET

### --- Init Spark

# - Spark Session
sc = SparkSession\
    .builder\
    .appName("WD External Identifiers")\
    .enableHiveSupport()\
    .getOrCreate()

# - Spark Session Log Level: INFO
sc.sparkContext.setLogLevel("INFO")
    
# - SQL Context
sqlContext = pyspark.SQLContext(sc)

### --- parse WEIP parameters
parsFile = "/home/goransm/Analytics/Wikidata/WD_IdentifierLandscape/WDIdentifiersLandscape_Config.xml"
# - parse wdcmConfig.xml
tree = ET.parse(parsFile)
root = tree.getroot()
k = [elem.tag for elem in root.iter()]
v = [x.text for x in root.iter()]
params = dict(zip(k, v))
etl_hdfsDir = params['etl_hdfsDir']

### --- get wmf.wikidata_entity snapshot
snaps = sqlContext.sql('SHOW PARTITIONS wmf.wikidata_entity')
snaps = snaps.toPandas()
wikidataEntitySnapshot = snaps.tail(1)['partition'].to_string()
wikidataEntitySnapshot = wikidataEntitySnapshot[-10:]
### --- get wmf.mediawiki_history snapshot
snaps = sqlContext.sql('SHOW PARTITIONS wmf.mediawiki_history')
snaps = snaps.toPandas()
mwwikiSnapshot = snaps.tail(1)['partition'].to_string()
mwwikiSnapshot = mwwikiSnapshot[-7:]

### ------------------------------------------------------------------------
### --- Explode WD dump: mainSnak
### ------------------------------------------------------------------------

### --- Access WD dump
WD_dump = sqlContext.sql('SELECT id, claims.mainSnak FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
### --- Cache WD dump
WD_dump.cache()
### --- Wrangle WD_dump
WD_dump = WD_dump.withColumn('mainSnak', explode('mainSnak'))
WD_dump = WD_dump.select('id', col("mainSnak.property").alias("property"),\
                         col("mainSnak.dataType").alias("dataType"))
WD_dump = WD_dump.filter(WD_dump.dataType == 'external-id')
WD_dump = WD_dump.select('id', 'property').orderBy(["id", "property"])
# - repartition
WD_dump = WD_dump.repartition(10)

# - save to csv:
WD_dump.write.format('csv').mode("overwrite").save(etl_hdfsDir + 'wd_extId_data_stat_.csv')

# - clear
sc.catalog.clearCache()

### ------------------------------------------------------------------------
### --- Explode WD dump: References
### ------------------------------------------------------------------------

### --- Access WD dump
WD_dump = sqlContext.sql('SELECT id, claims.references FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
### --- Cache WD dump
WD_dump.cache()
### --- Wrangle WD_dump
WD_dump = WD_dump.withColumn('references', explode('references'))
WD_dump = WD_dump.withColumn('references', explode('references'))
WD_dump = WD_dump.withColumn('references', explode('references.snaks'))
WD_dump = WD_dump.select(col("id"), col("references.property").alias("property"),\
                         col("references.dataType").alias("dataType"))
WD_dump = WD_dump.filter(WD_dump.dataType == 'external-id')
WD_dump = WD_dump.select('id', 'property').orderBy(["id", "property"])
# - repartition
WD_dump = WD_dump.repartition(10)

# - save to csv:
WD_dump.write.format('csv').mode("overwrite").save(etl_hdfsDir + 'wd_extId_data_ref_.csv')

# - clear
sc.catalog.clearCache()

### ------------------------------------------------------------------------
### --- Explode WD dump: Qualifiers
### ------------------------------------------------------------------------

### --- Access WD dump
WD_dump = sqlContext.sql('SELECT id, claims.qualifiers FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
### --- Cache WD dump
WD_dump.cache()
### --- Wrangle WD_dump
WD_dump = WD_dump.withColumn('qualifiers', explode('qualifiers'))
WD_dump = WD_dump.withColumn('qualifiers', explode('qualifiers'))
WD_dump = WD_dump.select(col("id"), col("qualifiers.property").alias("property"),\
                         col("qualifiers.dataType").alias("dataType"))
WD_dump = WD_dump.filter(WD_dump.dataType == 'external-id')
WD_dump = WD_dump.select('id', 'property').orderBy(["id", "property"])
# - repartition
WD_dump = WD_dump.repartition(10)

# - save to csv:
WD_dump.write.format('csv').mode("overwrite").save(etl_hdfsDir + 'wd_extId_data_qual_.csv')

# - clear
sc.catalog.clearCache()
