---
name: market-opportunity-research
description: Use when evaluating a proposed software application, product idea, or major feature to assess market demand, competitor landscape, commercial viability, and differentiation before development
disable-model-invocation: true
---

# Market Opportunity Research

## Overview

Determine whether a proposed software application is worth building in a competitive market before committing design or engineering time.

**Core Principle:**
> **Never confuse an interesting hypothesis with a verified finding.** Every important factual claim must be traceable to a source, and every recommendation must explain its evidence and uncertainty.

---

## When to Use

- Evaluating a new software startup concept or product thesis.
- Deciding whether to build a new feature or spin up a dedicated product line.
- Assessing commercial viability, competitor defensibility, and willingness to pay.
- Preparing evidence before drafting a product brief (`/project-brief`) or new intent (`/new-intent`).

### When NOT to Use

- Writing detailed user stories or UI specifications (use `/design-experience` or `/spec`).
- Debugging or fixing production bugs (use `/fix-bug`).
- System architecture or infrastructure design (use `/architecture` or `/plan`).

---

## 1. Gather Research Inputs

Collect the concept context from the user or proposal document:

- **Problem & Intended Outcome**: What pain does the user experience, and what is the desired result?
- **Target Customer, Buyer & User**: Who feels the pain, who uses the tool, and who holds the budget?
- **Business Model & Geography**: Monetization structure (SaaS, usage-based, marketplace) and initial geographic market.
- **Industry & Regulatory Requirements**: Compliance regimes (e.g., GDPR, HIPAA, SOC 2, PCI-DSS, local data residency).
- **Known Competitors & Alternatives**: Direct products, indirect tools, open source, and manual spreadsheets.
- **Proposed Pricing**: Hypothesized price points or pricing metrics.
- **Founder Advantages & Constraints**: Domain expertise, distribution channels, runway, and time constraints.
- **Initial Differentiation Hypotheses**: Why the founder believes they can win.

> [!TIP]
> **Input Protocol**: Ask only essential clarifying questions (one or two at a time). If details are missing, state working assumptions explicitly, record them in the research report, and proceed.

---

## 2. Coordinate Eight Specialized Research Agents

The research is divided into 8 distinct analytical roles.

### Agent Roles & Scopes

1. **Market and customer problem** ([market-problem-analyst](../../agents/market-problem-analyst.md))
   - Analyzes customer segments, jobs-to-be-done (JTBD), pain point severity, frequency, and current manual workarounds.
   - Evaluates urgency, cost of status quo, and verifiable willingness to pay.
   - Separates anecdotal comments from representative industry patterns.

2. **Competitor landscape** ([competitor-analyst](../../agents/competitor-analyst.md))
   - Identifies direct competitors, indirect alternatives, open-source projects, and "doing nothing" (inertia).
   - Compares workflows, positioning, pricing, packaging, integrations, onboarding friction, and security claims.
   - Flags outdated, unverified, or marketing-only claims.

3. **Customer dissatisfaction and unmet needs** ([customer-dissatisfaction-analyst](../../agents/customer-dissatisfaction-analyst.md))
   - Researches public reviews (G2, Capterra, App Stores), forums (Reddit, Hacker News), issue trackers, and customer communities.
   - Extracts recurring frustrations, dates, and short verbatim quotes.
   - Verifies whether competitors have already addressed the gap. Never assumes a missing feature equals demand.

4. **Differentiation and positioning** ([positioning-strategist](../../agents/positioning-strategist.md))
   - Formulates up to 3 evidence-backed positioning options (niche focus, workflow speed, integration depth, cost, privacy/compliance, automation).
   - Identifies target buyer, unmet need, promised outcome, supporting evidence, feasibility, expected competitor counter-moves, and falsifiable assumptions.

5. **Business model and unit economics** ([unit-economics-analyst](../../agents/unit-economics-analyst.md))
   - Benchmarks competitor prices and buyer budget norms.
   - Models Cost of Goods Sold (COGS): hosting, AI/API tokens, data egress, customer support, and payment fees.
   - Produces transparent financial scenarios (Conservative, Base, Aggressive) with formulas, assumptions, and sensitivity ranges.
   - Never presents speculative TAM, CAC, or LTV as verified facts.

6. **Go-to-market** ([gtm-strategist](../../agents/gtm-strategist.md))
   - Investigates how target buyers discover and purchase solutions (search intent, ecosystems, communities, outbound).
   - Recommends a concrete, founder-executable path to the first 5–10 paying customers.
   - Proposes low-cost, measurable acquisition experiments with explicit pass/fail thresholds.

