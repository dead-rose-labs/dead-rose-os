# Dead Rose OS — DESIGN.md

> **Status:** Binding design specification  
> **Applies to:** Dead Rose OS graphical shell and shared Dead Rose UI packages  
> **Primary stack:** React + TypeScript + Tauri + shadcn/ui + Tailwind CSS  
> **Default theme:** Dark  
> **Visual direction:** Calm Technical / Wine Monochrome  
> **Last major design decision:** 2026-08-29

---

## 0. Purpose of this document

This document is the **source of truth for the visual design, UX, frontend structure, component usage, typography, color system, motion, accessibility, and design-agent workflow of Dead Rose OS**.

Dead Rose OS is not a website, SaaS dashboard, marketing page, or conventional Ubuntu desktop.

It is a **full-screen graphical system interface for a server operating system**.

The intended user experience is:

```text
Power on
  ↓
Dead Rose OS boot splash
  ↓
Dead Rose OS login
  ↓
Dead Rose OS graphical shell
  ↓
System / Nodes / Network / Storage / Updates / Diagnostics / Settings
```

The user should feel that **Dead Rose OS itself is the application**.

There is no GNOME, KDE, conventional desktop, taskbar, dock, browser chrome, or visible Ubuntu UI.

The graphical shell is built with React and rendered as a native Tauri application on the system display stack.

---

# 1. Authority and decision hierarchy

When making any UI or UX decision, follow this order:

1. **Explicit current user requirement**
2. **This `DESIGN.md`**
3. Existing Dead Rose design tokens and established components
4. Existing feature-specific patterns in the repository
5. Relevant installed design/frontend skills
6. General framework/library best practices
7. Agent taste or preference

If a skill recommends something that conflicts with this file, **this file wins**.

If a component library default conflicts with this file, **this file wins**.

If Codex thinks another palette, font, component library, icon set, or visual direction would be better, it must **not change it silently**.

Major changes to the design language require an explicit design decision and an update to this document.

---

# 2. Non-negotiable product identity

## 2.1 Product

**Dead Rose OS** is the control-plane operating system for the Dead Rose infrastructure ecosystem.

It runs on the main control server and presents a local graphical system interface.

The local UI focuses on:

- system health;
- system configuration;
- networking;
- storage;
- connected Dead Rose Node OS machines;
- updates;
- security;
- diagnostics;
- control-plane status;
- initial setup;
- login and session management.

The remote **Dead Rose** application may later share the same design system, but it is a separate application with a broader rack-management feature set.

## 2.2 Product personality

Dead Rose must feel:

- calm;
- technical;
- precise;
- quiet;
- premium without being luxurious;
- modern without being trendy;
- developer-oriented;
- infrastructure-oriented;
- trustworthy;
- restrained;
- intentional.

Dead Rose must **not** feel:

- cyberpunk;
- gaming-oriented;
- hacker-themed;
- RGB/neon;
- flashy;
- playful;
- toy-like;
- marketing-heavy;
- generic AI-generated;
- generic SaaS-dashboard-like.

## 2.3 Visual phrase

The visual direction is called:

> **Calm Technical / Wine Monochrome**

A useful mental reference is:

> modern developer tooling + quiet system software + shadcn discipline + a restrained wine identity

Do not copy another product pixel-for-pixel.

The goal is a distinct Dead Rose identity.

---

# 3. Core frontend technology

The graphical shell uses:

```text
React
TypeScript
Tauri
shadcn/ui
Tailwind CSS
Base UI primitives through shadcn/ui
Lucide icons
Geist Sans
Geist Mono
```

The system display path is conceptually:

```text
Linux
  ↓
Wayland
  ↓
kiosk compositor
  ↓
Tauri
  ↓
React
  ↓
Dead Rose OS UI
```

The design layer does not depend on GNOME, KDE, Electron, or an external browser.

---

# 4. shadcn/ui policy

## 4.1 shadcn/ui is the primary component foundation

All general-purpose interactive UI should be built from shadcn/ui components whenever an appropriate component exists.

Examples:

- Button
- Input
- Textarea
- Select
- Checkbox
- Radio Group
- Switch
- Tabs
- Dialog
- Alert Dialog
- Sheet
- Dropdown Menu
- Context Menu
- Tooltip
- Popover
- Command
- Table
- Badge
- Progress
- Skeleton
- Separator
- Scroll Area
- Breadcrumb
- Sonner
- Chart primitives where appropriate

Do not recreate a standard primitive from scratch when shadcn already provides the correct accessible primitive.

## 4.2 Project baseline

For a new Dead Rose UI workspace, use:

```json
{
  "style": "base-nova",
  "rsc": false,
  "tsx": true,
  "tailwind": {
    "config": "",
    "baseColor": "neutral",
    "cssVariables": true
  },
  "iconLibrary": "lucide"
}
```

The exact generated `components.json` may contain additional required fields and aliases.

Important decisions:

- **style:** `base-nova`
- **component primitive family:** Base UI
- **base color:** neutral
- **CSS variables:** enabled
- **React Server Components:** disabled for the Tauri/Vite shell
- **TypeScript:** enabled
- **icon library:** Lucide

Once initialized, do not casually switch the shadcn style or primitive family.

## 4.3 Ownership model

shadcn components are source code owned by the project.

However, follow this rule:

```text
packages/ui/src/components/ui/
```

contains **low-level design-system primitives**.

Do not inject page-specific styling or business logic into those primitives.

Higher-level Dead Rose components belong in:

```text
packages/ui/src/components/dead-rose/
```

Examples:

```text
SystemStatus
MetricCard
NodeStatusRow
HealthIndicator
OperationProgress
NetworkInterfaceRow
StorageDeviceCard
DangerZone
SettingsSection
PageHeader
EmptyState
ErrorState
OfflineState
```

## 4.4 Modifying shadcn components

Allowed:

- accessibility fixes;
- Dead Rose-wide styling;
- token integration;
- system-wide component behavior;
- consistent density adjustments;
- consistent focus behavior.

Not allowed:

- one-off page hacks;
- feature-specific API calls;
- business logic;
- hard-coded feature colors;
- arbitrary props added for one screen.

If a component needs many boolean styling props, reconsider its composition.

---

# 5. Agent skills

Codex should have a deliberately small set of frontend/design skills.

Skills are **specialists**, not competing design directors.

## 5.1 Recommended installed skills

### `frontend-design` — Anthropic

Repository:

```text
anthropics/skills
```

Install:

```bash
npx skills add anthropics/skills --skill frontend-design
```

Use for:

- a completely new screen;
- a major new visual surface;
- first design of an important workflow;
- evaluating hierarchy and composition;
- avoiding generic AI-generated frontend aesthetics.

Do not use it to override the established Dead Rose palette, typography, component system, density, or visual identity.

Its job is to make a new screen **distinctive within Dead Rose**, not to invent a different design system.

---

### `ui-ux-pro-max`

Repository:

```text
nextlevelbuilder/ui-ux-pro-max-skill
```

Install:

```bash
npx skills add nextlevelbuilder/ui-ux-pro-max-skill --skill ui-ux-pro-max
```

Use for:

- UX flow design;
- information architecture;
- dashboard structure;
- forms;
- settings organization;
- navigation decisions;
- data visualization selection;
- accessibility reasoning;
- responsive behavior;
- interaction patterns.

Do not blindly adopt palettes, font pairings, or predefined styles proposed by the skill.

Dead Rose already has those decisions.

---

### `design-system`

Repository:

```text
nextlevelbuilder/ui-ux-pro-max-skill
```

Install:

```bash
npx skills add nextlevelbuilder/ui-ux-pro-max-skill --skill design-system
```

