#!/usr/bin/env python3
"""Give every key of Xcode string catalogs (Localizable.xcstrings) an entry for a language (T15.1).

Usage: scripts/xcstrings-add-language.py <language> <path>...
A key without an entry for <language> gets a copy of its `en` entry (its plural variations and substitutions
included) with every `state` set to `new`, so Xcode lists it as untranslated and the English text stands in until it
is translated. A key with no `en` entry (its key is its English text) gets `{"stringUnit": {"state": "new", "value":
<key>}}`. An existing entry is never changed, and a key marked `"shouldTranslate": false` is skipped. Keys keep their
order; the file is written as Xcode writes it (`" : "` separators, two-space indent, an empty object over two lines).
Prints each file it changed, with how many entries it added.
"""
import copy
import json
import re
import sys


def marked_new(value):
    """A deep copy of a localization in which every `state` is `new`."""
    result = copy.deepcopy(value)

    def walk(node):
        if isinstance(node, dict):
            if "state" in node:
                node["state"] = "new"
            for child in node.values():
                walk(child)

    walk(result)
    return result


def xcode_json(catalog):
    text = json.dumps(catalog, indent=2, ensure_ascii=False, separators=(",", " : "))
    # Xcode writes an empty object as `{` and `}` with a blank line between them.
    text = re.sub(r"^( *)(.*) : \{\}(,?)$", lambda m: f"{m[1]}{m[2]} : {{\n\n{m[1]}}}{m[3]}", text, flags=re.M)
    return text + "\n"


def main():
    language, *paths = sys.argv[1:]
    for path in paths:
        with open(path) as f:
            catalog = json.load(f)
        added = 0
        for key, entry in catalog.get("strings", {}).items():
            if entry.get("shouldTranslate") is False:
                continue
            localizations = entry.get("localizations", {})
            if language in localizations:
                continue
            source = localizations.get("en") or {"stringUnit": {"state": "new", "value": key}}
            localizations[language] = marked_new(source)
            entry["localizations"] = dict(sorted(localizations.items()))
            entry_keys = sorted(entry)
            reordered = {k: entry[k] for k in entry_keys}
            entry.clear()
            entry.update(reordered)
            added += 1
        if added:
            with open(path, "w") as f:
                f.write(xcode_json(catalog))
            print(f"{path}: {added} {language} entries added")


if __name__ == "__main__":
    main()
