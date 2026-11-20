---
name: frontend-ui-engineering
description: Use when building, styling, or modifying frontend UI components, screens, forms, modals, or client-side state to enforce design tokens, component modularity, all UX states, accessibility, and responsive polish.
---

# Frontend UI Engineering & Anti-Slop Design Craft

## Overview
Prevent generic, fragile "AI-slop" interfaces. Every user-visible change must honor the accepted `intent/<slug>/experience.md` (`UX-NNN`), use semantic design tokens, keep components modular, implement every required interaction state, and pass WCAG 2.1 AA accessibility and responsive checks.

## When to Use
- Creating or modifying frontend components, pages, layouts, forms, dialogs, tables, or client-side hooks/state.
- Styling UI elements or implementing animations/transitions.

## Mandatory Rules

### 1. Contract & UX State Completeness
- **Trace to Accepted Experience:** Before coding any visible change, read `intent/<slug>/experience.md`. Stop if `experience.md` is missing or not `accepted`, or if any `UX-NNN` state for the task is unresolved.
- **Implement All 7 Applicable Interaction States:** Never code only the happy path. Explicitly implement and verify every applicable state from `experience.md`:
  1. `Loading` (skeletons or non-layout-shifting spinners; preserve button dimensions)
  2. `Empty` (clear explanation + primary recovery/creation action)
  3. `Success` (deterministic confirmation and focus/scroll management)
  4. `Validation` (inline field-level feedback preserved with user input; never clear a form on validation error)
  5. `System error` (human-readable failure message + safe retry action; no raw stack traces or JSON dumps)
  6. `Partial failure` (graceful degradation when one panel or batch item fails)
  7. `Permission denied` (clear boundary explanation without leaking unauthorized data existence)

### 2. Design Tokens & Visual Integrity (Zero "AI Slop")
- **Semantic Tokens Over Magic Values:** Never scatter raw magic hex codes (`#3b82f6`), arbitrary pixel spacing (`margin: 13px`), or ad-hoc z-index wars (`z-index: 99999`) across components. Use the project's semantic design tokens / CSS variables (`bg-surface`, `text-primary`, `border-subtle`, spacing scale, elevation tokens).
- **Typography & Hierarchy:** Maintain a strict typographic scale, clear visual hierarchy (one primary CTA per view/card), consistent border radii, and intentional whitespace.
- **No Layout Shift (CLS = 0):** Reserve explicit dimensions or aspect ratios for images, async containers, banners, and dynamic actions.

### 3. Component Architecture & Framework Discipline
- **Modularity Limit (~200 Lines):** Keep components single-purpose and focused. When a component exceeds ~200 lines or mixes data orchestration with pure presentation, split container/hook logic from presentational subcomponents.
- **Composition Over Boolean-Prop Sprawl (Vercel Pattern):** Avoid components with 5+ boolean mode flags (`isCompact`, `isModal`, `isEditable`, `showHeader`, `hideFooter`). Use compound components, slots/children composition, or explicit variant unions.
- **Eliminate State & Effect Anti-Patterns:**
  - Never duplicate derived state into `useEffect` / watchers; compute derived values during render or via memoized selectors.
  - Clean up all timers, event listeners, `AbortController` fetches, and observers on unmount.
  - Prevent double-submit races on forms and mutation buttons by disabling or locking the trigger while in flight.
  - Never enforce authorization truth solely by hiding a button in the UI.

### 4. Accessibility (WCAG 2.1 AA) & Responsiveness
- **Semantic HTML First:** Use native `<button>`, `<a>`, `<nav>`, `<main>`, `<dialog>`, and `<label for="...">` elements before reaching for ARIA attributes. Never put `onClick` on a non-interactive `<div>` without role, `tabIndex`, and keyboard (`Enter`/`Space`) handlers.
- **Keyboard & Focus Management:** Ensure full keyboard navigation, visible `:focus-visible` rings, focus trapping inside modals/drawers, and focus restoration to the trigger element on close. Use `aria-live="polite"` / `role="alert"` for async status and error announcements.
- **Four-Breakpoint Responsive Verification:** Verify layout integrity and touch targets (>= 44x44px on mobile) across `320px`, `768px`, `1024px`, and `1440px` viewports with zero unintended horizontal overflow.

## Red Flags — STOP and Fix
- Coding a UI screen when `intent/<slug>/experience.md` is missing or still `Status: draft`
- A data view or form that renders only the `Success` state and crashes or goes blank on `Empty`, `Loading`, or `System error`
- Raw hex colors, inline magic pixel offsets, or `dangerouslySetInnerHTML` / `v-html` with unsanitized data
- `<div onClick={...}>` used in place of a semantic `<button>` or `<a>`