Use only when working on:

- design tokens;
- spacing scales;
- typography scales;
- theme architecture;
- component state specifications;
- global design-system changes.

Do not invoke it for routine feature implementation.

---

### `shadcn`

Repository:

```text
shadcn-ui/ui
```

Install:

```bash
npx skills add shadcn-ui/ui --skill shadcn
```

Use whenever:

- adding a shadcn component;
- checking current shadcn component APIs;
- inspecting project shadcn configuration;
- deciding whether a primitive already exists;
- updating a shadcn component;
- implementing component composition around shadcn.

Before manually inventing a primitive, check shadcn first.

Use the project package runner for shadcn CLI commands.

For this project the preferred package manager is **pnpm**.

---

### `composition-patterns`

Repository:

```text
vercel-labs/agent-skills
```

Install:

```bash
npx skills add vercel-labs/agent-skills --skill composition-patterns
```

Use for:

- reusable component API design;
- compound components;
- components developing too many boolean props;
- refactoring large reusable components;
- provider/context boundaries;
- shared component architecture.

Do not use it as a visual-design skill.

---

### `web-design-guidelines`

Repository:

```text
vercel-labs/agent-skills
```

Install:

```bash
npx skills add vercel-labs/agent-skills --skill web-design-guidelines
```

Use as a **review skill after implementation**.

Use for:

- accessibility audit;
- interaction audit;
- frontend UX audit;
- focus behavior;
- form correctness;
- semantics;
- common web-interface problems.

It is primarily a reviewer, not the source of the Dead Rose visual identity.

---

### `impeccable`

Repository:

```text
pbakaus/impeccable
```

Install:

```bash
npx skills add pbakaus/impeccable --skill impeccable
```

Use for:

- final visual critique;
- polish;
- typography refinement;
- hierarchy refinement;
- spacing refinement;
- making a finished screen feel intentional rather than generic;
- detecting visual anti-patterns.

It must load and respect this `DESIGN.md`.

Do not let it replace the Dead Rose visual world unless explicitly instructed to redesign the product identity.

---

### `animate`

Repository:

```text
emilkowalski/skills
```

Install:

```bash
npx skills add emilkowalski/skills --skill animate
```

Use only when motion has a clear UX purpose.

Examples:

- opening a contextual overlay;
- spatially explaining a panel;
- feedback for a state transition;
- revealing rare first-run UI;
- smoothly transitioning a controlled layout state.

Do not invoke it just to “make the page feel alive”.

---

### `review-animations`

Repository:

```text
emilkowalski/skills
```

Install:

```bash
npx skills add emilkowalski/skills --skill review-animations
```

Use after non-trivial animation code is implemented.

Its job is to reject:

- unjustified animations;
- sluggish transitions;
- excessive motion;
- incorrect easing;
- distracting repeated animation;
- poor reduced-motion behavior.

---

## 5.2 Skill workflow by task

### New major screen

Use this mental workflow:

```text
Read DESIGN.md
  ↓
Inspect existing Dead Rose screens/components
  ↓
frontend-design
  ↓
ui-ux-pro-max
  ↓
shadcn
  ↓
implement
  ↓
composition-patterns if reusable architecture is involved
  ↓
impeccable
  ↓
web-design-guidelines
  ↓
review-animations if meaningful motion exists
```

### Existing screen modification

Do **not** redesign the screen unless requested.

Workflow:

```text
Read DESIGN.md
  ↓
Inspect local patterns
  ↓
shadcn if component work is needed
  ↓
implement smallest coherent change
  ↓
web-design-guidelines when interaction/accessibility changed
```

### Design-system change

```text
Read DESIGN.md
  ↓
design-system
  ↓
inspect every affected primitive
  ↓
update tokens/spec
  ↓
update DESIGN.md if the decision changed
  ↓
visual regression review
```

### Animation work

```text
Ask: does this need to animate?
  ↓
No → do not animate
Yes
  ↓
animate
  ↓
implement
  ↓
review-animations
```

---

# 6. Rules for Codex before touching UI

Before implementing a UI task, Codex must:

1. Read this file.
2. Inspect the nearest existing feature implementation.
3. Inspect relevant shared components.
4. Inspect design tokens instead of guessing colors or sizes.
5. Determine whether a shadcn primitive already exists.
6. Determine whether a Dead Rose higher-level component already exists.
7. Use the minimum relevant skills.
8. Preserve existing product behavior unless the task explicitly changes it.

Codex must **not ask questions whose answer already exists in this document or established code**.

When a minor detail is unspecified, choose the simplest solution consistent with existing Dead Rose patterns.

---

# 7. Color philosophy

Dead Rose is a **mostly monochrome interface with a restrained wine accent**.

Approximate visual distribution:

```text
80% neutral surfaces
15% text / separators / structure
 5% wine accent
```

Wine is a signature accent.

It is **not** a background color for entire screens and should not flood the interface.

The palette must remain calm.

---

# 8. Brand palette

## 8.1 Core colors

### Black / dark neutral

```text
Dead Rose Black
HEX #0B0B0C
OKLCH ~ 0.150 0.002 286
```

Primary dark background.

### Dark surface

```text
Surface 1
HEX #111113
OKLCH ~ 0.179 0.004 286
```

### Elevated surface

```text
Surface 2
HEX #171719
OKLCH ~ 0.206 0.004 286
```

### Strong border

```text
Border Strong
HEX #2B2B2F
OKLCH ~ 0.291 0.007 286
```

### Warm white

```text
Dead Rose White
HEX #F4F3F0
OKLCH ~ 0.964 0.004 91
```

### Wine

```text
Wine
HEX #7A263A
OKLCH ~ 0.403 0.117 10
```

### Wine interactive

```text
Wine Active
HEX #922F49
OKLCH ~ 0.459 0.134 8
```

### Wine dark

```text
Wine Dark
HEX #521927
OKLCH ~ 0.309 0.086 9
```

### Wine surface

```text
Wine Surface
HEX #2A1118
OKLCH ~ 0.218 0.042 3
```

---

# 9. Semantic color tokens

Components must consume **semantic tokens**, not raw brand values.

Do not write feature code such as:

```tsx
className="bg-[#922F49]"
```

Do:

```tsx
className="bg-primary text-primary-foreground"
```

or a named Dead Rose semantic utility/token.

## 9.1 Dark theme

Dark is the default Dead Rose OS theme.

Recommended starting tokens:

```css
.dark {
  --background: oklch(0.150 0.002 286);
  --foreground: oklch(0.964 0.004 91);

  --card: oklch(0.179 0.004 286);
  --card-foreground: oklch(0.964 0.004 91);

  --popover: oklch(0.206 0.004 286);
  --popover-foreground: oklch(0.964 0.004 91);

  --primary: oklch(0.459 0.134 8);
  --primary-foreground: oklch(0.964 0.004 91);

  --secondary: oklch(0.206 0.004 286);
  --secondary-foreground: oklch(0.964 0.004 91);

  --muted: oklch(0.206 0.004 286);
  --muted-foreground: oklch(0.722 0.006 85);

  --accent: oklch(0.218 0.042 3);
  --accent-foreground: oklch(0.827 0.052 3);

  --border: oklch(0.257 0.006 286);
  --input: oklch(0.291 0.007 286);
  --ring: oklch(0.459 0.134 8);

  --destructive: oklch(0.562 0.140 13);
  --destructive-foreground: oklch(0.985 0 0);
}
```

## 9.2 Light theme

Light mode is a first-class theme, even though dark is the default.

