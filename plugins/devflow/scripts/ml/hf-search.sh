#!/usr/bin/env bash
# Search the Hugging Face Hub for models or datasets and print one JSON line
# per repo with the facts a shortlist needs: licence, gating, size, popularity,
# freshness. Public search needs no token; HF_TOKEN, when set, is sent so gated
# or private repos you can access show up too. Never prints the token.
#
# Usage: hf-search.sh models|datasets <query> [--filter TAG]... [--author NAME]
#                     [--sort downloads|likes|trendingScore|createdAt|lastModified]
#                     [--limit N] [--dry-run]
#   --filter is ANDed and repeatable: a task (text-classification), a library
#   (peft, gguf), a licence (license:apache-2.0), a language (uk), a size
#   (size_categories:10K<n<100K). Use --filter peft, not "library=peft": the
#   API ignores unknown parameters silently.
#
# Output fields: id, licence ("NONE" when the repo declares none: unusable
# until its owner says otherwise), gated, downloads_30d, likes, last_modified,
# and params (models) or size (datasets). Zero results is ambiguous on this
# API (an unknown filter also returns []), so the script says which filters
# were applied.
set -uo pipefail
kind="${1:-}"; query="${2:-}"
case "$kind" in models|datasets) ;; *) echo "usage: hf-search.sh models|datasets <query> [options]" >&2; exit 2 ;; esac
shift 2 2>/dev/null || { echo "usage: hf-search.sh models|datasets <query> [options]" >&2; exit 2; }
sort=downloads; limit=20; author=""; dry=""; filters=()
while [ $# -gt 0 ]; do
  case "$1" in
    --filter) filters+=("$2"); shift 2 ;;
    --author) author="$2"; shift 2 ;;
    --sort)   sort="$2"; shift 2 ;;
    --limit)  limit="$2"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    *) echo "ERROR: unknown option $1" >&2; exit 2 ;;
  esac
done
case "$sort" in downloads|likes|trendingScore|createdAt|lastModified) ;; *) echo "ERROR: --sort must be downloads, likes, trendingScore, createdAt or lastModified" >&2; exit 2 ;; esac
[[ "$limit" =~ ^[0-9]+$ ]] && [ "$limit" -ge 1 ] && [ "$limit" -le 1000 ] || { echo "ERROR: --limit must be 1..1000" >&2; exit 2; }

enc() { jq -rn --arg v "$1" '$v|@uri'; }
url="https://huggingface.co/api/$kind?sort=$sort&limit=$limit"
[ -n "$query" ] && url+="&search=$(enc "$query")"
[ -n "$author" ] && url+="&author=$(enc "$author")"
for f in ${filters[@]+"${filters[@]}"}; do url+="&filter=$(enc "$f")"; done
for e in downloads likes gated lastModified cardData tags; do url+="&expand%5B%5D=$e"; done
[ "$kind" = models ] && url+="&expand%5B%5D=safetensors&expand%5B%5D=pipeline_tag"

if [ -n "$dry" ]; then echo "$url"; exit 0; fi
auth=(); [ -n "${HF_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $HF_TOKEN")
body=$(curl -sf ${auth[@]+"${auth[@]}"} "$url") || { echo "ERROR: request failed: $url" >&2; exit 3; }
n=$(jq 'length' <<<"$body")
if [ "$n" = 0 ]; then
  echo "no results for: query='$query' filters='${filters[*]:-}' author='$author' (an unknown filter also gives 0)" >&2
  exit 0
fi
jq -c --arg kind "$kind" '.[] | {
  id,
  license: (.cardData.license // ([.tags[]? | select(startswith("license:")) | sub("^license:"; "")][0]) // "NONE"),
  gated: (.gated // false),
  downloads_30d: .downloads,
  likes,
  last_modified: ((.lastModified // "")[0:10]),
} + (if $kind == "models"
      then {task: .pipeline_tag, params: .safetensors.total}
      else {size: ([.tags[]? | select(startswith("size_categories:")) | sub("^size_categories:"; "")][0])} end)' <<<"$body"
