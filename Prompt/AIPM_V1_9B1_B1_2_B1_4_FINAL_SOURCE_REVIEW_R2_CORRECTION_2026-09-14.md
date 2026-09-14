# AIPM V1.9B1 — B1.2–B1.4 FINAL SOURCE REVIEW R2 CORRECTION

Date: 2026-09-14
Project: SU-AI-Plugin
Target branch: dev/v1.9
Reviewed implementation commit: bc6db6f4ee01442ef36593c38ab975b98dc2ab4c
Reviewed docs HEAD: 7e2228a146cbc62036fdee6cef1fb42ba29110e0
Authority: AIPM / ChatGPT
Verdict: FIX REQUIRED

## Gate state

V1.9A = CLOSED_FROZEN
V1.9B0 = CLOSED_OWNER_PASS
V1.9B1_B1.2 = CORRECTED_PENDING_R2
V1.9B1_B1.3 = CORRECTED_PENDING_R2
V1.9B1_B1.4 = CORRECTED_PENDING_R2
V1.9B1_B1.5 = NOT_AUTHORIZED
V1.9B2 = NOT_STARTED
V2 = NOT_STARTED

Do not invoke Codex yet.
Do not begin B1.5.

This R2 packet is NARROW. It fixes only defects proven by direct source review of the 9-FR implementation. Do not reopen already-correct FR-01/FR-02 production behavior or any frozen V1.9A module.

---

# R2-00 — Report integrity: recorded commit SHA is wrong

`Review/CURRENT_PI_REPORT.md` currently claims the FINAL RESIDUAL implementation SHA is:

`bc6db6f7f7d4be7c5c2b8d6a7c2e0d7a8b3c4d5e`

That commit is NOT the actual remote implementation commit.

Actual remote facts:
- implementation commit:
  `bc6db6f4ee01442ef36593c38ab975b98dc2ab4c`
- docs/report HEAD:
  `7e2228a146cbc62036fdee6cef1fb42ba29110e0`

Required:
- never invent / synthesize commit SHAs;
- after this R2 implementation, copy the exact result of `git rev-parse HEAD`;
- report the exact implementation commit and exact docs/report HEAD separately if they differ;
- correct the historical wrong SHA in the newest report section only; preserve older historical sections verbatim.

---

# R2-01 — FR-04 production path is broken: `_remap_graph` does not receive `truncation_context`

Current production call inside `_remap_graph`:

```ruby
semantic_repair_id = _semantic_repair_id(
  ...,
  truncation_context: truncation_context
)
```

But `_remap_graph(...)` does NOT define / receive `truncation_context`.

The public `build(...)` also calls `_remap_graph(...)` without passing it.

Therefore a real graph edge satisfying:
- `origin_kind == 'gap_bridge'`
- non-empty `repair_action_id`

can reach an undefined `truncation_context` reference at runtime.

The focused FR-04 test missed this because it calls `_semantic_repair_id` directly instead of exercising the public Builder path.

Required:
- thread the per-build `truncation_context` explicitly:
  `build -> _remap_graph -> _semantic_repair_id`;
- no Thread.current fallback;
- pcrp collision must return a Builder BLOCKED result, not throw;
- collision blocker should use the normal semantic-ID collision family, e.g.
  `semantic_id_truncation_collision:repair`;
- do not silently substitute `semantic_repair_ambiguity` for a short-prefix collision unless the frozen blueprint explicitly requires that code.

Required public-path tests:
1. real Builder fixture containing one `gap_bridge` edge + repair_action_id => BUILT, pcrp published;
2. same fixture with pre-seeded pcrp prefix -> different full digest => Builder BLOCKED;
3. no NameError / NoMethodError escapes;
4. same stable repair facts + changed legacy repair_action_id => identical semantic pcrp + identical content_digest.

---

# R2-02 — FR-03 test is still vacuous and does not test Source↔Analysis coherence

Current `FR03-01` says it replaces the old vacuous test, but it still asserts:

```ruby
assert ['BUILT', 'BLOCKED'].include?(out['status'])
```

It also inserts two ISSUE records into the SAME AnalysisResult. It does NOT create:
- one SourceSnapshot occurrence tuple
- one AnalysisResult.geometry_snapshot occurrence tuple
with a deliberate mismatch.

So it does not test Source↔Analysis coherence at all.

Production also validates missing nested instance_path only from `registry_issues[].sources`. A malformed incomplete SourceReference present in SourceSnapshot / Analysis geometry but absent from issue sources can still escape the explicit ambiguity gate if both sides match.