7. **Technical feasibility and defensibility** ([technical-defensibility-analyst](../../agents/technical-defensibility-analyst.md))
   - Evaluates critical APIs, integrations, data access rules, rate limits, licensing, latency budgets, and security/privacy boundaries.
   - Identifies major dependencies, build-vs-buy decisions, and technical assumptions requiring a proof of concept.
   - Distinguishes mandatory legal requirements from optional vendor claims. Explains structural defensibility beyond easily copied features.

8. **Independent red team** ([opportunity-red-team](../../agents/opportunity-red-team.md))
   - Attempts to disprove the opportunity.
   - Challenges demand authenticity, willingness to pay, unit economics, switching inertia, incumbent responses, and market size.
   - Identifies fatal counterarguments and defines explicit kill conditions under which the project should be terminated or repositioned.

### Sub-Agent Orchestration & Execution Modes

- **Multi-Agent Runtime (Parallel Execution)**:
  When running in an environment with native sub-agents, dispatch all 8 specialized agents in parallel workstreams with their dedicated prompts and scopes. Reconcile overlapping findings and resolve conflicts in the synthesis phase.
- **Single-Agent Runtime (Sequential Execution Fallback)**:
  When general sub-agent dispatch is unavailable, the orchestrator executes the 8 workstreams as distinct sequential phases. Maintain strict role isolation: do not allow findings from one phase to bias the objective data gathering of subsequent phases, and always execute the independent red team last without softening negative evidence.

---

## 3. Enforce Evidence Quality

### Material Finding Data Model

Every substantive assertion in the research must be logged in the evidence ledger with:

| Field | Description |
| :--- | :--- |
| **Finding ID** | Unique identifier (`FND-001`, `FND-002`, etc.) |
| **Claim** | Precise assertion of fact, customer feedback, or market condition |
| **Classification** | `verified fact` \| `customer-reported evidence` \| `inference` \| `estimate` \| `hypothesis` |
| **Source URLs & Dates** | Direct URLs with publication/update date and access date |
| **Customer Segment** | Specific customer persona or market segment affected |
| **Confidence Level** | `High` \| `Medium` \| `Low` with explicit justification |
| **Counterevidence** | Disagreeing sources, caveats, or alternative interpretations |
| **Business Implication** | Direct impact on MVP scope, pricing, positioning, or viability |
| **Recommended Validation Step** | Concrete action to reduce uncertainty or test the finding |

### Twelve Mandatory Research Rules

1. **Prefer Primary Sources**: Official product pages, live pricing matrices, technical documentation, regulatory standards, public financial filings, and direct customer forum posts.
2. **Secondary Analysis as Context Only**: Industry analyst summaries (Gartner, blog posts) are supporting context, never the sole evidence for consequential claims.
3. **Verify Claims Directly**: Confirm that linked sources explicitly support the claims attributed to them.
4. **Record Precise Dates**: Always log both source publication/update dates and your access date.
5. **Separate Marketing from Reality**: Do not treat vendor marketing copy or feature promises as verified operational capabilities.
6. **Track Contradictory Evidence**: Never omit or downplay findings that conflict with the founder's thesis.
7. **Count Distinct Sources**: Do not count syndicated reposts or citations of the same single blog post as multiple sources.
8. **Never Invent Information**: Strictly forbid fabricated URLs, statistics, survey results, user quotes, or purchase commitments.
9. **Never Fabricate Customer Validation**: Do not claim direct customer validation has occurred unless real interviews or signed LOIs exist.
10. **Respect Site Restrictions & Privacy**: Follow acceptable use policies and respect data privacy.
11. **Disclose Research Scope & Gaps**: Clearly state which areas were investigated, what evidence was unavailable, and which workstreams had limitations.
12. **Prioritize Decision-Altering Findings**: Focus analytical depth on the specific assumptions that could trigger a "do not build" or "reposition" decision.

### Research Tooling

Use the tools available in the environment:
- `search_web`: Discover industry data, competitors, discussions, and documentation.
- `read_url_content`: Inspect raw Markdown/text of pricing pages, terms of service, and public forums.
- `run_command`: Execute curl commands or query public APIs when applicable.
- `browser_subagent`: Inspect complex interactive web interfaces or app stores when static extraction is insufficient.

---

## 4. Transparent Opportunity Evaluation

Evaluate the opportunity across 10 balanced dimensions using a 1–5 scale (1 = Severe Risk / Non-viable, 5 = Exceptional Strength):

