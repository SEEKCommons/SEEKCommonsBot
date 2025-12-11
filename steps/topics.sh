#!/bin/bash
set -e

# Build QID list from stdin (one QID per line).
mapfile -t qids
clean_qids=()
for qid in "${qids[@]}"; do
  qid=${qid//[[:space:]]/}
  if [ -n "$qid" ]; then
    clean_qids+=("$qid")
  fi
done

if [ ${#clean_qids[@]} -eq 0 ]; then
  echo "No population IDs provided on stdin." >&2
  exit 1
fi

tmp_out=$(mktemp)
trap 'rm -f "$tmp_out" topics.rql' EXIT

# Shared topics among SEEKCommons members (main + scholarly graphs)
# Run on: https://query.wikidata.org/  (main graph host)
# Uses internal federation for the scholarly subgraph per WDQS split.

for ((i=0; i<${#clean_qids[@]}; i+=100)); do
  batch=("${clean_qids[@]:i:100}")
  population_ids=$(printf 'wd:%s ' "${batch[@]}")

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

  wd sparql -f table topics.rql | tail -n +2 >> "$tmp_out"

  # Pause between batches to avoid hammering the endpoint.
  if [ $((i + 100)) -lt ${#clean_qids[@]} ]; then
    sleep 1
  fi
done

sort -u "$tmp_out"
