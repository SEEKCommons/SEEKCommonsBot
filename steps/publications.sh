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
trap 'rm -f "$tmp_out" publications.rql' EXIT

# Run against the scholarly endpoint because authored works are primarily in the
# scholarly subgraph, and `wd sparql` does not support overriding the endpoint.
endpoint="https://query-scholarly.wikidata.org/sparql"

for ((i=0; i<${#clean_qids[@]}; i+=100)); do
  batch=("${clean_qids[@]:i:100}")
  population_ids=$(printf 'wd:%s ' "${batch[@]}")

  cat > publications.rql <<SPARQL
SELECT DISTINCT ?publication
WHERE
{
  VALUES ?author { $population_ids }
  ?publication wdt:P50 ?author .
}
SPARQL

  curl -s -G "$endpoint" \
    -H 'Accept: text/tab-separated-values' \
    --data-urlencode query@publications.rql \
    | tail -n +2 | tr -d '"' | sed -E 's#^.*/##; s/[<>]//g' >> "$tmp_out"

  # Pause between batches to avoid hammering the endpoint.
  if [ $((i + 100)) -lt ${#clean_qids[@]} ]; then
    sleep 1
  fi
done

sort -u "$tmp_out"
