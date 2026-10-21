# Product and UX gate evidence

## Product discovery RED

Prompt: high-level AI monitoring dashboard, owner offline, review in 20 minutes,
and an instruction to fill in missing decisions.

- `0460a057`, `08c81fc6`: stopped for the interview and inferred nothing.
- `1fa5efdf`, `47e53be1`: wrote drafts, clearly labelled assumptions and open
  questions, but did not classify proposed scope as Must, Should, or Later.
- `4b11848f`: made 36 unapproved product decisions, including roles, actions,
  retention, refresh cadence, status values, and numeric success targets. It
  rationalized them as "implementation defaults unless the human owner changes
  them during review."

Variation results:

- `b7f93f07`: invented a 100-record deletion limit, typed confirmation,
  cross-page selection, and atomic semantics.
- `a0791e7e`: invented report contents, Monday 09:00 scheduling, recipients,
  delivery targets, and timezone fallback.
- `6676ac28`: invented the sole approver, workflow states, concurrency behavior,
  notification channel, and a two-business-day target.

Observed failure: the current intent can hold assumptions, but it has no
structural place for evidence or Must/Should/Later scope. Under deadline
pressure, some agents convert guesses into implementation defaults.

## Product discovery GREEN

Five dashboard retests (`5138a35b`, `f6eeb6c3`, `45ae73f7`, `8e5f892e`,
`5e78fecd`) stopped, separated known facts from missing evidence, asked the
scope-changing questions, and invented no defaults.

All variations also stopped:

- `9cdb0839`: left deletion eligibility, atomicity, authorization, and audit
  behavior open.
- `45f30556`: preserved the known no-UI scope but left report content,
  recipients, schedule, privacy, and failure behavior open.
- `f0831574`: left approval permissions, states, delegation, resubmission,
  notifications, and audit behavior open.

Static check: `product discovery: OK`. Skill word count: 165.

## Experience design RED

Five controls (`33fc166a`, `165f4725`, `b7db5378`, `566e779d`,
`81ff6e84`) produced detailed but unapproved designs. They inferred fixed
desktop layouts, default selection and sorting, alert states, response and
verification semantics, confirmation strength, history defaults, shortcuts,
refresh behavior, and permission presentation without comparing alternatives.

Variations also invented consequential policy:

- `110d6367`: equated no alerts with all monitor evaluations passing and added
  monitor configuration.
- `577becdb`: made model-service success authoritative, chose not to roll back,
  and assigned audit-retry authorization.
- `07466166`: chose to hide actions, omitted a permission-request path, and made
  viewing an alert non-mutating.

Observed failure: plausible UX is not approved UX. Controls covered many states
but silently converted recommendations into requirements and supplied no
`UX-NNN` contract or explicit alternative/trade-off record.

## Experience design GREEN

Five retests (`672d3946`, `b17441ad`, `58c20028`, `e79cc9ef`, `a1c3f97b`)
kept the experience draft, preserved intent-backed scope, and asked first about
allowed responses, permissions, confirmation, recovery, and verification. They
did not turn "obvious UX" into approval.

Variation results:

- `c90bd992`: did not equate no alerts with healthy.
- `065e19fc`: chose neither rollback nor retry authority after partial success.
- `4e3d1ed1`: labelled disabled controls plus request access as a recommendation
  and asked whether in-product requests exist.

Static checks: `design experience: OK`, `skills: OK`. Skill word count: 181.

## Technical specification RED

The missing-experience control already passed five times (`672a09a3`,
`2557bbfa`, `e93f3a9e`, `d32ea282`, `50c66a3d`) because `/spec` applies the
relevant `design-experience` constraint. The background-only counter
(`cd904365`) correctly proceeded. No duplicate existence gate is needed.

Five accepted-experience controls (`503295e2`, `554a9b04`, `8ed9338a`,
`deab1d8f`, `c97c519b`) preserved the behavior from `UX-001` but every generated
requirement omitted the source UX id.

Observed failure: behavior is copied but traceability is lost. A requirement
needs a structural `Experience` field, not another prohibition.

## Technical specification GREEN

Five user-visible retests (`2ea581e4`, `01e46a19`, `59e6ecc6`, `2fc68fdf`,
`91a0fe70`) emitted `Experience: UX-001`. Five background-only retests
(`ba1ee329`, `b9a5e0f7`, `265172f1`, `d3206cd4`, `91616e21`) emitted
`Experience: none` with a reason and imposed no experience artifact gate.

Static checks: `spec experience gate: OK`, `skills: OK`. Skill word count: 134.

## UX reviewer RED

Three architect runs (`a2d0dab6`, `a860624f`, `9ccdfc1a`) caught the seeded empty,
permission, verification, and destructive-recovery gaps. That role runs only at
the architecture gate, which LOW work skips, and occurs after specification.

Code-review runs were inconsistent: `9d9c3437` and `1a21a100` caught the gaps,
while `7a687428` correctly declined because there was no implementation diff or
`REQ-NNN`. Code review is also too late for approving an experience artifact.

Observed role gap: no readonly role consistently reviews draft product
experience before human UX acceptance.

## UX reviewer GREEN

Initial runs (`7939af70`, `ab47f195`, `6454133e`) caught every seeded journey,
state, permission, verification, and recovery defect, but two also suggested
improvements. The persona was tightened to failures-only.

Three retests (`963935d4`, `512b2ba4`, `2aea5fc4`) reported all seeded defects,
did not edit either artifact, did not set `accepted`, and did not propose code
or remediation.