```css
:root {
  --background: #F7F6F3;
  --foreground: #1B1918;

  --card: #FFFFFF;
  --card-foreground: #1B1918;

  --popover: #FFFFFF;
  --popover-foreground: #1B1918;

  --primary: #7A263A;
  --primary-foreground: #FFFFFF;

  --secondary: #EEECE7;
  --secondary-foreground: #1B1918;

  --muted: #EEECE7;
  --muted-foreground: #6F6B67;

  --accent: #F3E7EA;
  --accent-foreground: #521927;

  --border: #D7D3CD;
  --input: #D7D3CD;
  --ring: #922F49;

  --destructive: #A83F51;
  --destructive-foreground: #FFFFFF;
}
```

When implementing the final token file, use one consistent color notation.

Prefer OKLCH for authored design tokens.

---

# 10. Status colors

Brand colors and status colors are separate concepts.

Wine means:

- brand;
- active selection;
- primary action;
- focus;
- selected state.

Wine must **not** mean “error”.

System health uses subdued semantic status colors:

```text
Healthy / success
#4F8A63

Warning
#B58A4A

Critical / error
#B84C5D

Informational
#5D79A6

Unknown / offline
neutral gray
```

Rules:

- status colors should be muted, not neon;
- never communicate state with color alone;
- pair color with label, icon, or shape;
- avoid using large saturated status backgrounds;
- use tinted surfaces for alerts instead.

Example:

```text
● Healthy
▲ Warning
● Critical
○ Offline
? Unknown
```

---

# 11. Typography

## 11.1 Font families

Dead Rose uses:

```text
Primary UI:
Geist Sans

Technical / machine data:
Geist Mono
```

Do not substitute:

- Inter;
- Roboto;
- Arial;
- random system fonts;
- a new trendy display font.

Changing the core typography is a design-system decision.

## 11.2 Why two fonts

Geist Sans is used for human-facing interface language.

Examples:

```text
System
Network
Storage
Restart system
Update available
Connected nodes
```

Geist Mono is used when the value is machine-oriented or benefits from fixed-width alignment.

Examples:

```text
rose-control-01
192.168.10.20
fd7a:115c:a1e0::1
v0.1.0
tcp/443
SHA256
2.43 GiB
eth0
nvme0n1
```

Do not make the entire product monospace.

The Claude-Code-like technical feeling comes from **selective mono typography**, restrained spacing, and technical density.

## 11.3 Font delivery

Dead Rose OS must not depend on an internet font CDN at runtime.

Fonts are shipped locally as part of the application/system image.

No Google Fonts runtime dependency.

No external font network request.

## 11.4 Typography scale

Use a compact system-oriented type scale.

```text
Caption
12px / 16px
400–500

Small label
13px / 18px
500

Body
14px / 20px
400

Body strong
14px / 20px
500–600

Section title
16px / 22px
600

Panel title
18px / 24px
600

Page title
24px / 30px
600

Large system title
30–32px / 38px
600
```

Large 30–32px typography is reserved for:

- login;
- initial setup;
- rare empty/onboarding surfaces.

Normal operational screens should remain compact.

Do not create marketing-style 48–72px headings.

## 11.5 Weight

Prefer:

```text
400 normal body
500 labels
600 headings
```

Avoid excessive bold text.

`700+` should be rare.

## 11.6 Letter spacing

Default to natural font metrics.

Use slightly tighter tracking only for large titles when needed.

Do not use large positive letter spacing to make the interface look “technical”.

Avoid unnecessary ALL CAPS.

---

# 12. Spacing system

Use a 4px base grid.

Preferred scale:

```text
4
8
12
16
20
24
32
40
48
64
```

Most UI should use:

```text
8px  → tight internal relationship
12px → compact component spacing
16px → normal component spacing
24px → section spacing
32px → major grouping
```

Do not introduce random values such as:

```text
13px
19px
27px
37px
```

unless a genuinely optical adjustment is required.

Prefer `gap` for sibling layout spacing.

Avoid stacks of unrelated margins.

---

# 13. Radius

Dead Rose is soft but not bubbly.

Base radius:

```css
--radius: 0.625rem;
```

General intent:

```text
small control       6–8px
button/input        8–10px
card/panel          10–12px
large dialog        12–14px
```

Do not over-round every surface.

Pill shapes are reserved for:

- badges;
- status chips;
- segmented micro-controls where appropriate.

Do not turn normal buttons, cards, dialogs, or inputs into pills by default.

---

# 14. Borders, depth, and shadows

Dead Rose should feel structured primarily through:

- spacing;
- surface tone;
- subtle borders;
- hierarchy.

Not through heavy shadows.

## 14.1 Borders

Use quiet neutral borders.

Dark mode borders should usually be only slightly lighter than their surface.

Avoid high-contrast box outlines around every region.

## 14.2 Shadows

Use shadows sparingly for:

- popovers;
- menus;
- dialogs;
- temporarily floating UI.

Main dashboard cards should not look like floating glass panels.

## 14.3 Glass

Glassmorphism is **not a default Dead Rose technique**.

Avoid:

- large blurred transparent panels;
- frosted-glass cards everywhere;
- excessive backdrop blur.

A small restrained blur may be used for a transient overlay if it materially improves layering.

---

# 15. Gradients

Default rule:

> **No decorative gradients in operational UI.**

Do not use:

- purple/blue gradients;
- wine-to-pink gradients;
- gradient text;
- glowing gradient borders.

A subtle controlled gradient may be used only for a rare brand moment such as a boot/login background, and even there a flat surface is preferred.

Operational system screens remain flat and calm.

---

# 16. Icons

Use **Lucide** as the standard icon library.

Rules:

- do not mix Lucide with Heroicons, Font Awesome, Material Icons, etc.;
- do not use emoji as application icons;
- do not use text symbols when a proper icon exists;
- use a consistent stroke weight;
- common UI icons should usually be 16–20px;
- navigation icons may be 18–20px;
- icons must support, not replace, understandable labels.

Brand icons and the Dead Rose logo are custom SVG assets.

Codex must **not invent a final Dead Rose logo** unless explicitly asked to design the logo.

Until the logo is finalized, use the approved placeholder brand mark/wordmark assets already present in the repository.

---

# 17. Application shell

Dead Rose OS is a full-screen system application.

The shell should provide:

```text
┌─────────────────────────────────────────────────────────────┐
│ Top bar / context / status                                  │
├──────────────┬──────────────────────────────────────────────┤
│              │                                              │
│ Navigation   │ Main content                                 │
│              │                                              │
│              │                                              │
│              │                                              │
│              │                                              │
├──────────────┴──────────────────────────────────────────────┤
│ Optional contextual operation / status surface              │
└─────────────────────────────────────────────────────────────┘
```

## 17.1 Sidebar

Default expanded width:

```text
220–240px
```

Compact/collapsed rail:

```text
60–68px
```

The sidebar should:

- remain visually quiet;
- use clear groups;
- show an active route using a restrained wine-tinted state;
- avoid large bright wine blocks;
- contain the product identity near the top;
- contain session/system utility actions near the bottom where appropriate.

Potential primary groups:

```text
Overview

Infrastructure
  Nodes
  Network
  Storage

System
  Updates
  Security
  Logs
  Diagnostics
  Settings
```

Do not add a navigation item for every tiny screen.

## 17.2 Top bar

Typical height:

```text
48–56px
```

Possible content:

- current context;
- breadcrumb;
- connection state;
- active operation state;
- command palette trigger;
- session menu.

Do not fill it with decorative controls.

## 17.3 Main content

Recommended operational page padding:

```text
24px
```

May become:

```text
16px
```

in compact resolutions.

Use full available width when dense infrastructure data benefits from it.

