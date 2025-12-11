#!/bin/bash
set -e

# Build ?member VALUES list from stdin (each line is a QID).
population_ids=$(sed 's/^/wd:/' | paste -sd' ' -)

if [ -z "$population_ids" ]; then
  echo "No population IDs provided on stdin." >&2
  exit 1
fi

cat > orgs.rql <<SPARQL
SELECT DISTINCT ?org
WHERE
{
  VALUES ?member { $population_ids }
  VALUES ?prop { wdt:P108 wdt:P1416 } # employer or affiliation
  VALUES ?orgType { wd:Q43229 wd:Q4830453 wd:Q163740 wd:Q79913 wd:Q31855 wd:Q3918 wd:Q2385804 }
  ?org wdt:P31/wdt:P279* ?orgType.
  
  # Where they "work": employer or other institutional affiliation
  ?member ?prop ?org .
  
  FILTER (?org != wd:Q118147033)
}
SPARQL

wd sparql -f table orgs.rql | tail -n +2 | sort -u
