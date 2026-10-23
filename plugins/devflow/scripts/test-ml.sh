#!/usr/bin/env bash
# The ML helpers: leakage.py on fixtures, hf-search.sh argument handling
# (offline, --dry-run). Exit status is the number of failures.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fails=0
is() { if [ "$1" = "$2" ]; then echo "ok    $3"; else echo "FAIL  $3: want '$1' got '$2'"; fails=$((fails+1)); fi; }
L() { python3 -I "$here/ml/leakage.py" "$@"; }

long_a="the quick brown fox jumps over the lazy dog near the river bank on a sunny morning"
long_b="a completely different sentence about invoices taxes and quarterly reports for small firms"
printf '%s\n' "{\"text\": \"$long_a\"}" '{"text": "Hello, World!"}' '{"text": "only in train"}' > "$tmp/train.jsonl"
printf '%s\n' '{"text": "only in train"}' '{"text": "hello world"}' \
  "{\"text\": \"prefix words then $long_a and more\"}" "{\"text\": \"$long_b\"}" '{"text": "short new one"}' > "$tmp/test.jsonl"

out=$(L --train "$tmp/train.jsonl" --test "$tmp/test.jsonl"); rc=$?
is 1 "$rc" "leak found -> exit 1"
is 1 "$(jq .exact <<<"$out")" "exact duplicate"
is 1 "$(jq .normalized <<<"$out")" "case/punctuation-only difference is a normalized duplicate"
is 1 "$(jq .ngram_overlap <<<"$out")" "a shared 13-gram inside a longer example"
is 3 "$(jq .leaked <<<"$out")" "total leaked"
is 1 "$(jq .too_short_for_ngram <<<"$out")" "short clean example is counted, not judged by n-grams"

printf '%s\n' "{\"text\": \"$long_b\"}" > "$tmp/clean_test.jsonl"
L --train "$tmp/train.jsonl" --test "$tmp/clean_test.jsonl" >/dev/null; is 0 $? "clean test set -> exit 0"

printf 'question,answer\nwhat is two plus two,four\n' > "$tmp/train.csv"
printf 'question,answer\nWHAT is two plus two?,four\n' > "$tmp/test.csv"
out=$(L --train "$tmp/train.csv" --test "$tmp/test.csv" --field question --field answer); is 1 "$(jq .normalized <<<"$out")" "csv with two fields joined"

L --train "$tmp/train.jsonl" --test "$tmp/test.jsonl" --field missing 2>/dev/null; is 2 $? "missing field -> exit 2"
L --train "$tmp/train.jsonl" --test "$tmp/nope.parquet" 2>/dev/null; is 2 $? "unsupported file -> exit 2"

S="$here/ml/hf-search.sh"
u=$("$S" datasets "ukr news" --filter "license:mit" --filter "size_categories:10K<n<100K" --author someone --sort likes --limit 7 --dry-run)
case "$u" in *"/api/datasets?sort=likes&limit=7&search=ukr%20news&author=someone&filter=license%3Amit&filter=size_categories%3A10K%3Cn%3C100K"*) echo "ok    dry-run URL encodes query, author and ANDed filters"; ;; *) echo "FAIL  dry-run URL: $u"; fails=$((fails+1)) ;; esac
case "$("$S" models q --dry-run)" in *safetensors*pipeline_tag*) echo "ok    models expand params and task" ;; *) echo "FAIL  models expand"; fails=$((fails+1)) ;; esac
"$S" spaces q --dry-run 2>/dev/null; is 2 $? "unknown kind rejected"
"$S" models q --sort bogus --dry-run 2>/dev/null; is 2 $? "unknown sort rejected"
"$S" models q --limit 5000 --dry-run 2>/dev/null; is 2 $? "limit above the API cap rejected"

echo "failures: $fails"
exit $fails
