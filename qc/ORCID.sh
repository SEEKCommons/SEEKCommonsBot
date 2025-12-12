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
trap 'rm -f "$tmp_out" ORCID.rql' EXIT

for ((i=0; i<${#clean_qids[@]}; i+=200)); do
  batch=("${clean_qids[@]:i:200}")
  population_ids=$(printf 'wd:%s ' "${batch[@]}")

  cat > ORCID.rql <<SPARQL
SELECT DISTINCT ?member
WHERE
{
  VALUES ?member { $population_ids }
  FILTER NOT EXISTS { ?member wdt:P496 [] }
}
SPARQL

  wd sparql -f table ORCID.rql | tail -n +2 >> "$tmp_out"

  # Pause between batches to avoid hammering the endpoint.
  if [ $((i + 200)) -lt ${#clean_qids[@]} ]; then
    sleep 1
  fi
done

sort -u "$tmp_out"