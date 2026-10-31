#!/usr/bin/env python3
"""Check a language's translations in Xcode string catalogs (Localizable.xcstrings), without Xcode (M15).

Usage: scripts/xcstrings-check-language.py <language> <path>...
For each key to translate (not `"shouldTranslate": false`), reports:
- untranslated: no <language> entry, or a string unit not in state `translated`, or with an empty value;
- plural: a `plural` variation without both `one` and `other`;
- format: a string unit whose format specifiers (`%@`, `%lld`, `%1$@`, `%#@name@`…) differ from the English text's
  at the same place (the `en` entry, else the key). Positions count: `%2$@ %1$@` matches `%@ %@` reordered. A plural
  `one` form may leave out the count (`une étape`), never add one.
Exits 1 when it reports anything. `--summary` prints only the counts per file.
The Swift check (`StringCatalogCoverage.untranslatedKeys(in:)`, T15.5) tests the same "translated" rule; the format
check is this script's only.
"""
import json
import re
import sys

SPECIFIER = re.compile(r"%(?:(\d+)\$)?(#@[A-Za-z0-9_]+@|[-+ #0']*\d*(?:\.\d+)?(?:ll|l|h|hh|q|z|t|j)?[@dDiuUxXoOfFeEgGaAcCsSp])|%%")


def specifiers(text):
    """{position: type} for the format specifiers of `text`; `%%` is skipped."""
    found, next_position = {}, 1
    for match in SPECIFIER.finditer(text):
        if match.group(0) == "%%":
            continue
        kind = match.group(2)
        if kind.startswith("#@"):
            kind = "substitution"
        else:
            kind = re.sub(r"^[-+ #0']*\d*(?:\.\d+)?", "", kind)
        if match.group(1):
            position = int(match.group(1))
        else:
            position = next_position
            next_position += 1
        found[position] = kind
    return found


def units(node, path=()):
    """Every string unit of a localization, with its path (`variations`, `plural`, `one`…)."""
    if isinstance(node, dict):
        if "stringUnit" in node:
            yield path, node["stringUnit"]
        for key, child in node.items():
            if key != "stringUnit":
                yield from units(child, path + (key,))


def english_at(english, path, key):
    """The English text for the string unit at `path`: the same place in `en`, else its `other` form, else the key."""
    node = english
    for part in path:
        if not isinstance(node, dict) or part not in node:
            node = None
            break
        node = node[part]
    if isinstance(node, dict) and "stringUnit" in node:
        return node["stringUnit"].get("value", key)
    if path and path[-1] in ("zero", "one", "two", "few", "many"):
        return english_at(english, path[:-1] + ("other",), key)
    if english.get("stringUnit") and not path:
        return english["stringUnit"].get("value", key)
    return key


def check(language, path):
    with open(path) as f:
        strings = json.load(f).get("strings", {})
    problems = []
    for key, entry in strings.items():
        if entry.get("shouldTranslate") is False:
            continue
        localizations = entry.get("localizations", {})
        target = localizations.get(language)
        if not target:
            problems.append(("untranslated", key, "no entry"))
            continue
        english = localizations.get("en", {})
        found = list(units(target))
        if not found:
            problems.append(("untranslated", key, "no string unit"))
        for unit_path, unit in found:
            where = "/".join(unit_path) or "stringUnit"
            value = unit.get("value", "")
            if unit.get("state") != "translated" or not value:
                problems.append(("untranslated", key, f"{where}: state {unit.get('state')!r}"))
                continue
            source = english_at(english, unit_path, key)
            # Inside a substitution, the English text uses %arg for the substituted value.
            expected, actual = specifiers(source.replace("%arg", "%@")), specifiers(value.replace("%arg", "%@"))
            if unit_path and unit_path[-1] in ("zero", "one", "two", "few", "many"):
                ok = all(expected.get(p) == t for p, t in actual.items())
            else:
                ok = expected == actual
            if not ok:
                problems.append(("format", key, f"{where}: {value!r} vs English {source!r}"))
        for plural_path, plural in walk_plurals(target):
            if "one" not in plural or "other" not in plural:
                problems.append(("plural", key, f"{'/'.join(plural_path)}: needs `one` and `other`"))
    return problems


def walk_plurals(node, path=()):
    if isinstance(node, dict):
        for key, child in node.items():
            if key == "plural" and isinstance(child, dict):
                yield path + (key,), child
            else:
                yield from walk_plurals(child, path + (key,))


def main():
    args = sys.argv[1:]
    summary = "--summary" in args
    args = [a for a in args if a != "--summary"]
    language, *paths = args
    failed = False
    for path in paths:
        problems = check(language, path)
        if not problems:
            print(f"✅ {path}")
            continue
        failed = True
        counts = {}
        for kind, _, _ in problems:
            counts[kind] = counts.get(kind, 0) + 1
        print(f"❌ {path}: " + ", ".join(f"{n} {kind}" for kind, n in sorted(counts.items())))
        if not summary:
            for kind, key, detail in problems:
                print(f"   {kind}: {key!r} — {detail}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
