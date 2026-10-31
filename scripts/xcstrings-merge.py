#!/usr/bin/env python3
"""Three-way merge of Xcode string catalogs (Localizable.xcstrings), key by key.

Usage: scripts/xcstrings-merge.py <base-rev> <ours-rev> <theirs-rev> <path>...
Run it during a conflicted merge (e.g. base = `git merge-base HEAD MERGE_HEAD`, ours = HEAD,
theirs = MERGE_HEAD); it writes each path in place. A key changed on one side takes that side; a key
removed on one side and unchanged on the other is removed; a key changed on both keeps ours and is
reported. Keys are sorted case-insensitively, as Xcode writes them. Build once afterwards so Xcode
settles the file.
"""
import json
import subprocess
import sys


def load(rev, path):
    try:
        return json.loads(subprocess.check_output(["git", "show", f"{rev}:{path}"], stderr=subprocess.DEVNULL))
    except subprocess.CalledProcessError:
        return {"strings": {}}


def main():
    base_rev, ours_rev, theirs_rev, *paths = sys.argv[1:]
    for path in paths:
        b, o, t = load(base_rev, path), load(ours_rev, path), load(theirs_rev, path)
        bs, os_, ts = b.get("strings", {}), o.get("strings", {}), t.get("strings", {})
        out, both = {}, []
        for k in set(bs) | set(os_) | set(ts):
            if k in os_ and k in ts:
                if os_[k] == ts[k] or ts[k] == bs.get(k):
                    out[k] = os_[k]
                elif os_[k] == bs.get(k):
                    out[k] = ts[k]
                else:
                    out[k] = os_[k]
                    both.append(k)
            elif k in os_:
                if not (k in bs and os_[k] == bs[k]):
                    out[k] = os_[k]
            elif k in ts:
                if not (k in bs and ts[k] == bs[k]):
                    out[k] = ts[k]
        res = dict(o or t)
        res["strings"] = dict(sorted(out.items(), key=lambda kv: (kv[0].lower(), kv[0])))
        if "version" in o or "version" in t:
            res["version"] = max(o.get("version", "1.0"), t.get("version", "1.0"))
        with open(path, "w") as f:
            f.write(json.dumps(res, indent=2, ensure_ascii=False, separators=(",", " : ")) + "\n")
        print(f"{path}: {len(out)} keys" + (f"; changed on both sides, kept ours: {both}" if both else ""))


if __name__ == "__main__":
    main()