Avoid artificial marketing-style narrow content columns for dashboards/tables.

---

# 18. Supported display sizes

Primary design target:

```text
1920 × 1080
```

Must remain fully usable at:

```text
1280 × 720
```

Provide a compact but usable layout at:

```text
1024 × 768
```

The local Dead Rose OS shell is **not mobile-first**.

Do not distort desktop system UI decisions in order to support phone layouts.

Shared components should still be structurally responsive so the remote Dead Rose application can adapt them later.

---

# 19. Page structure

Most operational pages should follow:

```text
PageHeader

Primary content

Secondary details / contextual tools

Operational state
```

Typical `PageHeader`:

```text
Title
Short one-line description if necessary
Optional status
Primary actions on the right
```

Do not add descriptions just to fill space.

If the page title is self-explanatory, keep the header compact.

---

# 20. Avoid “card soup”

Do not put every value inside a separate rounded rectangle.

Bad:

```text
[CPU card] [RAM card] [Disk card] [Uptime card]
[IP card]  [Temp card] [Version card] [Kernel card]
```

Use cards only where a real grouping exists.

Prefer:

- sections;
- rows;
- dividers;
- compact metric groups;
- tables;
- structured lists;
- a small number of meaningful panels.

A system interface should feel information-dense without feeling cluttered.

---

# 21. Data density

Dead Rose should be **medium-compact**.

It is infrastructure software.

The user should be able to see useful information without scrolling through oversized cards and excessive whitespace.

However:

- never sacrifice readability;
- never shrink hit areas below comfortable sizes;
- never compress unrelated information together.

The target is:

> compact enough for serious operational work, calm enough for long sessions.

---

# 22. Buttons

Button hierarchy:

```text
Primary
Secondary
Outline
Ghost
Destructive
Link
```

## 22.1 Primary

Wine background.

Use for the single dominant action in a context.

Examples:

```text
Install update
Save changes
Continue
Create volume
```

Do not show five wine primary buttons in one view.

## 22.2 Secondary / outline

Use for ordinary operations.

Examples:

```text
Refresh
Edit
View details
Cancel
```

## 22.3 Destructive

Use destructive semantic red, not wine.

Examples:

```text
Delete
Remove node
Erase disk
Factory reset
```

## 22.4 Ghost

Use for:

- compact toolbar controls;
- overflow actions;
- navigation utility actions.

## 22.5 Button copy

Prefer direct verbs:

```text
Restart system
Install update
Save network
Remove node
```

Avoid vague:

```text
Submit
OK
Proceed
Do it
```

when a specific verb is available.

---

# 23. Inputs and forms

General form rules:

- persistent visible label above the field;
- placeholder is not a label;
- concise helper text only where useful;
- validation errors appear next to the relevant field;
- required state is understandable;
- keyboard flow is correct;
- disabled state is visually clear;
- pending state prevents duplicate submission.

Default input/control height should generally be around:

```text
36–40px
```

For passwords:

- mask by default;
- provide show/hide control;
- never log or expose password values.

For IP addresses, ports, IDs, and technical values, use Geist Mono inside the field where appropriate.

---

# 24. Tables and lists

Infrastructure data often belongs in tables or structured lists.

Use tables for comparable entities such as:

```text
nodes
network interfaces
storage devices
volumes
updates
operations
logs
```

Rules:

- left-align text;
- right-align comparable numeric values where helpful;
- use Geist Mono for machine values;
- keep row height compact but comfortable;
- make row actions predictable;
- support keyboard focus;
- avoid horizontal scrolling at target resolutions when reasonable;
- use sticky headers for long datasets where useful.

Do not use a card grid when a table communicates the data better.

---

# 25. Charts

Use charts only when a trend, relationship, or history matters.

Do not create a chart solely because numeric data exists.

Preferred chart types:

- line;
- area;
- bar;
- compact sparkline;
- donut only for simple composition where it is genuinely clearer.

Avoid:

- 3D charts;
- rainbow palettes;
- decorative pie charts;
- excessive gradients;
- animated chart entrances on every navigation;
- dozens of simultaneous live animations.

Use shadcn chart patterns / the project chart abstraction.

Color order:

1. wine for the primary emphasized series;
2. neutral grays for secondary series;
3. muted status colors when the series semantically represents status.

Axes and machine values may use Geist Mono.

---

# 26. System statuses

Standard state vocabulary should be consistent.

Preferred terms:

```text
Healthy
Degraded
Warning
Critical
Offline
Unknown
Updating
Starting
Stopping
Restarting
Connected
Disconnected
```

Do not invent synonyms per page.

Example: do not mix `Online`, `Up`, `Alive`, and `Connected` for the same semantic concept.

Define domain-specific status enums once and render them consistently.

---

# 27. Async state requirements

Every async/system-data surface must consider:

1. loading;
2. loaded;
3. empty;
4. error;
5. disconnected/offline;
6. stale;
7. permission denied where applicable;
8. operation in progress.

Do not assume the backend always responds instantly.

## 27.1 Loading

Use:

- skeletons for structured content;
- compact spinner for local action progress;
- operation progress for long-running system tasks.

Do not block the whole application for a small local refresh.

## 27.2 Empty state

Empty states should be calm and useful.

Example:

```text
No nodes connected

Connect a Dead Rose Node OS machine to manage it from this system.

[Add node]
```

Do not use cute illustrations or marketing copy.

## 27.3 Error state

Explain:

- what failed;
- what the user can do;
- whether data may be stale.

Avoid generic:

```text
Something went wrong.
```

when a more specific message is available.

---

# 28. Destructive and system-critical actions

Dead Rose controls real infrastructure.

System actions must never imply success before the backend confirms it.

Examples:

- reboot;
- shutdown;
- erase disk;
- delete volume;
- remove node;
- install update;
- network reconfiguration;
- factory reset.

Rules:

- show exactly what will happen;
- distinguish reversible from irreversible actions;
- use confirmation for destructive or disruptive actions;
- use stronger confirmation for irreversible actions;
- show operation progress;
- show final confirmed result;
- never hide a critical failure only inside a toast.

Do not use optimistic UI for destructive infrastructure operations unless the domain explicitly guarantees safe semantics.

---

# 29. Dialogs

Dialogs are for focused decisions.

Use `Dialog` for:

- forms;
- contextual configuration;
- detail surfaces.

Use `AlertDialog` for:

- destructive confirmation;
- disruptive system actions;
- irreversible operations.

Rules:

- clear title;
- one concise explanation;
- explicit action labels;
- destructive action visually distinct;
- `Esc` closes non-critical dialogs;
- focus is trapped correctly;
- focus returns correctly after closing.

Avoid nesting dialogs.

---

# 30. Toasts and notifications

Use toast notifications for transient confirmation:

```text
Settings saved
Node label updated
Copy completed
```

Do not rely on toast for:

- critical errors;
- long-running operations;
- actions requiring follow-up;
- connection loss.

Those need persistent inline or global state.

---

# 31. Navigation and command palette

Primary navigation is visible in the app shell.

Add a command palette using the shadcn `Command` pattern.

Default shortcut:

```text
Ctrl+K
```

If the platform uses Command semantics, support:

```text
Cmd+K
```

where relevant to the shared remote app.

The command palette may provide:

- navigate to page;
- find node;
- search setting;
- execute safe common action.

Destructive actions should not execute immediately from search without an appropriate confirmation flow.

---

# 32. Keyboard behavior

Dead Rose must be usable efficiently with a keyboard.

Minimum expectations:

```text
Tab / Shift+Tab   focus traversal
Enter             activate focused control
Space             toggle appropriate controls
Esc               dismiss overlay / cancel transient state
Arrow keys        menu/list navigation where expected
Ctrl+K            command palette
```