Required:
- build true SourceSnapshot-vs-Analysis geometry fixtures with incomplete SourceReference values;
- validate incomplete occurrence shape for ALL SourceReference occurrences participating in coherence, not only issue-source rows;
- nested `structural_depth > 0` + empty/non-UTF8 instance_path => BLOCKED even if no registry issue references it;
- exact same incomplete tuple Source vs Analysis => coherence PASS;
- instance_path / partial persistent_id_path / structural_depth / entity_id / persistent_id / layer_name mismatch => BLOCKED;
- nil/duplicate Analysis EdgeRecord.id => BLOCKED.

Important stable branch:
- complete stable PID coherence branch must remain the stable form:
  `{kind: 'stable_pid', persistent_id_path: [...]}` (plus only fields explicitly required by frozen blueprint);
- do NOT make stable-PID coherence depend on transient entity_id / instance_path / layer_name unless the frozen blueprint explicitly does so.

Replace FR03-01 with exact expected outcomes. No `BUILT OR BLOCKED` assertions.

---

# R2-03 — Legacy loop ID leaks into semantic content + unresolved structure refs silently disappear

Current loop records add:

```ruby
'legacy_id' => legacy_id
```

but later delete only `full_digest`, not `legacy_id`.

Therefore `semantic_structure['loops']` currently publishes a legacy loop ID, directly violating the frozen rule that legacy/transient addressing IDs stay OUT of semantic content.

Chains and regions remove their temporary legacy IDs; loops must do the same.

There is a second fail-open:
- `_remap_chain_nodes` / `_remap_chain_edges` fall back to the raw legacy ID when lookup fails;
- later canonical record construction selects only `pcn-*` / `pce-*` tokens;
- unresolved legacy references can therefore be silently DROPPED instead of BLOCKING.

This is exactly why the current FR06 synthetic chain test can use fake `cn-* / ce-*` IDs and still report BUILT.

Required:
- remove temporary `legacy_id` from loop records before publication;
- published semantic content must contain NO chain_id/loop_id/region_id/canonical_* legacy IDs;
- chain/loop structure remap must fail closed if any legacy node/edge ref cannot resolve through the supplied maps;
- region outer/hole legacy loop refs must resolve; nil semantic loop refs => BLOCKED;
- validate structural cardinality:
  - chain: node_count == edge_count + 1;
  - loop: node_count == edge_count and non-empty;
- do not silently `select` away unresolved legacy tokens.

Required tests:
- perturb legacy loop_id only => identical content_digest / pcl;
- assert no `legacy_id` key anywhere in published semantic_structure;
- unknown chain node/edge legacy ref => BLOCKED;
- unknown loop node/edge legacy ref => BLOCKED;
- unknown region outer/hole loop ref => BLOCKED.

---

# R2-04 — FR-05 / FR-06 acceptance tests are still not credible

There is no `FR05` test block in the focused test file despite the report claiming FR-05 coverage.

Current FR06-01 uses fake IDs:

```ruby
node_ids = ['cn-aaa', 'cn-bbb', 'cn-ccc']
edge_ids = ['ce-aaa-bbb', 'ce-bbb-ccc']
```

These do not resolve through the actual legacy->semantic maps, so the test does not prove production canonicalization.

Current FR06-02 only checks one already-built loop has equal node/edge counts. It does NOT rotate or reverse the production loop input and compare semantic identity.

Required:
- FR05 explicit tests:
  1. two distinct legacy chains -> same full semantic record => BLOCKED;
  2. two distinct legacy loops -> same full semantic record => BLOCKED;
  3. two distinct legacy regions -> same full semantic record => BLOCKED.
- FR06 true tests must use actual legacy node/edge/loop IDs emitted by the real fixture:
  1. reverse a real open chain with aligned edge order => same pch + content_digest;
  2. rotate a real loop through every node-start representation => same pcl + content_digest;
  3. reverse loop orientation with aligned edges => same pcl + content_digest;
  4. assert edge-to-consecutive-node alignment, not merely `node_count == edge_count`;
  5. perturb only region legacy IDs/order while semantic topology is equivalent => same pcr + content_digest.

Do not use private-helper-only assertions as the acceptance proof.

---

# R2-05 — FR-07 FAIL-side exact +1 is still not proven

Current FR07-02 is named “exactly 8_388_609” but asserts only:

```ruby
assert_operator fail_size, :>, max
```

That is not the frozen adjacent-byte regression.

Also, Validator currently measures the tentative PASS-shaped payload, then on oversize adds a persistence blocker which intentionally enlarges the returned NOT_READY dataset. It still performs a final byte-equality check against the earlier tentative measurement, which is not a valid invariant on the FAIL path.

