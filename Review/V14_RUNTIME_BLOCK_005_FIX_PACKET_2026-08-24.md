# V14-RUNTIME-BLOCK-005 Fix Packet

Date: 2026-08-24
Scope: narrow real-SketchUp-2020 material-collection compatibility

## Symptom

After BLOCK-004 was fixed and the new RBZ was loaded, Prepare surfaced the
original error instead of masking it:

`NoMethodError: undefined method 'empty?' for #<Sketchup::Materials ...>`

The failure came from `core/source_fingerprint.rb` assuming
`host.materials` was an Array.

## Fix

Normalize `host.materials` through `to_a` when available, otherwise iterate
with plain `each` into an Array, and only then use Array operations. No
SketchUp constant or new host API was added to core.

Added a regression test using an enumerable collection that deliberately has
no `empty?`, `map`, or `each_with_object`, matching the relevant SU2020
surface.

## Verification

- SourceFingerprint targeted: **7/7 PASS**
- Full Ruby: **656/656 PASS**, 0 fail, 0 error
- Node DOM: **148/148 PASS**
- RBZ smoke: **8/8 PASS**
- RBZ: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- RBZ size: 443,553 bytes; entries: 53
- SHA256: `4708569bef45af7c66945a78da700cb61b73368be09ec12d0f8cb0010e669705`

## Next gate

Install this RBZ and rerun the real SU2020 V14-9 narrow flow. If Prepare
passes, continue with failure cleanup, Discard/Retry, whole-Prepare Ctrl+Z,
and source-unchanged checks. Do not enter V1.5 or release yet.
