#!/bin/bash
set -e

# Build ?member VALUES list from stdin (each line is a QID).
population_ids=$(sed 's/^/wd:/' | paste -sd' ' -)

if [ -z "$population_ids" ]; then
  echo "No population IDs provided on stdin." >&2
  exit 1
fi

# Funding sources of SEEKCommons (Q118147033) members, using only Wikidata data
# - Direct funder/sponsor on the person (P8324/P859)
# - Grants/stipends/fellowships via award received (P166) -> conferred by (P1027),
#   detected by English label match: grant|scholarship|fellowship
# - Funders/sponsors of works authored by the person (scholarly graph) (P50 -> P8324/P859)

cat > funding.rql <<SPARQL
SELECT DISTINCT ?fundingSource
WHERE
{
  # --- members ---
  VALUES ?member { $population_ids }

  # (1) direct funder on the person
  { ?member wdt:P8324 ?fundingSource .
  }
  UNION
  # (2) direct sponsor on the person
  { ?member wdt:P859 ?fundingSource .
  }
  UNION
  # (3) grant/stipend/fellowship as award received → awarding body
  { ?member wdt:P166 ?award .
    ?award  wdt:P1027 ?fundingSource .      # conferred by (awarding/funding body)
  }
  UNION
  # (4) funder of an authored work (scholarly graph)
  { ?work wdt:P50 ?member ;
          wdt:P8324 ?fundingSource .
  }
  UNION
  # (5) sponsor of an authored work (scholarly graph)
  { ?work wdt:P50 ?member ;
          wdt:P859 ?fundingSource .
  }
}
SPARQL

wd sparql -f table funding.rql | tail -n +2 | sort -u
