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
endpoint="https://query-scholarly.wikidata.org/sparql"

cat > coauthors.rql <<SPARQL
SELECT DISTINCT
  ?coauthorLabel
WHERE {

  # --- members ---
  VALUES ?author { $population_ids }

  # works authored by member with another listed author
  ?work wdt:P50 ?author .
  ?work wdt:P50 ?coauthor .
  FILTER(?coauthor != ?author)

  SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en". }
}
ORDER BY ?coauthorLabel
SPARQL

# Run via curl because `wd sparql` lacks a flag to override the endpoint.
curl -s -G "$endpoint" \
  -H 'Accept: text/tab-separated-values' \
  --data-urlencode query@coauthors.rql \
  | tail -n +2 | tr -d '"' > $OUTPUT
