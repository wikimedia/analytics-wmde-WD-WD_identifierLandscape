
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
from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import rank, col, explode, regexp_extract
import numpy as np
import pandas as pd
import csv

### --- Init Spark

# - Spark Session
sc = SparkSession\
    .builder\
    .appName("WD External Identifiers - Test")\
    .enableHiveSupport()\
    .getOrCreate()
# - dump file: /user/joal/wmf/data/wmf/mediawiki/wikidata_parquet/20190204

# - SQL Context
sqlContext = pyspark.SQLContext(sc)

### ------------------------------------------------------------------------
### --- Explode WD dump: mainSnak
### ------------------------------------------------------------------------

### --- Access WD dump
WD_dump = sqlContext.read.parquet('/user/joal/wmf/data/wmf/mediawiki/wikidata_parquet/20190204')

### --- Cache WD dump
WD_dump.cache()

WD_dump = WD_dump.select('id', 'claims.mainSnak')
WD_dump = WD_dump.withColumn('mainSnak', explode('mainSnak'))
WD_dump = WD_dump.select('id', col("mainSnak.property").alias("property"),\
                         col("mainSnak.dataType").alias("dataType"))
WD_dump = WD_dump.filter(WD_dump.dataType == 'external-id')
WD_dump = WD_dump.select('id', 'property').orderBy(["id", "property"])
# - repartition
WD_dump = WD_dump.repartition(10)

# - save to csv:
WD_dump.write.format('csv').mode("overwrite").save('wd_extId_data_stat_.csv')

# - clear
sc.catalog.clearCache()

### ------------------------------------------------------------------------
### --- Explode WD dump: References
### ------------------------------------------------------------------------

### --- Access WD dump
WD_dump = sqlContext.read.parquet('/user/joal/wmf/data/wmf/mediawiki/wikidata_parquet/20190204')

### --- Cache WD dump
WD_dump.cache()

WD_dump = WD_dump.select('id', 'claims.references')
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
WD_dump.write.format('csv').mode("overwrite").save('wd_extId_data_ref_.csv')

# - clear
sc.catalog.clearCache()

### ------------------------------------------------------------------------
### --- Explode WD dump: Qualifiers
### ------------------------------------------------------------------------

### --- Access WD dump
WD_dump = sqlContext.read.parquet('/user/joal/wmf/data/wmf/mediawiki/wikidata_parquet/20190204')

### --- Cache WD dump
WD_dump.cache()

WD_dump = WD_dump.select('id', 'claims.qualifiers')
WD_dump = WD_dump.withColumn('qualifiers', explode('qualifiers'))
WD_dump = WD_dump.withColumn('qualifiers', explode('qualifiers'))
WD_dump = WD_dump.select(col("id"), col("qualifiers.property").alias("property"),\
                         col("qualifiers.dataType").alias("dataType"))
WD_dump = WD_dump.filter(WD_dump.dataType == 'external-id')
WD_dump = WD_dump.select('id', 'property').orderBy(["id", "property"])
# - repartition
WD_dump = WD_dump.repartition(1)

# - save to csv:
WD_dump.write.format('csv').mode("overwrite").save('wd_extId_data_qual_.csv')

# - clear
sc.catalog.clearCache()