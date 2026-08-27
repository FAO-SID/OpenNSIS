#!/bin/bash

# variables
PROJECT_DIR="/home/carva014/Work/Code/FAO/OpenNSIS"      # << EDIT THIS LINE!
DATE=`date +%Y-%m-%d`
clear


#################
#   Database    #
#################


pg_dump -h localhost -p 5432 -d sis -U sis -F plain -v --schema-only -f $PROJECT_DIR/sis-database/sis-database_v$DATE.sql
pg_dump -h localhost -p 5432 -d sis -U sis -F plain -v --schema-only -f $PROJECT_DIR/sis-database/sis-database_latest.sql
pg_dump -h localhost -p 5432 -d sis -U sis -F plain -v -f $PROJECT_DIR/sis-database/sis-database_latest_with_codelist.sql
psql -h localhost -p 5432 -d postgres -U postgres -c "DROP DATABASE IF EXISTS sis"
psql -h localhost -p 5432 -d postgres -U sis -c "CREATE DATABASE sis"


#################
#   Extension   #
#################

psql -h localhost -p 5432 -d sis -U sis -c "CREATE EXTENSION IF NOT EXISTS postgis"
psql -h localhost -p 5432 -d sis -U sis -c "CREATE EXTENSION IF NOT EXISTS postgis_raster"
psql -h localhost -p 5432 -d sis -U sis -c "CREATE EXTENSION IF NOT EXISTS postgis_sfcgal"
psql -h localhost -p 5432 -d sis -U sis -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp"'


#################
#   Schemas     #
#################

psql -h localhost -p 5432 -d sis -U sis -f $PROJECT_DIR/sis-database/sis-database_latest.sql


#################
#   Inserts     #
#################

psql -h localhost -p 5432 -d sis -U sis -f $PROJECT_DIR/sis-database/owl2sql/output/property_desc.sql
psql -h localhost -p 5432 -d sis -U sis -f $PROJECT_DIR/sis-database/owl2sql/output/category_desc.sql
psql -h localhost -p 5432 -d sis -U sis -c "INSERT INTO soil_data.procedure_desc (procedure_desc_id,reference,uri) VALUES
	 ('FAO GfSD 2006','Food and Agriculture Organisation of the United Nations, Guidelines for Soil Description, Fourth Edition, 2006.','https://www.fao.org/publications/card/en/c/903943c7-f56a-521a-8d32-459e7e0cdae9/'),
	 ('FAO GfSD 1990','Food and Agriculture Organisation of the United Nations, Guidelines for Soil Description, Fourth Edition, 1990','FAO GfSD 1990'),
	 ('ISRIC Report 2019/01','ISRIC Report 2019/01: Tier 1 and Tier 2 data in the context of the federated Global Soil Information System','https://www.isric.org/documents/document-type/isric-report-201901-tier-1-and-tier-2-data-context-federated-global-soil'),
	 ('Keys to Soil Taxonomy 13th edition 2022','Keys to Soil Taxonomy, 13th ed.2022','https://nrcspad.sc.egov.usda.gov/DistributionCenter/product.aspx?ProductID=1709'),
	 ('Köppen-Geiger Climate Classification','DOI: 10.1127/0941-2948/2006/0130','https://www.schweizerbart.de/papers/metz/detail/15/55034/World_Map_of_the_Koppen_Geiger_climate_classificat?af=crossref'),
	 ('Soil Survey Manual 2017','Soil Survey Manual 2017','https://www.nrcs.usda.gov/resources/guides-and-instructions/soil-survey-manual'),
	 ('WRB fourth edition 2022','WRB fourth edition 2022','https://www.fao.org/soils-portal/data-hub/soil-classification/world-reference-base/en/');"
psql -h localhost -p 5432 -d sis -U sis -f $PROJECT_DIR/sis-database/owl2sql/output/observation_desc.sql
psql -h localhost -p 5432 -d sis -U sis -f $PROJECT_DIR/sis-database/owl2sql/output/property_num.sql
psql -h localhost -p 5432 -d sis -U sis -f $PROJECT_DIR/sis-database/owl2sql/output/procedure_num.sql
psql -h localhost -p 5432 -d sis -U sis -f $PROJECT_DIR/sis-database/owl2sql/output/unit_of_measure.sql
psql -h localhost -p 5432 -d sis -U sis -f $PROJECT_DIR/sis-database/owl2sql/output/observation_num.sql
psql -h localhost -p 5432 -d sis -U sis -f $PROJECT_DIR/sis-database/owl2sql/fix.sql
psql -h localhost -p 5432 -d sis -U sis -f $PROJECT_DIR/sis-database/data_country.sql
psql -h localhost -p 5432 -d sis -U sis -f $PROJECT_DIR/sis-database/data_mapped_property.sql


#################
#   Dump        #
#################

pg_dump -h localhost -p 5432 -d sis -U sis -F plain -v --schema-only -f $PROJECT_DIR/sis-database/sis-database_v$DATE.sql
pg_dump -h localhost -p 5432 -d sis -U sis -F plain -v --schema-only -f $PROJECT_DIR/sis-database/sis-database_latest.sql
pg_dump -h localhost -p 5432 -d sis -U sis -F plain -v -f $PROJECT_DIR/sis-database/sis-database_latest_with_codelist.sql