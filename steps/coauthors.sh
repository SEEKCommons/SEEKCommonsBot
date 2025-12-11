#!/bin/bash
set -e

# Build ?member VALUES list from stdin (each line is a QID).
population_ids=$(sed 's/^/wd:/' | paste -sd' ' -)

if [ -z "$population_ids" ]; then
  echo "No population IDs provided on stdin." >&2
  exit 1
fi
endpoint="https://query-scholarly.wikidata.org/sparql"

cat > coauthors.rql <<SPARQL
SELECT DISTINCT ?coauthor
WHERE
{
  # --- members ---
  VALUES ?author { $population_ids }

  # works authored by member with another listed author
  ?work wdt:P50 ?author .
  ?work wdt:P50 ?coauthor .
  FILTER(?coauthor != ?author)
}
SPARQL

# Run via curl because `wd sparql` lacks a flag to override the endpoint.
curl -s -G "$endpoint" \
  -H 'Accept: text/tab-separated-values' \
  --data-urlencode query@coauthors.rql \
  | tail -n +2 | tr -d '"' | sed -E 's#^.*/##; s/[<>]//g' | sort -u
