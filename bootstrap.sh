#!/bin/bash
set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 OUTPUT_FILE" >&2
  exit 1
fi
OUTPUT=$1  # The output file

if [ -e "$OUTPUT" ]; then
  read -r -p "\"$OUTPUT\" exists. Overwrite? [y/N] " reply
  case "$reply" in
    [yY][eE][sS]|[yY]) ;;
    *) echo "Aborting."; exit 1 ;;
  esac
fi

# search for SEEKCommons affiliations
cat > population.rql <<SPARQL
SELECT DISTINCT ?member
WHERE {
  BIND(wd:Q118147033 AS ?SEEKCommons)  # SEEKCommons
  {
    # Organizations listed as participants of SEEKCommons
    ?SEEKCommons wdt:P710 ?member .
    BIND("organization (participant)" AS ?role)
  }
  UNION
  {
    # People affiliated with SEEKCommons
    ?member wdt:P1416 ?SEEKCommons .        # affiliation SEEKCommons
    FILTER EXISTS { ?member wdt:P31 wd:Q5 } # instance of human      
    BIND("person (affiliation)" AS ?role)
  }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en". }
}
ORDER BY ?role ?memberLabel
SPARQL

wd sparql -f table population.rql | tail -n +2 > "$OUTPUT"
