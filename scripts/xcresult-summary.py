"""Prints one summary line (plus failures) from `xcresulttool get test-results summary` JSON on stdin."""
import json
import sys

d = json.load(sys.stdin)
print("%s: %s passed, %s failed, %s skipped" % (d["result"], d["passedTests"], d["failedTests"], d["skippedTests"]))
for failure in d.get("testFailures", []):
    text = (failure.get("failureText") or "").splitlines()
    print("    %s: %s" % (failure.get("testName", ""), text[0] if text else ""))