Do not implement custom keyboard behavior that conflicts with standard accessible primitives.

---

# 33. Focus

Focus must always be visible for keyboard users.

Use the semantic `ring` token.

The focus ring may use the wine accent.

Do not remove outlines without providing an equal or better accessible focus treatment.

Hover is not a replacement for focus.

---

# 34. Accessibility baseline

Target:

> **WCAG 2.2 AA where applicable to the graphical shell**

Requirements:

- sufficient contrast;
- semantic controls;
- keyboard operation;
- visible focus;
- labels for inputs;
- accessible names for icon-only controls;
- correct dialog focus management;
- no color-only state communication;
- reduced-motion support;
- no important information available only on hover;
- useful error messages;
- logical heading hierarchy;
- correct ARIA only where native semantics are insufficient.

Do not add ARIA to compensate for incorrect HTML if semantic HTML can solve the problem.

---

# 35. Motion philosophy

Motion is functional, not decorative.

Every animation must answer:

> Why does this need to move?

Valid reasons:

- spatial continuity;
- state-change feedback;
- showing where a panel came from;
- explaining layout change;
- reducing visual abruptness;
- rare first-run brand moment.

Invalid reason:

> It looks cool.

## 35.1 Frequency rule

The more frequently an interaction occurs, the less animation it should have.

Frequently used navigation should feel immediate.

Keyboard-heavy actions should generally avoid visible motion.

## 35.2 Timing

Preferred ranges:

```text
hover / color response       100–140ms
small overlay                140–180ms
dialog / sheet               160–220ms
larger rare transition       200–280ms
```

Avoid normal UI animations above 300ms.

## 35.3 Motion style

Prefer:

- opacity;
- small translation;
- controlled scale near 0.98–1.00 only where appropriate;
- smooth layout transition.

Avoid:

- bounce;
- dramatic spring motion;
- scale from 0;
- large sliding distances;
- parallax;
- constant pulsing;
- decorative looping motion.

## 35.4 Reduced motion

Respect:

```css
prefers-reduced-motion
```

Meaningful functionality must not depend on animation.

---

# 36. Loading animation

A spinner may exist for local indeterminate loading.

It should:

- be small;
- be quiet;
- use semantic foreground/primary colors;
- not become a large decorative centerpiece unless the entire system is actually starting.

Long operations should show real progress when available.

---

# 37. Boot splash

The boot splash is **not part of React**.

It is implemented by the system boot splash layer.

However it must use the same brand tokens.

Boot splash direction:

```text
background: Dead Rose Black
logo/mark: warm white + restrained wine
wordmark: warm white
animation: subtle
```

Never show:

- Ubuntu branding;
- random boot logs during normal successful boot;
- bright gradients;
- complex marketing animation.

A diagnostic/recovery mode may expose technical boot output separately.

---

# 38. Transition from boot to GUI

The handoff must feel intentional.

Goals:

- boot splash background and initial Tauri shell background match;
- no white flash from the WebView;
- no visible browser loading;
- no flash of unstyled content;
- login surface appears cleanly when the GUI is ready.

The initial HTML/CSS background must be set immediately to the Dead Rose dark background before React hydration/render.

---

# 39. Login screen

The login screen is part of the Dead Rose graphical shell.

It should feel like system software, not a SaaS sign-in page.

Requirements:

- Dead Rose OS identity visible;
- restrained layout;
- username;
- password;
- clear login action;
- useful authentication error;
- keyboard-first behavior;
- no social login;
- no marketing content;
- no background photography;
- no huge glass card.

The default login screen should use dark mode.

A subtle brand composition may be used, but the form remains the focus.

---

# 40. Initial setup

First boot setup should use a step-based system flow.

Potential steps:

```text
Welcome
System identity
Administrator
Network
Storage
Security
Review
Apply
Ready
```

Rules:

- show current step;
- allow going back where safe;
- clearly distinguish planning from applying;
- once applying system configuration, display real operation states;
- never fake progress;
- if setup fails, show the specific failing subsystem and recovery action.

Do not create a consumer-app onboarding carousel.

---

# 41. Copy and tone of voice

Dead Rose UI language is:

- concise;
- factual;
- calm;
- technically correct;
- direct;
- non-marketing.

Good:

```text
Network configuration could not be applied.
The previous configuration is still active.
```

Bad:

```text
Oops! Something went wrong 😢
```

Good:

```text
Restart system
```

Bad:

```text
Give it a fresh start
```

Good:

```text
No nodes connected
```

Bad:

```text
It looks lonely in here!
```

Do not use emoji in system copy.

---

# 42. Technical formatting

Use Geist Mono for:

- hostnames;
- IP addresses;
- MAC addresses;
- ports;
- versions;
- hashes;
- interface names;
- device paths;
- filesystem paths;
- command snippets;
- IDs;
- exact machine measurements where alignment matters.

Recommended unit conventions:

```text
Memory / filesystem capacity:
MiB, GiB, TiB

Network throughput:
Mbit/s, Gbit/s

Storage throughput:
MB/s or GB/s where device/performance convention expects decimal units

Temperature:
°C

CPU / memory usage:
%

Duration:
ms, s, min, h, d
```

Be consistent within each domain.

---

# 43. Time and dates

Operational UI may show friendly relative time:

```text
2 min ago
12 min ago
3 h ago
```

When exact time matters, provide an exact timestamp on detail/tooltip.

Logs should show exact timestamps.

Avoid ambiguous date formats.

Prefer locale-aware display for user-facing dates and ISO-like precision for technical/log contexts.

---

# 44. Theme behavior

Dead Rose supports:

```text
Dark
Light
```

Dark is the default.

A later system setting may add `System` where a meaningful host preference exists, but the local kiosk UI must never depend on a GNOME/KDE theme.

All components must use semantic theme tokens.

Do not create separate ad-hoc dark-only component colors.

---

# 45. Runtime independence

Dead Rose OS may be used without public internet access.

Therefore UI must not require runtime access to:

- font CDNs;
- icon CDNs;
- remote CSS;
- public JavaScript;
- external image hosts;
- analytics scripts;
- third-party UI services.

All core assets must ship with the application/system image.

---

# 46. Images and illustrations

Operational Dead Rose screens should generally avoid decorative imagery.

Allowed:

- Dead Rose brand assets;
- topology diagrams;
- device diagrams when actually useful;
- QR code for a specific pairing/setup workflow;
- meaningful system visualizations.

Avoid:

- stock photos;
- decorative 3D servers;
- generic AI art;
- random abstract backgrounds.

---

# 47. File structure

The UI should be structured so the design system can later be shared with the remote Dead Rose application.

Recommended repository shape:

```text
dead-rose-os/
├── DESIGN.md
│
├── apps/
│   └── os-shell/
│       ├── components.json
│       ├── package.json
│       ├── vite.config.ts
│       ├── src/
│       │   ├── app/
│       │   │   ├── App.tsx
│       │   │   ├── router.tsx
│       │   │   └── providers/
│       │   │
│       │   ├── routes/
│       │   │   ├── login/
│       │   │   ├── setup/
│       │   │   ├── overview/
│       │   │   ├── nodes/
│       │   │   ├── network/
│       │   │   ├── storage/
│       │   │   ├── updates/
│       │   │   ├── security/
│       │   │   ├── logs/
│       │   │   ├── diagnostics/
│       │   │   └── settings/
│       │   │
│       │   ├── features/
│       │   │   ├── auth/
│       │   │   ├── system-health/
│       │   │   ├── nodes/
│       │   │   ├── network/
│       │   │   ├── storage/
│       │   │   ├── updates/
│       │   │   └── operations/
│       │   │
│       │   ├── components/
│       │   │   └── shell/
│       │   │
│       │   ├── hooks/
│       │   ├── lib/
│       │   │   ├── api/
│       │   │   ├── tauri/
│       │   │   └── formatting/
│       │   │
│       │   ├── assets/
│       │   │   └── brand/
│       │   │
│       │   └── main.tsx
│       │
│       └── src-tauri/
│
└── packages/
    └── ui/
        ├── components.json
        ├── package.json
        └── src/
            ├── components/
            │   ├── ui/
            │   └── dead-rose/
            │
            ├── hooks/
            ├── lib/
            ├── styles/
            │   ├── globals.css
            │   ├── tokens.css
            │   └── typography.css
            │
            └── index.ts
```

