#!/usr/bin/env python3
"""Validate php-prebuild-quality skill structure and wiring."""

from __future__ import annotations

import pathlib
import re
import sys


def fail(message: str) -> None:
    print(f"[FAIL] {message}")
    raise SystemExit(1)


def ok(message: str) -> None:
    print(f"[OK] {message}")


skill_root = pathlib.Path(__file__).resolve().parent.parent
script_path = skill_root / "scripts" / "run_prebuild_quality.sh"
profile_path = skill_root / "references" / "phpstorm-profile.xml"
parser_path = skill_root / "scripts" / "count_phpstorm_issues.php"

for required in (script_path, profile_path, parser_path):
    if not required.exists():
        fail(f"Missing required file: {required}")
    ok(f"Found: {required}")

script_text = script_path.read_text(encoding="utf-8")
required_snippets = [
    "--ide-inspect",
    "--ide-profile",
    "--ide-bin",
    "--final-validation",
    "Stage: phpstorm_inspect",
    "count_phpstorm_issues.php",
]
for snippet in required_snippets:
    if snippet not in script_text:
        fail(f"Runner missing snippet: {snippet}")
    ok(f"Runner contains: {snippet}")

profile_text = profile_path.read_text(encoding="utf-8")
required_inspections = [
    "PhpUnhandledExceptionInspection",
    "PhpDocMissingThrowsInspection",
    "PhpPossiblePolymorphicInvocationInspection",
    "PhpRedundantCastingInspection",
]
for inspection in required_inspections:
    if inspection not in profile_text:
        fail(f"Profile missing inspection: {inspection}")
    ok(f"Profile contains: {inspection}")

if not re.search(r"IDE_INSPECT=\"on\"", script_text):
    fail("Runner default for IDE_INSPECT is not on")
ok("Runner default IDE_INSPECT is on")

if not re.search(r"FINAL_VALIDATION=\"off\"", script_text):
    fail("Runner default for FINAL_VALIDATION is not off")
ok("Runner default FINAL_VALIDATION is off")

parser_text = parser_path.read_text(encoding="utf-8")
if "$PROJECT_DIR$" not in parser_text:
    fail("PhpStorm parser is missing $PROJECT_DIR$ path normalization support")
ok("PhpStorm parser supports $PROJECT_DIR$ path normalization")

if "PhpCastIsUnnecessaryInspection" not in parser_text:
    fail("PhpStorm parser is missing cast-inspection alias support")
ok("PhpStorm parser supports cast-inspection alias")

print("[OK] Skill quick validation passed.")