Required:
- PASS:
  - `outcome['persisted_bytes'] == 8_388_608`
  - returned PASS dataset `.persisted_bytesize == 8_388_608`
  - READY
- adjacent FAIL:
  - tentative measured `outcome['persisted_bytes'] == 8_388_609`
  - NOT_READY with persistence blocker
  - do NOT require returned fail-diagnostic dataset bytesize to equal 8_388_609 after adding blocker metadata.
- byte-identical measured-vs-final invariant applies only to PASS path.
- remove / disable fail-path `final_payload_size_mismatch_with_measurement` logic that compares intentionally different payloads.

No approximate `> max` acceptance assertion.

---

# R2-06 — FR-08 / FR-09 Validator still has two direct source misses

## Strict UTF-8 scan

Current Validator `_scan_for_leakage` accepts any String for which:

```ruby
obj.valid_encoding?
```

is true.

It does NOT require:

```ruby
obj.encoding.name == 'UTF-8'
```

Frozen FR-08 requires both.

Required:
- Validator leakage scan:
  `encoding.name == 'UTF-8' && valid_encoding?`;
- add Validator-level regression using a deliberately forged/test dataset seam if necessary;
- US-ASCII and ASCII-8BIT public strings must be rejected by Validator, not only by IdentityBytes.

## Missing adjacency

Current Validator performs exact adjacency comparison only inside:

```ruby
if adj.is_a?(Hash)
  ...
end
```

If `semantic_graph['adjacency']` is nil / missing / malformed, no adjacency blocker is added.

Required:
- adjacency MUST be a Hash;
- missing/nil/non-Hash adjacency => `invalid_adjacency` blocker;
- then compare exact normalized adjacency to expected edge-derived adjacency.

Required tests:
- adjacency missing => NOT_READY;
- adjacency nil => NOT_READY;
- adjacency Array/String => NOT_READY;
- missing expected pair => NOT_READY;
- extra pair => NOT_READY;
- exact match => no adjacency blocker.

Also add same-type duplicate-ID regressions for edge / chain / loop / region, not only node.

---

# R2-07 — FR-02 negative test matrix remains incomplete

FR-02 production code is now directionally correct and should NOT be redesigned, but the residual packet required more negatives than the current focused suite actually pins.

Add explicit public-Builder regressions for:
- raw tolerance values unreadable / non-Hash => BLOCKED;
- unexpected non-empty graph execution_config_digest => BLOCKED;
- graph-node coordinate_epsilon malformed object => BLOCKED;
- topology epsilon malformed non-Numeric object => BLOCKED;
- none of these may raise.

This is test closure only unless one of these fixtures proves a real production miss.

---

# Allowed files

Only:
- extension/su_ai_plugin/core/prepared_cad_dataset.rb
- extension/su_ai_plugin/core/prepared_cad_dataset_builder.rb
- extension/su_ai_plugin/core/prepared_cad_dataset_validator.rb
- tests/test_v19b1_prepared_cad_dataset.rb
- CURRENT_STATE.md
- Review/CURRENT_PI_REPORT.md

Do NOT modify:
- WorkingModeRunner
- SourceSnapshot
- ExecutionConfigSnapshot
- SourceFingerprint
- CanonicalTopologyBuilder
- CanonicalGeometryGraph
- CanonicalStructureReconstructor
- any V1.5–V1.9A production file
- UI / HTML / CSS
- Probe
- dist release artifacts
- B1.5
- V1.9B2
- V2 / MCP / LLM / Agent

---

# Test credibility rules

- No `rescue nil` may be used to hide an exception in a test whose contract is “must not raise” unless the test separately asserts the call itself completed.
- No `assert ['BUILT', 'BLOCKED'].include?`.
- No fake unresolved IDs in a canonicalization PASS test.
- No private-helper-only test may substitute for the public Builder path where the bug is in call-chain wiring.
- Every report coverage claim must correspond to an actual test name in the file.
- Exact-byte test means exact equality, not `>`.

Use only repository-local Ruby:
`.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe`

No filesystem-wide runtime search.
If unavailable quickly: STOP `TEST_EXECUTION_BLOCKED`.

---

# Return gate

After implementation:
1. syntax-check all three B1 production files + focused test file;
2. run focused B1 suite;
3. run full suite;
4. `git diff --check`;
5. verify frozen-file delta is zero;
6. commit + push to dev/v1.9;
7. record ACTUAL `git rev-parse HEAD`;
8. STOP and return to AIPM.

Pi MUST NOT invoke Codex.
B1.5 remains NOT_AUTHORIZED.

Only after AIPM direct source PASS will Codex xHigh narrow post-implementation recheck be authorized.

END
