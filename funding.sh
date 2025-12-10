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

# Funding sources of SEEKCommons (Q118147033) members, using only Wikidata data
# - Direct funder/sponsor on the person (P8324/P859)
# - Grants/stipends/fellowships via award received (P166) -> conferred by (P1027),
#   detected by English label match: grant|scholarship|fellowship
# - Funders/sponsors of works authored by the person (scholarly graph) (P50 -> P8324/P859)

cat > funding.rql <<SPARQL
SELECT DISTINCT
  ?member ?memberLabel
  ?fundingSource ?fundingSourceLabel
  ?evidence ?evidenceLabel
  ?path
WHERE {

  # --- members ---
  VALUES ?member { $population_ids }

  # (1) direct funder on the person
  { ?member wdt:P8324 ?fundingSource .
    BIND(?member AS ?evidence)
    BIND("member→funder (P8324)" AS ?path)
  }
  UNION
  # (2) direct sponsor on the person
  { ?member wdt:P859 ?fundingSource .
    BIND(?member AS ?evidence)
    BIND("member→sponsor (P859)" AS ?path)
  }
  UNION
  # (3) grant/stipend/fellowship as award received → awarding body
  { ?member wdt:P166 ?award .
    ?award  wdt:P1027 ?fundingSource .      # conferred by (awarding/funding body)
    OPTIONAL { ?award rdfs:label ?awardLabel FILTER (lang(?awardLabel) = "en") }
    FILTER (BOUND(?awardLabel) &&
            REGEX(LCASE(STR(?awardLabel)), "grant|scholarship|fellowship"))
    BIND(?award AS ?evidence)
    BIND("award received→conferred by (P1027)" AS ?path)
  }
  UNION
  # (4) funder of an authored work (scholarly graph)
  { ?work wdt:P50 ?member ;
          wdt:P8324 ?fundingSource .
    BIND(?work AS ?evidence)
    BIND("authored work→funder (P8324)" AS ?path)
  }
  UNION
  # (5) sponsor of an authored work (scholarly graph)
  { ?work wdt:P50 ?member ;
          wdt:P859 ?fundingSource .
    BIND(?work AS ?evidence)
    BIND("authored work→sponsor (P859)" AS ?path)
  }

  SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en". }
}
ORDER BY ?memberLabel ?fundingSourceLabel ?path
SPARQL

wd sparql -f table funding.rql | tail -n +2 > $OUTPUT