---

# 48. Responsibilities by folder

## `packages/ui/src/components/ui`

Low-level shadcn primitives.

Examples:

```text
button.tsx
dialog.tsx
input.tsx
table.tsx
tabs.tsx
tooltip.tsx
```

No Dead Rose feature business logic.

## `packages/ui/src/components/dead-rose`

Reusable product-level components.

Examples:

```text
page-header.tsx
status-indicator.tsx
system-metric.tsx
metric-group.tsx
operation-progress.tsx
settings-section.tsx
empty-state.tsx
error-state.tsx
health-summary.tsx
```

These may know Dead Rose visual conventions, but should not directly perform backend calls.

## `apps/os-shell/src/features`

Feature logic and feature-specific components.

A feature may contain:

```text
components/
hooks/
model/
api/
utils/
```

Do not create giant global `components/` dumping grounds.

## `apps/os-shell/src/routes`

Routes compose features and layout.

Routes should not contain hundreds of lines of reusable UI implementation.

## `apps/os-shell/src/lib/tauri`

Typed frontend boundary to Tauri/native commands.

React components must not execute shell commands.

---

# 49. Component architecture

Prefer composition over “config monster” components.

Bad:

```tsx
<SystemCard
  compact
  bordered
  wine
  showIcon
  showActions
  dense
  horizontal
  loading
/>
```

Better:

```tsx
<SystemCard>
  <SystemCard.Header>...</SystemCard.Header>
  <SystemCard.Body>...</SystemCard.Body>
  <SystemCard.Actions>...</SystemCard.Actions>
</SystemCard>
```

Use variants when there are true semantic variants.

Do not use boolean props as a substitute for proper component structure.

---

# 50. Component size and responsibility

A component should have one clear role.

When a component becomes difficult to name or contains several unrelated regions and behaviors, split it.

However, do not fragment simple UI into dozens of tiny wrapper files with no meaningful reuse.

The goal is clear ownership, not maximal component count.

---

# 51. Feature boundaries

Business/system feature logic belongs near the feature.

Examples:

```text
features/network/
features/storage/
features/updates/
```

Do not place feature-specific hooks in a global generic hooks folder merely because they are hooks.

Global shared hooks should genuinely be cross-feature.

---

# 52. State management

Prefer the simplest state ownership that fits.

Order of preference:

1. local React state for local UI state;
2. form state in the form;
3. async backend state in the project async-query layer;
4. shared client state only when multiple distant surfaces genuinely need it.

Do not add a global store for every toggle.

Do not duplicate authoritative backend/system state into an unrelated client store.

---

# 53. Backend boundary

React is presentation and interaction logic.

React must not directly:

- execute shell commands;
- call `sudo`;
- manipulate partitions;
- invoke systemd;
- edit system files;
- manage networking through shell scripts.

UI action:

```text
React
  ↓
typed Tauri/native command or local API
  ↓
Dead Rose control layer
  ↓
privileged system layer where required
```

The UI shows results returned by the authoritative backend.

---

# 54. Fake data policy

Production components must not contain hard-coded fake infrastructure data.

Bad:

```tsx
const cpu = 42
const hostname = "server-01"
```

for shipped code.

Mock/fixture data is allowed only in explicit:

```text
stories/
fixtures/
tests/
mocks/
```

Production routes must clearly connect to real typed data sources or display a valid unavailable/loading state.

---

# 55. Storybook / component catalog

Reusable components should have isolated visual documentation.

Use Storybook or the project-selected equivalent for:

- shared UI primitives that are substantially customized;
- Dead Rose product components;
- important states.

Stories should demonstrate:

- default;
- hover/focus where possible;
- disabled;
- loading;
- empty;
- error;
- long content;
- dark theme;
- light theme.

Do not create stories for trivial one-use layout wrappers.

---

# 56. Visual regression

Important shared UI and critical system flows should have screenshot/visual regression coverage where practical.

High-priority surfaces:

```text
Login
Initial setup
Application shell
Overview
Network configuration
Storage destructive flow
Update flow
Critical dialogs
```

A design-system token change must be treated as potentially affecting the whole product.

---

# 57. Testing UX, not only rendering

Important workflows should test:

- keyboard navigation;
- disabled/pending state;
- error state;
- confirmation behavior;
- loading state;
- offline behavior where relevant;
- long strings;
- constrained resolution.

A component “rendering without crashing” is not sufficient UX validation.

---

# 58. Z-index policy

Do not invent arbitrary z-index values.

Use a semantic layering model, for example:

```text
base            0
sticky          20
navigation      30
popover/menu    40
dialog          50
toast           60
critical        70
```

Maintain a single project layering convention.

Do not use values such as:

```text
z-[999999]
```

---

# 59. Scroll behavior

The app shell itself should not accidentally create multiple competing scroll areas.

Prefer:

- fixed application shell;
- one intentional main content scroller;
- contained scrolling inside tables/log viewers only where required.

Dialogs and sheets must prevent inappropriate background scrolling.

---

# 60. Logs UI

Logs are technical and should use Geist Mono.

Requirements:

- compact;
- readable line height;
- timestamps visually de-emphasized but accessible;
- severity distinguishable by label/color;
- search/filter controls;
- pause/follow behavior for live logs where applicable;
- line wrapping configurable where useful;
- copy support.

Do not render logs as colorful chat messages.

---

# 61. Network UI

Networking is high-risk configuration.

UI should clearly distinguish:

```text
current state
desired/edit state
pending apply
applied state
rollback/failure
```

Do not visually imply that edited values are active until the backend confirms application.

When a network change may disconnect the UI, communicate that explicitly before applying.

---

# 62. Storage UI

Storage values should emphasize:

- device identity;
- capacity;
- filesystem/role;
- health;
- mount/use state;
- destructive consequences.

Device identifiers and paths use Geist Mono.

Destructive actions such as formatting/erasing must be visually and behaviorally separated from routine controls.

---

# 63. Update UI

Update UI should show:

```text
current version
available version
release channel if relevant
download state
verification state
installation state
reboot requirement
rollback/result state
```

Never show “Updated successfully” until the system has authoritative confirmation.

For long update operations, use a persistent operation surface, not only a spinner.

---

# 64. Node UI

Node status must be scan-friendly.

A node row/card should make it easy to identify:

```text
name
status
role/capabilities where relevant
CPU
memory
network/address if relevant
last contact
active operation
```

Do not overwhelm the default list with every available hardware field.

Detailed hardware belongs on the node detail screen.

---

# 65. Settings UI

Settings should be organized by meaningful domain.

Use:

```text
SettingsSection
label
description where needed
control
```

Avoid one giant form with hundreds of fields.

Changes should either:

- save immediately when clearly safe and conventional;
- or use explicit Save/Apply when changes form a configuration transaction.

Do not mix both behaviors arbitrarily in one section.

