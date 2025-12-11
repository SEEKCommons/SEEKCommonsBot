#!/bin/bash
set -e

# Build ?member VALUES list from stdin (each line is a QID).
population_ids=$(sed 's/^/wd:/' | paste -sd' ' -)

if [ -z "$population_ids" ]; then
  echo "No population IDs provided on stdin." >&2
  exit 1
fi

# Shared topics among SEEKCommons members (main + scholarly graphs)
# Run on: https://query.wikidata.org/  (main graph host)
# Uses internal federation for the scholarly subgraph per WDQS split.

cat > topics.rql <<SPARQL
SELECT ?topic
WHERE
{
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
}
GROUP BY ?topic
HAVING (COUNT(DISTINCT ?member) >= 2)
SPARQL

wd sparql -f table topics.rql | tail -n +2 | sort -u
