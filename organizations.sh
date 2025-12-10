#!/bin/bash
set -e

if [ $# -lt 2 ]; then
  echo "Usage: $0 INPUT_FILE OUTPUT_FILE" >&2
  exit 1
fi
POPULATION=$1  # The set of QIDs to start from
OUTPUT=$2      # The output file

if [ ! -e "$POPULATION" ]
then
    echo "Can't find the \"$POPULATION\" QID starter set (text file w/ single QID per line)!"
    exit 1
fi

if [ -e "$OUTPUT" ]; then
  read -r -p "\"$OUTPUT\" exists. Overwrite? [y/N] " reply
  case "$reply" in
    [yY][eE][sS]|[yY]) ;;
    *) echo "Aborting."; exit 2 ;;
  esac
fi

# build ?member VALUES list from population.txt (each line is a QID)
population_ids=$(sed 's/^/wd:/' $POPULATION | paste -sd' ' -)

cat > orgs.rql <<SPARQL
SELECT DISTINCT
  ?member ?memberLabel
  (STRAFTER(STR(?member), "/entity/") AS ?memberQID)
  ?org ?orgLabel
  (STRAFTER(STR(?org), "/entity/") AS ?orgQID)
  ?relation
WHERE {

  VALUES ?member { $population_ids }
  VALUES ?prop { wdt:P108 wdt:P1416 } # employer or affiliation
  VALUES ?orgType { wd:Q43229 wd:Q4830453 wd:Q163740 wd:Q79913 wd:Q31855 wd:Q3918 wd:Q2385804 }
  ?org wdt:P31/wdt:P279* ?orgType.
  
  # Where they "work": employer or other institutional affiliation
  ?member ?prop ?org .
  
  FILTER (?org != wd:Q118147033)

  

  # Helpful label for the relation type
  BIND(IF(?prop = wdt:P108, "employer", "affiliation") AS ?relation)

  SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en". }
}
ORDER BY ?orgLabel ?memberLabel
SPARQL

wd sparql -f table orgs.rql | tail -n +2 > $OUTPUT
