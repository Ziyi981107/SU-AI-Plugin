# V14-RUNTIME-BLOCK-004 Fix Packet

Date: 2026-08-24
Scope: narrow real-SketchUp-2020 logging/recovery path only
Commit: `875333d`

## Symptom

On the final V1.4 RBZ, clicking Prepare in SketchUp 2020 raised
`NoMethodError: private method 'puts' called for #<Sketchup::Console>`
from `dialog_runner.rb`'s rescue logger. The logger masked the original
Prepare exception and prevented the toast/UI refresh path from completing.

## Fix

- `dialog_runner.rb`: replace explicit `$stderr.puts` / `$stdout.puts`
  in affected production paths with defensive `_safe_log` using bare
  `warn`; logging failures are swallowed.
- `_safe_invoke` preserves the original exception for the toast, isolates
  toast failure, and always attempts `push_data`.
- `main.rb` boot rescue uses the same safe logging rule.
- Added `tests/test_v14_runtime_block_004.rb` covering private-console
  behavior, original-error preservation, unconditional UI refresh, toast
  isolation, and the locate path.

## Verification

- V14-RUNTIME-BLOCK-004 targeted: **9/9 PASS**
- Full Ruby suite: **655/655 PASS**, 0 fail, 0 error
- Node DOM: **148/148 PASS**
- RBZ smoke: **8/8 PASS**
- `git diff --check`: clean
- RBZ: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- RBZ size: 442,832 bytes; entries: 53
- SHA256: `c8288a2c2b499291fc9a03a75b90f96f4184a057df41a833a5d410f625418db0`

## Remaining gate

This packet is ready for CodeX narrow BLOCK recheck. Do not enter V1.5,
publish, release, or treat the V1.4 Stage Review as complete until the
new RBZ is installed and the real SU2020 V14-9 narrow test passes:
Prepare success, mid-build failure cleanup, Discard/Retry, one Ctrl+Z
whole-Prepare undo, and source unchanged.
