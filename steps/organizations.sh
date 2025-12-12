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
  echo "No QIDs provided on stdin." >&2
  exit 1
fi

tmp_out=$(mktemp)
trap 'rm -f "$tmp_out" orgs.rql' EXIT

for ((i=0; i<${#clean_qids[@]}; i+=100)); do
  batch=("${clean_qids[@]:i:100}")
  population_ids=$(printf 'wd:%s ' "${batch[@]}")

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

  wd sparql -f table orgs.rql | tail -n +2 >> "$tmp_out"

  # Pause between batches to avoid hammering the endpoint.
  if [ $((i + 100)) -lt ${#clean_qids[@]} ]; then
    sleep 1
  fi
done

sort -u "$tmp_out"
