# Validation Experiments Specification

> [!NOTE]
> Every critical assumption must have a cheap, falsifiable validation experiment designed before committing code or engineering resources.

## Experiment Registry

| Experiment ID | Linked Findings | Falsifiable Hypothesis | Test Method / Channel | Success Threshold | Failure / Kill Threshold | Time & Budget Cap |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `EXP-001` | `FND-001`, `FND-004` | [If we offer X to segment Y, then Z% will commit to W] | [Landing page smoke test \| Cold outreach \| Paid pilot \| Prototype demo] | [e.g. >= 15% conversion, >= 3 LOIs] | [e.g. < 5% conversion after 100 visits] | [e.g. 7 days, $150 budget] |

---

## Detailed Experiment Protocols

### EXP-001: [Experiment Title]
- **Target Customer Segment**: [Specific persona and buyer]
- **Linked Findings & Hypotheses**: Cites `FND-NNN`
- **Falsifiable Hypothesis**:
  - *If*: [We present solution X to target segment Y via channel Z]
  - *Then*: [A specific observable action indicating genuine commitment occurs]
  - *Because*: [Underlying driver / value proposition]
- **Validation Method**:
  - [ ] Customer discovery interviews (structured, non-leading)
  - [ ] Smoke-test landing page with clear pricing & call-to-action
  - [ ] Interactive clickable prototype walkthrough
  - [ ] Letter of Intent (LOI) / Pre-order deposit request
  - [ ] Concierge / Wizard of Oz manual delivery pilot
- **Execution Channel**: [e.g. Targeted LinkedIn outbound to 50 engineering leads; Reddit community post]
- **Measurable Metrics**:
  - Primary metric: [e.g. Paid deposits, signed LOIs, calendar bookings]
  - Secondary metric: [e.g. Reply rate, time spent on pricing section]
- **Thresholds**:
  - **Success Threshold**: [e.g. At least 5 signed LOIs or 10 scheduled demo calls out of 50 targeted prospects]
  - **Failure / Kill Threshold**: [e.g. Fewer than 2 responses or zero willingness to sign LOI at the proposed price point]
- **Guardrails**:
  - **Time Cap**: [e.g. 10 business days]
  - **Budget Cap**: [e.g. $200 USD]
- **Stop Decision**:
  - If Success -> Advance to Intent / Product Brief (`/new-intent` or `/project-brief`)
  - If Inconclusive -> Refine positioning or tighten customer segment
  - If Failure -> Reposition, pivot, or trigger the kill condition
