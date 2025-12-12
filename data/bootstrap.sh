#!/bin/bash
set -e

trap 'rm -f population.rql' EXIT

# search for SEEKCommons affiliations
cat > population.rql <<SPARQL
SELECT DISTINCT ?member
WHERE {
  BIND(wd:Q118147033 AS ?SEEKCommons)  # SEEKCommons
  {
    # Organizations listed as participants of SEEKCommons
    ?SEEKCommons wdt:P710 ?member .
  }
  UNION
  {
    # People affiliated with SEEKCommons
    ?member wdt:P1416 ?SEEKCommons .        # affiliation SEEKCommons
    FILTER EXISTS { ?member wdt:P31 wd:Q5 } # instance of human
  }
}
ORDER BY ?role ?memberLabel
SPARQL

wd sparql -f table population.rql | tail -n +2 | sort -u
