# CODEX xHigh — V1.9B1 Blueprint v1.2 PRE-BUILD RECHECK

REVIEW ONLY. Do not modify code/files/commits.

Review:
`Prompt/AIPM_V1_9B1_SOURCE_CONTRACT_MAPPING_BLUEPRINT_V1_2_2026-09-11.md`

Previous real Codex xHigh v1.1 recheck returned FIX REQUIRED with:
- B1-ID-03
- B1-ID-02-R1
- B1-COHERENCE-01-R1
- B1-STATE-01-R1

Check against current `dev/v1.9` production source.

## A. B1-ID-03 — semantic geometry/structure IDs

Confirm Blueprint v1.2:
- does not copy derived_edge_id, endpoint_key, canonical_node_id, canonical_edge_id, chain_id, loop_id, region_id or legacy repair IDs into semantic identity;
- requires topology_snapshot endpoints so semantic node coordinates are based on current endpoint-member coordinates;
- chooses semantic node coordinate independent from endpoint-key ordering;
- defines deterministic node-label refinement without legacy tie-break;
- fails closed on unresolved semantic node ambiguity;
- defines semantic edge IDs and fails closed on duplicate semantic-edge ambiguity;
- rebuilds adjacency from semantic edges;
- canonically remaps chain direction;
- canonically remaps all loop rotations + reverse orientation;
- remaps regions from semantic loop IDs;
- prevents raw ID-bearing structure diagnostic strings from entering semantic content;
- stays implementable entirely in new pure B1 modules.

Look for hidden identity dependence on traversal order, source edge order, gap proposal ID, derived ID, transient occurrence ID, or legacy canonical IDs.

## B. B1-ID-02-R1 — source identity + canonical encoding

Confirm:
- semantic source identity is rebuilt from per-edge/per-face/per-layer SourceSnapshot records;
- edge_length_sum and other order-sensitive float aggregates are not semantic identity;
- source edge orientation + collection ordering are canonical;
- Float is a disjoint type in identity bytes, not a tag-shaped user Hash;
- -0.0 normalization is defined;
- raw UTF-8 length-prefixed String encoding removes JSON control-escape ambiguity;
- invalid UTF-8 fails closed;
- fixed tolerance key schema accepts production Symbol or String keys;
- session_overrides have explicit recursive normalization, collision handling and type allowlist;
- Ruby 2.2 can implement the byte format.

Check the proposed byte grammar for any collision or parsing ambiguity.

## C. B1-COHERENCE-01-R1

Confirm:
- SourceSnapshot and AnalysisResult.geometry_snapshot use the exact same coherence projection schema;
- edge/face/layer field sets are precise;
- set-like collections are order independent;
- current-session entity_id is coherence evidence only and never semantic identity;
- registry edge IDs are used only to locate Analysis EdgeRecords;
- unknown/duplicate/missing registry edge IDs fail closed;
- resolved registry edge descriptor must exist in SourceSnapshot coherence multiset;
- raw analysis-local edge IDs never enter content;
- cross-input graph/structure/source/workspace/schema checks remain feasible.

Also review the new REQUIRED `topology_snapshot` input:
- whether current production can later provide it in B1.5 through a narrow coherent read-only bundle;
- whether B1.2–B1.4 can test it without modifying frozen modules.

## D. B1-STATE-01-R1 duplicate validation

Confirm:
- duplicate action rows have strict applied/skipped/failed allowlist;
- row counts are recomputed and must equal summary counts;
- malformed/raw-only rows fail closed;
- last_action_status consistency rules match actual Runner behavior, including the legitimate skip-only case where appended pre-execution skipped rows may coexist with `last_action_status=none`;
- no unknown status can disappear from counts and allow READY.

## E. New-block scan

Look especially for:
- topology member-coordinate representative still identity-unstable;
- symmetric graph ambiguity policy insufficient;
- structure remap edge/node alignment bugs;
- stable source PID assumptions incompatible with current SourceReference;
- source semantic projection omitting facts that the V2 handoff contract actually requires;
- candidate/final digest circularity;
- impossible Ruby 2.2 byte encoding;
- any hidden need to edit frozen V1 modules.

Required output:

VERDICT: PASS | FIX REQUIRED

## BLOCKS
## NON-BLOCKING FINDINGS
## SEMANTIC ID / REMAP
## SOURCE IDENTITY / CANONICAL BYTES
## INPUT COHERENCE
## DUPLICATE READINESS
## NEW-BLOCK SCAN
## RUBY 2.2
## SAFE TO DISPATCH B1.2-B1.4: YES | NO

Review only. Do not implement.
