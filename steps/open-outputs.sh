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
trap 'rm -f "$tmp_out" open-outputs.rql' EXIT

for ((i=0; i<${#clean_qids[@]}; i+=100)); do
  batch=("${clean_qids[@]:i:100}")
  population_ids=$(printf 'wd:%s ' "${batch[@]}")

  cat > open-outputs.rql <<SPARQL
SELECT DISTINCT ?output
WHERE
{
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
  }
  UNION
  # 2) Open hardware (typed or by open-hardware license)
  {
    OPTIONAL { ?output wdt:P275 ?license . }
    FILTER (
      EXISTS { ?output wdt:P31/wdt:P279* wd:Q159172 }          # open hardware
      || EXISTS { ?license wdt:P31/wdt:P279* wd:Q1023365 }     # open hardware license, e.g., CERN OHL
    )
  }
  UNION
  # 3) Open data (dataset + CC0/CC BY/CC BY-SA)
  {
    ?output wdt:P31/wdt:P279* wd:Q1172284 .                    # dataset
    ?output wdt:P275 ?license .
    FILTER( ?license IN ( wd:Q6938433, wd:Q20007257, wd:Q18199165 ) )
  }
  UNION
  # 4) Educational resources (OER/educational resource types + CC0/CC BY-SA)
  {
    VALUES ?eduType { wd:Q116781 }
    ?output wdt:P31/wdt:P279* ?eduType .
    ?output wdt:P275 ?license .
    FILTER( ?license IN ( wd:Q6938433, wd:Q20007257, wd:Q18199165 ) )
  }
}
SPARQL

  wd sparql -f table open-outputs.rql | tail -n +2 >> "$tmp_out"

  # Pause between batches to avoid hammering the endpoint.
  if [ $((i + 100)) -lt ${#clean_qids[@]} ]; then
    sleep 1
  fi
done

sort -u "$tmp_out"
