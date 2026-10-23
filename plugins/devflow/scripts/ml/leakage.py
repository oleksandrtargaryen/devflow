#!/usr/bin/env python3
"""Train/test leakage check: does the evaluation set overlap the training set?

A metric measured on examples the model trained on says nothing about new
data. Three levels, from cheapest to broadest:

  exact       the same example text in both sets;
  normalized  equal after Unicode NFKC, lowercasing, dropping punctuation and
              collapsing whitespace (catches copies that differ only in form);
  ngram       a test example shares at least one N-word sequence (default 13,
              as lm-evaluation-harness decontamination does) with any training
              example (catches partial copies and templated duplicates).

Usage:
  leakage.py --train TRAIN --test TEST [--field text]... [--ngram 13] [--show 5]

Files: .jsonl / .json (a list of objects; --field names the text fields,
default "text"; several --field values are joined), .csv / .tsv (--field is
the column), .txt (one example per line).

Output: one JSON object on stdout. Exit 0 when clean, 1 when any test example
leaks, 2 on bad input. Memory grows with the number of distinct training
n-grams; for very large training sets, run it on a sample and say so.
"""
import argparse, csv, json, re, sys, unicodedata

PUNCT = re.compile(r"[^\w\s]", re.UNICODE)
SPACE = re.compile(r"\s+", re.UNICODE)


def normalize(text):
    text = unicodedata.normalize("NFKC", text).lower()
    return SPACE.sub(" ", PUNCT.sub(" ", text)).strip()


def load(path, fields):
    def pick(obj):
        parts = []
        for f in fields:
            if f not in obj:
                raise ValueError(f"{path}: field '{f}' missing in an example; available: {sorted(obj)}")
            parts.append(str(obj[f]))
        return "\n".join(parts)

    low = path.lower()
    with open(path, encoding="utf-8", newline="") as fh:
        if low.endswith(".jsonl"):
            return [pick(json.loads(line)) for line in fh if line.strip()]
        if low.endswith(".json"):
            data = json.load(fh)
            if not isinstance(data, list):
                raise ValueError(f"{path}: expected a JSON list of objects")
            return [pick(o) for o in data]
        if low.endswith(".csv") or low.endswith(".tsv"):
            reader = csv.DictReader(fh, delimiter="\t" if low.endswith(".tsv") else ",")
            return [pick(row) for row in reader]
        if low.endswith(".txt"):
            return [line.rstrip("\n") for line in fh if line.strip()]
    raise ValueError(f"{path}: unsupported extension (use .jsonl, .json, .csv, .tsv or .txt)")


def ngrams(tokens, n):
    return {" ".join(tokens[i:i + n]) for i in range(len(tokens) - n + 1)}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--train", required=True)
    ap.add_argument("--test", required=True)
    ap.add_argument("--field", action="append", default=None)
    ap.add_argument("--ngram", type=int, default=13)
    ap.add_argument("--show", type=int, default=5)
    a = ap.parse_args()
    if a.ngram < 1:
        print("ERROR: --ngram must be >= 1", file=sys.stderr); return 2
    fields = a.field or ["text"]
    try:
        train, test = load(a.train, fields), load(a.test, fields)
    except (OSError, ValueError, json.JSONDecodeError) as e:
        print(f"ERROR: {e}", file=sys.stderr); return 2
    if not train or not test:
        print("ERROR: an empty set cannot be checked", file=sys.stderr); return 2

    exact_train = set(train)
    norm_train = {normalize(t) for t in train}
    gram_train = set()
    for t in train:
        gram_train |= ngrams(normalize(t).split(), a.ngram)

    exact, norm, gram, short = [], [], [], 0
    for i, t in enumerate(test):
        n = normalize(t)
        if t in exact_train:
            exact.append(i)
        elif n in norm_train:
            norm.append(i)
        else:
            toks = n.split()
            if len(toks) < a.ngram:
                short += 1
            elif ngrams(toks, a.ngram) & gram_train:
                gram.append(i)

    leaked = exact + norm + gram
    out = {
        "train_examples": len(train),
        "test_examples": len(test),
        "ngram": a.ngram,
        "exact": len(exact),
        "normalized": len(norm),
        "ngram_overlap": len(gram),
        "leaked": len(leaked),
        "leaked_fraction": round(len(leaked) / len(test), 4),
        "too_short_for_ngram": short,
        "examples": [{"test_index": i, "kind": k, "text": test[i][:160]}
                     for k, ids in (("exact", exact), ("normalized", norm), ("ngram", gram))
                     for i in ids][: a.show],
    }
    print(json.dumps(out, ensure_ascii=False))
    return 1 if leaked else 0


if __name__ == "__main__":
    sys.exit(main())
