
### ---------------------------------------------------------------------------
### --- WD_IdentifierLandscape_Data.py
### --- Authors: Goran S. Milovanovic, Data Scientist, WMDE
### --- Developed under the contract between Goran Milovanovic PR Data Kolektiv
### --- and WMDE.
### --- Contact: goran.milovanovic_ext@wikimedia.de
### --- March 2019.
### ---------------------------------------------------------------------------
### --- COMMENT:
### --- Pyspark ETL procedures for the WD JSON dumps in hdfs
### ---------------------------------------------------------------------------
### ---------------------------------------------------------------------------
### --- LICENSE:
### ---------------------------------------------------------------------------
### --- GPL v2
### --- This file is part of Wikidata Concepts Monitor (WDCM)
### ---
### --- WDCM is free software: you can redistribute it and/or modify
### --- it under the terms of the GNU General Public License as published by
### --- the Free Software Foundation, either version 2 of the License, or
### --- (at your option) any later version.
### ---
### --- WDCM is distributed in the hope that it will be useful,
### --- but WITHOUT ANY WARRANTY; without even the implied warranty of
### --- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
### --- GNU General Public License for more details.
### ---
### --- You should have received a copy of the GNU General Public License
### --- along with WDCM. If not, see <http://www.gnu.org/licenses/>.
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
from pyspark.sql import SparkSession
from pyspark.sql.functions import rank, col, explode, regexp_extract
import numpy as np
import pandas as pd
import csv
import xml.etree.ElementTree as ET
from sys import stdin
import sys
import re

# - where is the script being run from:
parsFile = str(sys.path[0]) + "/WDIdentifiersLandscape_Config.xml"
# - parse config XML file
tree = ET.parse(parsFile)
root = tree.getroot()
k = [elem.tag for elem in root.iter()]
v = [x.text for x in root.iter()]
params = dict(zip(k, v))
publicDir = params['dataDir']

### --- Init Spark

# - Spark Session
sc = SparkSession\
    .builder\
    .appName("WD Identifiers Landscape")\
    .enableHiveSupport()\
    .getOrCreate()

# - SQL Context
sqlContext = pyspark.SQLContext(sc)

### --- Access WD dump
WD_dump = sqlContext.read.parquet(params['WD_dumpFile'])

### --- Explode WD dump
WD_dump = WD_dump.select('id', 'claims.references')
WD_dump = WD_dump.withColumn('references', explode('references'))
WD_dump = WD_dump.withColumn('references', explode('references'))
WD_dump = WD_dump.withColumn('references', explode('references.snaks'))
WD_dump = WD_dump.select(col("id"), col("references.property").alias("property"),\
                         col("references.dataType").alias("dataType"))
WD_dump = WD_dump.filter(WD_dump.dataType == 'external-id')
WD_dump = WD_dump.select('id', 'property')

### --- Cache WD dump
WD_dump.cache()

### --- clean up
# - create View from WDCM_MainTableRaw
WD_dump.createTempView("wddump")
# - SQL for regex
WD_dump = WD_dump.select(regexp_extract('id', r'Q(\d+)', 1).alias('id'), \
                    regexp_extract('property', r'P(\d+)', 1).alias('property'))

### --- randomSplit; loop over batches, process and store:
s = list(np.repeat(.01, 99))
splits = WD_dump.randomSplit(s, 11)
c = 0
for sp in splits:
    c = c + 1
    df = pd.DataFrame(data={"col1": sp.collect()})
    df.to_csv(publicDir + "split_" + str(c) + ".csv",\
              sep=',', index=False)




