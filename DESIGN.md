# Dead Rose OS design specification

This is the binding UI specification for the graphical shell and shared components.

## Direction

Dead Rose OS is a full-screen system interface, not a website or conventional desktop. It must feel calm, technical, precise, restrained, trustworthy, and intentionally built for infrastructure operation.

Visual direction: **Calm Technical / Wine Monochrome**.

Avoid neon, gaming or hacker motifs, decorative gradients, glassmorphism, stock imagery, card soup, oversized marketing headings, emoji icons, fake data, and decorative motion.

## Technology and ownership

- React, TypeScript, Vite, Tauri, Tailwind CSS, shadcn/ui base-nova, Base UI, and Lucide.
- `packages/ui` owns primitives, semantic tokens, and reusable product-level components.
- Feature logic stays in `apps/shell`.
- React never performs privileged operations or executes commands; it uses the typed Tauri/Core boundary.
- Core assets and fonts ship locally. Runtime network dependencies are forbidden.

## Palette

Dark is the default. Feature components consume semantic tokens rather than raw colors.

| Token | Value |
| --- | --- |
| Background | `oklch(0.150 0.002 286)` |
| Surface | `oklch(0.179 0.004 286)` |
| Elevated | `oklch(0.206 0.004 286)` |
| Foreground | `oklch(0.964 0.004 91)` |
| Wine interactive | `oklch(0.459 0.134 8)` |
| Border | `oklch(0.257 0.006 286)` |
| Destructive | `oklch(0.562 0.140 13)` |

Wine identifies brand, focus, selection, and the primary action; it does not mean error. Status colors are muted green, amber, red, blue, and neutral, always paired with text or shape.

## Typography and spacing

- Geist Sans for human-facing UI; Geist Mono for paths, versions, hostnames, IP addresses, hashes, and measurements.
- Body 14/20, label 13/18, section title 16/22, panel title 18/24, page title 24/30, rare setup title 30–32/38.
- Use weights 400, 500, and 600. Avoid all-caps and wide tracking.
- Use a 4 px grid, usually 8/12/16/24/32 px gaps.
- Controls are 36–40 px high. Panels use 10–12 px radii; pills are reserved for badges.
- Structure comes from spacing, surfaces, and quiet 1 px borders. Shadows are reserved for floating overlays.

## Application surfaces

One shell supports four authoritative states returned by Core:

1. `LIVE_INSTALLER`: two-column installation surface with a persistent context panel and explicit step state.
2. `FIRST_BOOT`: focused local administrator creation.
3. `LOGIN`: keyboard-first local sign-in.
4. `DASHBOARD`: medium-compact application shell with navigation and real system identity.

The installer flow is Welcome → Disk → Review and `ERASE` confirmation → real operation stages → Complete. Never display fake percentages. Installation media is visible only as a disabled device.

The initial dashboard may label unavailable product areas as `Planned`; it must not populate them with fake operational data.

## Interaction and safety

- Visible labels, inline errors, pending states, and duplicate-submit prevention are mandatory.
- Destructive and disruptive operations wait for authoritative Core confirmation.
- Every backend surface handles loading, error, unavailable, and retry states.
- Focus uses the wine ring and remains visible. Keyboard navigation follows native semantics.
- Status never relies on color alone.
- Motion is limited to brief state feedback. Respect `prefers-reduced-motion`.
- Target WCAG 2.2 AA where applicable.

## Display targets

Primary: 1920×1080. Fully usable: 1280×720. Compact minimum: 1024×768. The kiosk shell is not mobile-first and intentionally sets a 1024 px minimum viewport.

## Definition of done

A UI change uses existing shared primitives, semantic tokens, local Geist fonts, correct async/error states, visible focus, accessible labels, no fake production data, and no direct system access. Major changes are inspected at the three target resolutions before completion.