---

# 66. Dangerous settings

Use a dedicated `DangerZone` pattern for:

- factory reset;
- identity reset;
- destructive storage actions;
- removing the control-plane identity;
- similar irreversible operations.

Danger Zone should be clear but not visually screaming across the entire settings page.

---

# 67. Copyable technical values

For technical values such as:

```text
IP
node ID
certificate fingerprint
path
hash
version
```

support convenient copy where useful.

Use a copy icon/button with accessible label.

After copying, a subtle confirmation is sufficient.

Do not replace the original value with “Copied!” and cause layout shift.

---

# 68. Tooltips

Use tooltips for:

- icon-only controls;
- unfamiliar technical abbreviations;
- secondary precision.

Do not put essential instructions only in tooltips.

Do not use a tooltip to compensate for an unclear icon when a label would be better.

---

# 69. Context menus

Use context menus for secondary expert actions, not for the only access to important functionality.

Critical actions should remain discoverable from a detail/action surface.

Context-menu destructive items must use destructive semantics.

---

# 70. Hover

Hover should be subtle.

Typical hover effects:

- slight surface change;
- slightly stronger border;
- foreground emphasis.

Avoid:

- large scale;
- card lift;
- glow;
- dramatic shadow;
- moving elements.

Dead Rose is not a marketing landing page.

---

# 71. Selected / active state

Use wine carefully for selected state.

Preferred pattern:

- wine-tinted subtle background;
- wine foreground/icon;
- small indicator;
- accessible contrast.

Avoid:

- full saturated wine sidebar rows everywhere;
- glowing active borders;
- bright red selection.

---

# 72. Skeletons

Skeletons should match the approximate content structure.

Do not show a giant generic rectangle when the final content is a table.

Skeleton motion must respect reduced-motion preferences.

Avoid long decorative shimmer if a quieter pulse/static skeleton works.

---

# 73. Empty/error illustrations

Default to icon + concise copy.

Do not add decorative cartoon illustrations unless a future explicit brand decision introduces them.

System software should remain restrained.

---

# 74. Anti-pattern blacklist

Codex must avoid the following unless explicitly requested:

- generic blue primary color;
- purple/cyan AI gradients;
- neon wine/red glow;
- glassmorphism everywhere;
- giant blurred blobs;
- gradient text;
- rainbow charts;
- excessive drop shadows;
- every section inside a card;
- every card with the same visual weight;
- huge marketing typography;
- pill-shaped everything;
- emoji icons;
- mixed icon libraries;
- random hard-coded colors;
- random spacing;
- random radii;
- arbitrary z-index;
- all-monospace UI;
- all-uppercase navigation;
- animated everything;
- fake loading progress;
- fake system data;
- optimistic success for risky infrastructure actions;
- hidden critical errors in toast only;
- browser/SaaS-looking login page;
- stock photography;
- abstract AI-generated decorative art;
- unnecessary hamburger navigation at desktop size;
- mobile-first compromises in the local OS shell;
- direct shell/system calls from React;
- duplicating a shadcn primitive from scratch without reason.

---

# 75. Dependency policy for UI

Do not add a new frontend dependency merely because it makes one component easier.

Before adding a dependency:

1. check shadcn;
2. check existing project dependencies;
3. check native browser/CSS capability;
4. evaluate bundle/runtime/security impact;
5. confirm it solves a recurring or substantial problem.

Do not introduce a second:

- component library;
- icon library;
- styling framework;
- form system;
- animation system;
- chart system

without an explicit architecture decision.

---

# 76. Preferred implementation tools

Baseline choices:

```text
UI framework:
React + TypeScript

Build:
Vite

Native shell:
Tauri

Components:
shadcn/ui

Primitive foundation:
Base UI

Styling:
Tailwind CSS + semantic CSS variables

Icons:
Lucide

Class composition:
cn() / clsx + tailwind-merge

Variants:
class-variance-authority where appropriate

Forms:
project-standard React form solution + schema validation

Charts:
shadcn chart abstraction / project-standard Recharts integration

Notifications:
Sonner through shadcn patterns

Command palette:
shadcn Command

Fonts:
Geist Sans + Geist Mono
```

When package versions are pinned in the repository, the repository versions win.

Do not silently upgrade major versions during unrelated UI work.

---

# 77. Tailwind rules

Use Tailwind primarily through semantic design tokens.

Good:

```tsx
bg-background
text-foreground
bg-card
text-muted-foreground
border-border
text-primary
bg-primary
ring-ring
```

Avoid feature-level raw palette utilities when a semantic token exists.

Avoid arbitrary values unless they represent a deliberate special-case measurement.

If the same arbitrary value appears repeatedly, make it a token or shared component rule.

---

# 78. CSS rules

Global CSS is reserved for:

- tokens;
- typography;
- application/root behavior;
- base reset;
- theme definitions;
- truly global system shell requirements.

Do not move feature styling into giant global CSS files.

Prefer component-level Tailwind classes and shared variants.

Do not use `!important` as a normal styling technique.

---

# 79. Design tokens are code

Changes to:

```text
color
spacing
radius
typography
shadow
motion
z-index
```

must be treated like API changes to the visual system.

A token change may affect many screens.

Do not edit tokens to fix one badly designed component.

Fix the component unless the token itself is actually wrong globally.

---

# 80. Dead Rose design components

The project should grow a small product-level component vocabulary.

Likely components include:

```text
AppShell
Sidebar
TopBar
PageHeader
SectionHeader
StatusIndicator
HealthBadge
SystemMetric
MetricGroup
NodeRow
OperationProgress
SettingsSection
DangerZone
EmptyState
ErrorState
OfflineState
InlineNotice
TechnicalValue
CopyableValue
KeyValueList
LogViewer
```

Before creating a new product-level component, check whether an existing one already expresses the same semantic pattern.

---

# 81. Naming

Component names should describe semantics, not appearance.

Good:

```text
StatusIndicator
OperationProgress
SettingsSection
NodeRow
```

Bad:

```text
WineBox
GrayPanel
PrettyCard
BigRedButton
LeftThing
```

Visual styling can change.

Semantic meaning is more stable.

---

# 82. No design forks per feature

Features must not create their own mini design systems.

Do not create:

```text
network-button.tsx
storage-button.tsx
update-button.tsx
```

when the difference is purely visual.

Use the shared Button with semantic variants and composed feature components.

---

# 83. Branding usage

Use `Dead Rose OS` when referring to the operating system.

Use `Dead Rose` for the ecosystem/remote management application where appropriate.

Do not accidentally use legacy project names.

UI copy and assets must not contain legacy branding.

---

# 84. Product logo usage

Until a final logo specification exists:

- keep logo usage minimal;
- do not redraw it ad hoc;
- use repository brand assets;
- retain clear space;
- do not apply random gradients/effects;
- do not use the wine color as a glow.

The logo should be most visible on:

- boot;
- login;
- initial setup;
- app shell identity.

It should be less dominant on routine operational screens.

---

# 85. Dark mode surface hierarchy

Recommended conceptual hierarchy:

```text
Background
#0B0B0C

Main panel/card
#111113

Elevated/interactive surface
#171719

Hover / stronger elevated neutral
~ #1D1D20

Border
~ #232326

Strong border/input
#2B2B2F
```

Do not create ten nearly identical surface colors without semantic purpose.

---

# 86. Light mode surface hierarchy

Recommended:

```text
Background
#F7F6F3

Card
#FFFFFF

Secondary surface
#EEECE7

Border
#D7D3CD

Foreground
#1B1918
```

Light mode should feel warm and quiet, not clinical blue-white.

---

# 87. Contrast

