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

# Shared topics among SEEKCommons members (main + scholarly graphs)
# Run on: https://query.wikidata.org/  (main graph host)
# Uses internal federation for the scholarly subgraph per WDQS split.

cat > topics.rql <<SPARQL
SELECT
  ?topic ?topicLabel
  (STRAFTER(STR(?topic), "entity/") AS ?topicQid)
  (COUNT(DISTINCT ?member) AS ?memberCount)
  (GROUP_CONCAT(DISTINCT STRAFTER(STR(?member), "entity/"); separator=", ") AS ?memberQids)
WHERE {
  hint:Query hint:optimizer "None" .  # helps with federated performance

  # --- members ---
  VALUES ?member { $population_ids }
  
  # --- Gather (member, topic) pairs from two sources ---

  # 1) Direct field of work for the member (main graph)
  { ?member wdt:P101 ?topic . }

  UNION

  # 2a) Topics of works authored by the member (works that remain in main graph)
  { ?work wdt:P50 ?member ;
          wdt:P921 ?topic . }

  UNION

  # 2b) Topics of works authored by the member (scholarly subgraph)
  {
    SERVICE wdsubgraph:scholarly_articles {
      ?work wdt:P50 ?member ;
            wdt:P921 ?topic .
      # (We do not fetch labels here; topic/person labels live in main.)
    }
  }

  # Pull human‑readable topic labels from the main graph
  SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en". }
}
GROUP BY ?topic ?topicLabel
HAVING (COUNT(DISTINCT ?member) >= 2)
ORDER BY DESC(?memberCount) ?topicLabel
SPARQL

wd sparql -f table topics.rql | tail -n +2 > $OUTPUT
