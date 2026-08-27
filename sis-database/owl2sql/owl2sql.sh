#!/bin/bash

clear
PROJECT_DIR="/home/carva014/Work/Code/FAO/OpenNSIS/sis-database/owl2sql"
cd $PROJECT_DIR


# Create folders
mkdir -p ontology
mkdir -p output


# Start Virtuoso
docker run -d \
    --name virtuoso \
    -p 8890:8890 \
    -p 1111:1111 \
    -e DBA_PASSWORD=dba \
    -e VIRT_Parameters_DirsAllowed="., /database, /opt/virtuoso-opensource/vad" \
    -v "$(pwd)/ontology:/database" \
    openlink/virtuoso-opensource-7:latest

# Wait ~10 seconds, then test
sleep 10


# Download GloSIS modules
cd $PROJECT_DIR/ontology
curl -fsSLO https://raw.githubusercontent.com/glosis-ld/glosis/refs/heads/v2.0/glosis_cl.ttl
curl -fsSLO https://raw.githubusercontent.com/glosis-ld/glosis/refs/heads/v2.0/glosis_common.ttl
curl -fsSLO https://raw.githubusercontent.com/glosis-ld/glosis/refs/heads/v2.0/glosis_layer_horizon.ttl
curl -fsSLO https://raw.githubusercontent.com/glosis-ld/glosis/refs/heads/v2.0/glosis_main.ttl
curl -fsSLO https://raw.githubusercontent.com/glosis-ld/glosis/refs/heads/v2.0/glosis_observation.ttl
curl -fsSLO https://raw.githubusercontent.com/glosis-ld/glosis/refs/heads/v2.0/glosis_procedure.ttl
curl -fsSLO https://raw.githubusercontent.com/glosis-ld/glosis/refs/heads/v2.0/glosis_profile.ttl
curl -fsSLO https://raw.githubusercontent.com/glosis-ld/glosis/refs/heads/v2.0/glosis_siteplot.ttl
curl -fsSLO https://raw.githubusercontent.com/glosis-ld/glosis/refs/heads/v2.0/glosis_surface.ttl
curl -fsSLO https://raw.githubusercontent.com/glosis-ld/glosis/refs/heads/v2.0/glosis_unit.ttl
curl -fsSLO https://raw.githubusercontent.com/glosis-ld/glosis/refs/heads/v2.0/iso28258.ttl


# Isseu https://github.com/glosis-ld/glosis/issues/212
# Fix the typo: replace cm: with om: for centimolePerLitre
sed -i 's/cm:centimolePerLitre/om:centimolePerLitre/g' glosis_layer_horizon.ttl


# Import ontology files
cd $PROJECT_DIR
docker exec virtuoso isql 1111 dba dba exec="DB.DBA.TTLP_MT (file_to_string_output ('/database/glosis_cl.ttl'), '', 'http://w3id.org/glosis/model/codelists');"
docker exec virtuoso isql 1111 dba dba exec="DB.DBA.TTLP_MT (file_to_string_output ('/database/glosis_common.ttl'), '', 'http://w3id.org/glosis/model/common');"
docker exec virtuoso isql 1111 dba dba exec="DB.DBA.TTLP_MT (file_to_string_output ('/database/glosis_layer_horizon.ttl'), '', 'http://w3id.org/glosis/model/layerhorizon');"
docker exec virtuoso isql 1111 dba dba exec="DB.DBA.TTLP_MT (file_to_string_output ('/database/glosis_main.ttl'), '', 'http://w3id.org/glosis/model/main');"
docker exec virtuoso isql 1111 dba dba exec="DB.DBA.TTLP_MT (file_to_string_output ('/database/glosis_observation.ttl'), '', 'http://w3id.org/glosis/model/observation');"
docker exec virtuoso isql 1111 dba dba exec="DB.DBA.TTLP_MT (file_to_string_output ('/database/glosis_procedure.ttl'), '', 'http://w3id.org/glosis/model/procedure');"
docker exec virtuoso isql 1111 dba dba exec="DB.DBA.TTLP_MT (file_to_string_output ('/database/glosis_profile.ttl'), '', 'http://w3id.org/glosis/model/profile');"
docker exec virtuoso isql 1111 dba dba exec="DB.DBA.TTLP_MT (file_to_string_output ('/database/glosis_siteplot.ttl'), '', 'http://w3id.org/glosis/model/siteplot');"
docker exec virtuoso isql 1111 dba dba exec="DB.DBA.TTLP_MT (file_to_string_output ('/database/glosis_surface.ttl'), '', 'http://w3id.org/glosis/model/surface');"
docker exec virtuoso isql 1111 dba dba exec="DB.DBA.TTLP_MT (file_to_string_output ('/database/glosis_unit.ttl'), '', 'http://w3id.org/glosis/model/unit');"
docker exec virtuoso isql 1111 dba dba exec="DB.DBA.TTLP_MT (file_to_string_output ('/database/iso28258.ttl'), '', 'http://w3id.org/glosis/model/iso28258');"


# Generate SQL files, extracting only INSERT statements
docker exec -i virtuoso isql 1111 dba dba < sparql/property_desc.sparql 2>/dev/null | grep "^INSERT" > output/property_desc.sql
docker exec -i virtuoso isql 1111 dba dba < sparql/category_desc.sparql 2>/dev/null | grep "^INSERT" > output/category_desc.sql
docker exec -i virtuoso isql 1111 dba dba < sparql/observation_desc.sparql 2>/dev/null | grep "^INSERT" > output/observation_desc.sql
docker exec -i virtuoso isql 1111 dba dba < sparql/property_num.sparql 2>/dev/null | grep "^INSERT" > output/property_num.sql
docker exec -i virtuoso isql 1111 dba dba < sparql/procedure_num.sparql 2>/dev/null | grep "^INSERT" > output/procedure_num.sql
docker exec -i virtuoso isql 1111 dba dba < sparql/observation_num.sparql 2>/dev/null | grep "^INSERT" > output/observation_num.sql
# Issue https://github.com/glosis-ld/glosis/issues/182
# docker exec -i virtuoso isql 1111 dba dba < sparql/unit_of_measure.sparql 2>/dev/null | grep "^INSERT" > output/unit_of_measure.sql
# Extracted units from observation_num.sql
grep -oP "unit_of_measure WHERE uri LIKE '\K[^']+" output/observation_num.sql | sort -u | while read uri; do
    unit_id="${uri##*/}"
    query="SELECT ?label WHERE { <$uri> <http://www.w3.org/2000/01/rdf-schema#label> ?label . FILTER(lang(?label) = 'en') } LIMIT 1"
    label=$(curl -sf -G "https://www.qudt.org/sparql" \
        --data-urlencode "query=$query" \
        -H "Accept: application/sparql-results+json" \
        | grep -oP '"value"\s*:\s*"\K[^"]+')
    [ -z "$label" ] && label="$unit_id"
    echo "INSERT INTO soil_data.unit_of_measure (unit_of_measure_id, unit_name, uri) VALUES ('${unit_id}', '${label}', '${uri}') ON CONFLICT DO NOTHING;"
done > output/unit_of_measure.sql


# Clean up
docker stop virtuoso
docker rm virtuoso
rm -Rf $PROJECT_DIR/ontology