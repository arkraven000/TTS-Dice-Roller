#!/usr/bin/env python3
"""Run the BattleTech Dice Mat Lua tests against a mock TTS API.

Uses lupa's bundled Lua 5.2 (closest to TTS's MoonSharp). Each test runs in a
fresh Lua runtime: mock_tts.lua -> src/battletech_dice_mat.lua -> tests.

    pip install lupa
    python3 tests/run_tests.py [test_name ...]
"""
import json
import pathlib
import sys

import lupa.lua52 as lua52

ROOT = pathlib.Path(__file__).resolve().parent.parent
MOCK = (ROOT / "tests" / "mock_tts.lua").read_text()
SCRIPT = (ROOT / "src" / "battletech_dice_mat.lua").read_text()
TESTS = (ROOT / "tests" / "test_dice_mat.lua").read_text()


def make_runtime():
    lua = lua52.LuaRuntime(unpack_returned_tuples=True)

    def to_py(obj):
        if lua52.lua_type(obj) == "table":
            keys = list(obj.keys())
            if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
                return [to_py(obj[k]) for k in sorted(keys)]
            if not keys:
                return []
            return {str(k): to_py(obj[k]) for k in keys}
        if lua52.lua_type(obj) is not None:
            raise TypeError("cannot JSON-encode Lua %s" % lua52.lua_type(obj))
        return obj

    def encode(t):
        return json.dumps(to_py(t))

    def decode(s):
        return lua.table_from(json.loads(s), recursive=True)

    lua.execute(MOCK)
    lua.globals().JSON = lua.table_from({"encode": encode, "decode": decode})
    lua.execute(SCRIPT, "=battletech_dice_mat.lua")
    lua.execute(TESTS, "=test_dice_mat.lua")
    return lua


def main(argv):
    names = sorted(make_runtime().globals().TESTS.keys())
    if argv:
        names = [n for n in names if n in argv]
    failed = 0
    for name in names:
        lua = make_runtime()
        try:
            lua.globals().TESTS[name]()
            print("PASS", name)
        except Exception as exc:  # LuaError carries the Lua traceback message
            failed += 1
            print("FAIL", name, "\n    ", str(exc).replace("\n", "\n     "))
    dist = ROOT / "dist" / "BattleTech Dice Mat.json"
    if not argv and dist.exists():
        embedded = json.loads(dist.read_text())["ObjectStates"][0]["LuaScript"]
        if embedded != SCRIPT:
            failed += 1
            print("FAIL dist_is_current \n     dist JSON is stale: run tools/build_saved_object.py")
        else:
            print("PASS dist_is_current")
        names = names + ["dist_is_current"]
    print("\n%d passed, %d failed" % (len(names) - failed, failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