1. **Problem severity and frequency**: How painful, urgent, and frequent is the problem?
2. **Willingness-to-pay evidence**: Are buyers currently paying real money to solve this?
3. **Competitive intensity within target segment**: Is the target niche open or crowded?
4. **Differentiation strength**: Is the proposed advantage meaningful and defensible?
5. **Reachability of initial buyers**: Can the founder access the first 10 customers directly?
6. **Commercial economics**: Do unit economics support healthy gross margins (>70%)?
7. **Technical feasibility**: Can the solution be reliably delivered within constraints?
8. **Security and regulatory exposure**: Are compliance barriers manageable?
9. **Founder advantage**: Does the team possess unique domain, distribution, or technical edge?
10. **Defensibility and retention potential**: Can the product retain customers against fast-follows?

### The Critical Blocker Rule

> [!CRITICAL]
> **A high overall score CANNOT compensate for a critical blocker.**  
> If an insurmountable obstacle exists—such as zero verified willingness to pay, an unresolvable platform dependency, or a fatal regulatory barrier—the verdict MUST be `Do not build yet` or `Narrow or reposition`, regardless of high scores elsewhere.

Always explicitly state: **What new evidence would change the recommendation?**

---

## 5. Produce Decision-Ready Artifacts

Generate the complete research documentation in a dedicated research directory (e.g., `research/<slug>/` or `intent/<slug>/research/`):

1. **Research Report**: Follow [templates/research-report.md](templates/research-report.md) with all 17 standardized sections:
   - 1. Executive recommendation
   - 2. Research scope, assumptions, geography, and limitations
   - 3. Customer problem evidence and existing workarounds
   - 4. Competitor landscape and comparison matrix
   - 5. Pricing and packaging comparison
   - 6. Customer dissatisfaction patterns and potential unmet needs
   - 7. Opportunity shortlist
   - 8. Recommended positioning and differentiation
   - 9. Business model, pricing hypotheses, and unit economics
   - 10. Go-to-market strategy and route to first customers
   - 11. MVP scope and core user journey
   - 12. Technical feasibility and regulatory considerations
   - 13. Validation experiments with success and failure thresholds
   - 14. Red-team findings and reasons not to build
   - 15. Decision gates
   - 16. Evidence gaps and recommended next steps
   - 17. Deduplicated source register
2. **Evidence Ledger**: Follow [templates/evidence-ledger.md](templates/evidence-ledger.md) to record all `FND-NNN` entries.
3. **Validation Experiments**: Follow [templates/validation-experiments.md](templates/validation-experiments.md) to define cheap falsifiable test protocols.

---

## 6. Define the Next Action

Based on the research report verdict:

- **Weak Evidence / Unverified Demand**: Recommend the cheapest useful experiment (landing page test, cold outreach) to validate or disprove the core assumption.
- **Promising but Uncertain Demand**: Recommend 5–10 structured customer discovery interviews, a clickable prototype walkthrough, or a concierge pilot.
- **Credible Opportunity with Verified Demand**: Recommend drafting a product brief (`/project-brief`) and proceeding to formal intent discovery (`/new-intent`).
- **Do Not Build**: Document the kill conditions and preserve the research report as a documented decision record.
- **Strict Constraint**: Never automatically start software implementation or write application code directly from this skill.

---

## Rationalization Table & Red Flags

| Rationalization / Fallacy | Reality & Required Counter |
| :--- | :--- |
| *"Competitors charge $100/mo so we can easily charge $80/mo."* | Competitors have trust, integrations, brand, and support. An unbuilt product has zero pricing power without verified buyer validation. |
| *"Users on Reddit complained about X, so there is huge market demand."* | Online complaints are cheap. Demand requires willingness to pay or invest time switching. Classify as `customer-reported evidence`, not verified market demand. |
| *"The TAM is $20B, so capturing 0.1% gives us $20M in revenue."* | Top-down TAM is a pitch deck fantasy. Viability requires bottom-up unit economics, reachable buyer channels, and realistic conversion rates. |
| *"No competitor offers feature X, so it represents a massive opportunity."* | Feature X may be omitted because users refuse to pay for it, it causes high churn, or it is an architectural nightmare. Validate why it is missing. |
| *"We can build an MVP in a weekend and test in production."* | Building before validating burning customer pain wastes engineering resources. Run a zero-code or low-cost experiment first. |
| *"We don't need sources for obvious industry facts."* | If it is consequential to the build decision, it must be verified and cited in the evidence ledger. |

### Red Flags — STOP and Re-Evaluate

- Claiming customer validation without primary quotes, interview transcripts, or signed letters of intent.
- Assigning a favorable verdict while a critical blocker remains unresolved.
- Suppressing negative competitor reviews, incumbent strengths, or red-team objections.
- Projecting financial scenarios without exposing underlying cost-per-user assumptions.
