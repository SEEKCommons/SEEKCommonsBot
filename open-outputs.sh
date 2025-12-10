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

cat > open-outputs.rql <<SPARQL
SELECT DISTINCT
  ?member ?memberLabel
  ?output ?outputLabel
  ?outputTypeLabel
  ?howLinkedLabel
  ?license ?licenseLabel
WHERE {

  # --- members ---
  VALUES ?member { $population_ids }

  # --- links from outputs to member ---
  VALUES ?howLinked { wdt:P50 wdt:P170 wdt:P178 wdt:P61 wdt:P126 wdt:P767 }  # author | creator | developer | inventor | maintained by | contributor
  ?output ?howLinked ?member .

  # --- OPEN OUTPUT CATEGORIES ---

  # 1) Open-source software (by FOSS typing OR FOSS license)
  {
    ?output wdt:P31/wdt:P279* wd:Q7397 .                       # software
    OPTIONAL { ?output wdt:P275 ?license . }                   # license (if present)
    FILTER (
      EXISTS { ?output wdt:P31/wdt:P279* wd:Q506883 }          # free and open-source software
      || EXISTS { ?output wdt:P31/wdt:P279* wd:Q1130645 }      # open-source software
      || EXISTS { ?license wdt:P279* wd:Q3943414 }             # free software license (class)
      || EXISTS { ?license wdt:P279* wd:Q97044024 }            # open-source license (class)
      || ?license IN ( wd:Q334661, wd:Q7603, wd:Q18534390, wd:Q18526202, wd:Q386474, wd:Q308915, wd:Q13785927 )
    )
    BIND("open-source software"@en AS ?outputTypeLabel)
  }
  UNION
  # 2) Open hardware (typed or by open-hardware license)
  {
    OPTIONAL { ?output wdt:P275 ?license . }
    FILTER (
      EXISTS { ?output wdt:P31/wdt:P279* wd:Q159172 }          # open hardware
      || EXISTS { ?license wdt:P31/wdt:P279* wd:Q1023365 }     # open hardware license, e.g., CERN OHL
    )
    BIND("open hardware"@en AS ?outputTypeLabel)
  }
  UNION
  # 3) Open data (dataset + CC0/CC BY/CC BY-SA)
  {
    ?output wdt:P31/wdt:P279* wd:Q1172284 .                    # dataset
    ?output wdt:P275 ?license .
    FILTER( ?license IN ( wd:Q6938433, wd:Q20007257, wd:Q18199165 ) )
    BIND("open data"@en AS ?outputTypeLabel)
  }
  UNION
  # 4) Educational resources (OER/educational resource types + CC0/CC BY/CC BY-SA)
  {
    VALUES ?eduType { wd:Q116781 }
    ?output wdt:P31/wdt:P279* ?eduType .
    ?output wdt:P275 ?license .
    FILTER( ?license IN ( wd:Q6938433, wd:Q20007257, wd:Q18199165 ) )
    BIND("educational resource"@en AS ?outputTypeLabel)
  }


  SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en". }
}
ORDER BY ?memberLabel ?outputTypeLabel ?outputLabel
SPARQL

wd sparql -f table open-outputs.rql | tail -n +2 > $OUTPUT