Text must remain readable for long technical sessions.

Do not use extremely low-contrast gray text for important content.

Muted text is for:

- secondary metadata;
- descriptions;
- timestamps;
- supplementary information.

Primary values and labels use sufficient foreground contrast.

---

# 88. Live data behavior

Live telemetry should update without causing visual jitter.

Rules:

- reserve stable widths for numeric metrics where possible;
- use Geist Mono for changing numeric values;
- avoid reflow caused by changing digit widths;
- do not animate every metric change;
- do not flash color on every update;
- highlight only meaningful state transitions.

---

# 89. Performance

Dead Rose OS runs as a local system shell.

The UI should remain responsive even while system operations are active.

Avoid:

- unnecessary rerenders;
- huge DOM trees;
- excessive blur effects;
- continuous JavaScript animation loops;
- unnecessary chart redraws;
- rendering thousands of log/table rows without virtualization where needed.

Visual quality does not justify sluggish system control.

---

# 90. Interaction latency

Controls should feel immediate.

When an operation is backend-bound:

1. acknowledge the click immediately with pending state;
2. do not pretend the operation succeeded;
3. show authoritative progress/result.

Example:

```text
Restart
  ↓
Restart requested…
  ↓
Restarting
  ↓
Connection lost as expected
  ↓
Reconnecting
  ↓
Healthy
```

This is better than immediately showing:

```text
Restart successful
```

before the server has restarted.

---

# 91. Connection state

Because the graphical shell depends on Dead Rose services, the shell must have an explicit global connection/health strategy.

The UI should gracefully represent:

```text
Connected
Reconnecting
Backend unavailable
Partial/degraded service
```

Do not crash to a blank screen when a local daemon restarts.

---

# 92. Error boundaries

Major route/surface boundaries should fail gracefully.

If a React rendering error occurs:

- preserve the shell where possible;
- display a controlled error surface;
- provide diagnostics/retry where appropriate;
- log the technical error through the proper application logging path.

Never expose a raw stack trace as the normal user experience.

---

# 93. Security presentation

Sensitive values such as:

- tokens;
- recovery secrets;
- private keys;
- passwords

must never be casually rendered.

When a secret must be shown:

- explicit reveal;
- warning/context;
- limited exposure;
- copy control if appropriate;
- never log it.

Do not use frontend-only hiding as a security boundary.

---

# 94. Screenshots and visual inspection

For major UI work, Codex should visually inspect the rendered result, not judge only from source code.

Review at least:

```text
1920×1080 dark
1280×720 dark
light theme for theme-sensitive shared work
```

For foundational shell/design-system changes, also inspect:

```text
1024×768
```

Look for:

- overflow;
- broken hierarchy;
- cramped text;
- excessive whitespace;
- misaligned baselines;
- clipping;
- poor focus states;
- bad contrast;
- inconsistent radius;
- accidental raw colors.

---

# 95. Definition of Done — UI feature

A UI feature is not done until:

- [ ] It follows this `DESIGN.md`.
- [ ] It uses existing shadcn/shared primitives where appropriate.
- [ ] It introduces no unnecessary dependency.
- [ ] It introduces no arbitrary new visual language.
- [ ] It works in dark mode.
- [ ] It remains valid in light mode where the surface is themeable.
- [ ] It uses Geist Sans / Geist Mono correctly.
- [ ] It uses semantic color tokens.
- [ ] It has clear loading state.
- [ ] It has clear error state.
- [ ] It has an empty state when relevant.
- [ ] It handles backend unavailable state when relevant.
- [ ] It has correct pending behavior for operations.
- [ ] Risky actions wait for authoritative backend confirmation.
- [ ] Keyboard interaction works.
- [ ] Focus is visible.
- [ ] Icon-only controls have accessible names/tooltips where appropriate.
- [ ] Status is not communicated by color alone.
- [ ] Motion is justified.
- [ ] Reduced motion is respected.
- [ ] No fake production data exists.
- [ ] No runtime CDN dependency was introduced.
- [ ] No Ubuntu/legacy branding is visible.
- [ ] Target resolutions were visually checked for major surfaces.
- [ ] Design review/audit skill was used when the task warrants it.

---

# 96. Definition of Done — shared component

A shared component additionally requires:

- [ ] Clear semantic purpose.
- [ ] No feature-specific backend dependency.
- [ ] No unnecessary boolean-prop explosion.
- [ ] All important states represented.
- [ ] Dark/light theme compatibility.
- [ ] Accessible keyboard/focus behavior.
- [ ] Consistent token usage.
- [ ] Reasonable long-content behavior.
- [ ] Story/catalog entry when the component is significant.
- [ ] No duplication of an existing component.

---

# 97. Rules for design iteration

When improving existing UI:

1. preserve product behavior unless behavior is part of the task;
2. identify the actual visual/UX problem;
3. fix hierarchy/spacing/components before adding decoration;
4. reuse tokens;
5. inspect the result;
6. stop when the issue is solved.

Do not respond to “make this better” by adding:

- gradients;
- more shadows;
- more cards;
- more animations;
- more accent color.

Polish often means **removing noise**.

---

# 98. Rule against temporary visual architecture

Do not create a throwaway UI architecture with the intention to “clean it up later”.

A feature may be small in early versions, but implemented pieces should use the intended structure:

```text
real tokens
real shared components
real loading/error states
real backend boundary
real accessibility
real theme behavior
```

It is acceptable for a feature to be absent.

It is not acceptable to implement a knowingly disposable version that will require restructuring later.

---

# 99. When Codex may introduce a new pattern

A new pattern is acceptable only if:

1. no existing Dead Rose pattern solves the problem;
2. no suitable shadcn primitive solves it;
3. the use case is likely to recur or is important enough to justify a dedicated pattern;
4. it fits the existing design system;
5. it has a clear semantic name.

If the new pattern changes the global visual language, update this document as part of the design decision.

---

# 100. Final design summary

When in doubt, Dead Rose should look and feel like this:

```text
Dark-first
Calm
Technical
Precise
Medium-compact
Warm monochrome
Deep wine accent
Geist Sans
Geist Mono for machine data
shadcn/ui
Base UI
Lucide
Subtle borders
Minimal shadow
Very little gradient
No glass by default
No neon
No RGB
No card soup
No fake data
No decorative motion
Fast interactions
Strong system status clarity
Production-quality accessibility
```

The design should make the user think:

> **This is a serious operating system built specifically for my infrastructure.**

Not:

> This is a web dashboard running on top of Linux.

---

# 101. Codex quick-reference

Before a UI task:

```text
1. Read DESIGN.md.
2. Inspect existing patterns.
3. Do not change palette/font/design language.
4. Check shadcn before building a primitive.
5. Use semantic tokens.
6. Keep React away from privileged system operations.
7. Implement real loading/error/offline states.
8. Keep infrastructure actions authoritative, not fake/optimistic.
9. Use motion only when it explains something.
10. Visually inspect the result.
```

Skill selection:

```text
New screen:
frontend-design + ui-ux-pro-max

Design tokens/system:
design-system

shadcn component work:
shadcn

Reusable React architecture:
composition-patterns

Final visual polish:
impeccable

Accessibility / interface audit:
web-design-guidelines

Motion implementation:
animate

Motion audit:
review-animations
```

Visual anchors:

```text
Background        #0B0B0C
Surface           #111113
Elevated          #171719
Warm white        #F4F3F0
Wine              #7A263A
Wine active       #922F49

Font UI           Geist Sans
Font technical    Geist Mono

shadcn style       base-nova
base color         neutral
icons              Lucide
theme              dark-first
```

---

**End of Dead Rose OS design specification.**
