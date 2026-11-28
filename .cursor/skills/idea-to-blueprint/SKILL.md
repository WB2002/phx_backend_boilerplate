---
name: idea-to-blueprint
description: Use when the user has a high-level product idea and needs it shaped into concrete low-level details (journey, screens, states, rules, copy, MVP) by choosing between recommended options at each step.
disable-model-invocation: true
---

# Idea to Blueprint

The user has many product ideas, clear at the high level and fuzzy at the low level. Your job is to walk an idea down from vision to buildable detail, and to make the product good enough to be a hit instead of unused.

## Interaction model: options with a recommendation, the user selects

The user should never have to invent details or answer open-ended questions. At every decision point:

1. Present 2–4 distinct, concrete options that are tailored to their product (not generic).
2. Put your recommended option first and mark it `(Recommended)`.
3. Give each option a one-line description of what choosing it leads to (the trade-off).
4. Add a short line explaining why you recommend your pick.
5. The user selects (or types their own answer), and you move on.

Use the interactive question tool (`AskUserQuestion` / `ask_question`) for this when it is available: up to 4 questions per call, but prefer 1–3 so each choice gets attention. Each question must stand alone and name the thing being decided. If the tool isn't available, present lettered options (`A`, `B`, `C`) in text with the recommendation first and ask the user to reply with a letter.

Only skip options and just state an assumption when there is no real choice or the cost of being wrong is trivial. Never ask a question you can answer yourself from what the user already said.

After every selection, add it to a running **Decisions log** (`decision`, `choice`, `reason`) and carry it forward. Show the log briefly at the end of each level so the user sees the product taking shape.

## Setup

- If the idea will live inside an existing product or system, get a short summary of it first (users, core flows, constraints) from attached files or the user, and confirm it in 3–4 lines.
- If it's a standalone product, ask (as a choice) which platform and stage.
- If the user brings several ideas, triage them in one line each (`user`, `problem`, `biggest risk`, `build / reshape / park`), then let them select which to take deep first.

## The zoom ladder (one level at a time)

Finish a level, summarize the decisions made, then go one level deeper. Never dump all levels at once. Make everything tangible by anchoring on a specific example person and moment ("Sara, a freelance designer, opens the app on Sunday night and wants X").

### Level 1: Vision
Draft the one-sentence version: `"[Specific user] can [do X] so that [outcome]."` Offer options for the sharpest target user, the main problem to solve, and the positioning against what people do today. Give a verdict: **Build / Reshape / Park**, and if **Reshape**, offer 2–3 sharper versions to choose from.

### Level 2: Core loop and promise
Options for: the one core action; the aha moment (aim for value within about 60 seconds); the return loop (habit, progress, new content, reminders, other people).

### Level 3: User journey
Walk the stages: `discover` → `onboard` → `first success` → `core use` → `payoff` → `return`. Where there is a real design choice (for example sign-up first vs. try first, guided setup vs. blank canvas), offer options. Remove every step that isn't essential to the first success.

### Level 4: Screens and states
Propose the list of screens. For each: its purpose, single primary action, contents, and states (`empty`, `loading`, `success`, `error`). Offer layout or structure options for the key screens. Offer to sketch the screens or draw the flow as a diagram.

### Level 5: Rules and data
Propose the main entities and key fields, the rules and logic (limits, defaults, permissions), and edge cases (no data, duplicates, failure, abuse, undo). Offer options where rules change the experience.

### Level 6: The details that make it a hit
Options for: smart defaults; first-run and onboarding approach; tone and key microcopy (show 2–3 sample wordings to pick from); notification and reminder style (when, how often, how to avoid annoying); a moment of delight or progress feedback; a distribution hook (sharing, invites, shareable outputs).

### Level 7: Build plan
Options for: MVP scope (in / out), what to fake or do manually first, build order, the validation method (prototype, fake door, manual pilot, small cohort), the activation metric, the retention metric, and kill criteria.

## Hit checklist (run before finishing)

- Does a new user get value in about a minute?
- Is there exactly one core action, and is it obvious?
- Is there a clear reason to come back?
- Is it meaningfully better than what people do today?
- Is the v1 small enough to ship and learn from quickly?

If any answer is no, raise it as a decision with options before writing the blueprint.

## Principles

- **Be opinionated**: always recommend, and say why.
- **Be honest**: if the idea is weak, say so and propose the sharper version.
- **Prefer the smaller, sharper product.**
- **Ground every option** in the user's actual product and example user.
- **Distinguish evidence from assumptions.**

## Output: Product Blueprint

When the levels are done, assemble a single blueprint containing:
1. Vision
2. Core loop
3. User journey
4. Screens and states
5. Rules and data
6. Hit details (including copy)
7. MVP and build order
8. Metrics and kill criteria
9. Full decisions log
10. Open questions

Offer to save it as a draft document the user can keep, share, or hand to a developer or designer (for example `docs/blueprints/<slug>.md` or `intent/<slug>/blueprint.md`). For multiple ideas, keep one blueprint per idea and a short ranked list of what to build first.

## SDLC Integration & Boundaries

- **Upstream of formal SDLC artifacts**: A Product Blueprint feeds directly into `/project-brief` (for a new standalone product) or `/new-intent` and `/design-experience` (for a feature inside an existing product). When market demand or pricing is unproven, recommend `/market-opportunity-research` before committing build effort.
- **Human gates remain authoritative**: Do not set `Status: accepted` on any artifact, do not bypass `/new-intent`, `/design-experience`, `/spec`, or `/plan`, and do not start writing application code directly from this skill.
