#!/usr/bin/env python3
"""bands-validate.py - offline structural check for config/bands.json.

Run at setup time (and in tests) to catch a broken map before anything routes
through it - it inspects EVERY cell, not just one resolved path. Per the
gpt-6-astra review it rejects duplicate JSON keys (which json/jq would silently
last-wins), an unknown schema version, a stance override for a band that does
not exist under balanced, and any cell missing a non-empty string model.

Usage: bands-validate.py <bands.json>
Exit: 0 ok | 2 usage | 3 invalid (reason on stderr).
"""
import json
import sys

SCHEMA = 1


def no_dupes(pairs):
    seen = {}
    for k, v in pairs:
        if k in seen:
            raise ValueError("duplicate key %r" % k)
        seen[k] = v
    return seen


def fail(msg):
    sys.stderr.write("BANDS INVALID: %s\n" % msg)
    sys.exit(3)


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: bands-validate.py <bands.json>\n")
        sys.exit(2)
    try:
        with open(sys.argv[1]) as fh:
            doc = json.load(fh, object_pairs_hook=no_dupes)
    except (OSError, ValueError) as e:
        fail(str(e))

    if doc.get("schema_version") != SCHEMA:
        fail("schema_version must be %d, got %r" % (SCHEMA, doc.get("schema_version")))

    routes = doc.get("routes")
    if not isinstance(routes, dict):
        fail("routes must be an object")
    balanced = routes.get("balanced")
    if not isinstance(balanced, dict) or not balanced:
        fail("routes.balanced must be a non-empty object (the canonical band set)")

    for stance, backends in routes.items():
        if not isinstance(backends, dict):
            fail("routes.%s must be an object" % stance)
        for backend, bands in backends.items():
            if not isinstance(bands, dict):
                fail("routes.%s.%s must be an object" % (stance, backend))
            for band, cell in bands.items():
                where = "%s/%s/%s" % (stance, backend, band)
                if not isinstance(cell, dict):
                    fail("cell %s is not an object" % where)
                model = cell.get("model")
                if not isinstance(model, str) or not model:
                    fail("cell %s has no non-empty string 'model'" % where)
                if "effort" in cell and not isinstance(cell["effort"], str):
                    fail("cell %s effort must be a string" % where)
                # A stance override may only refine a band that exists in the
                # canonical (balanced) set for that backend.
                if stance != "balanced":
                    bal_backend = balanced.get(backend, {})
                    if band not in bal_backend:
                        fail("cell %s overrides a band absent from balanced.%s" % (where, backend))

    sys.exit(0)


if __name__ == "__main__":
    main()
