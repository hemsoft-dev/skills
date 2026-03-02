---
name: landing-page
description: V1.2 - Expert at creating high-converting, visually stunning landing pages with animated hero sections, floating UI elements, and split-screen auth flows.
---

# Landing Page Expert

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Build memorable landing pages that convert visitors into users through bold visual design, purposeful animation, and clear value proposition.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Core Structure

```
src/components/landing/
├── hero-section.tsx      # Split-layout hero with CTAs
├── floating-widgets.tsx  # 3D animated product previews
├── feature-section.tsx   # Scroll-triggered feature cards
├── cta-section.tsx       # Final call-to-action
├── auth-layout.tsx       # Split-screen login/signup wrapper
├── landing-footer.tsx    # Minimal footer
└── index.ts              # Barrel exports
```

## Hero Section Pattern

Split layout: **Left = Content** | **Right = Visual**

```tsx
<section className="min-h-screen">
  <div className="container grid lg:grid-cols-2 gap-12">
    {/* Left: Badge → Headline → Subheadline → CTAs → Trust indicators */}
    {/* Right: Animated floating elements */}
  </div>
</section>
```

**Content hierarchy:**

1. Badge/eyebrow text (optional)
2. Headline: Bold, gradient text, 2-line max
3. Subheadline: Value prop in 1-2 sentences
4. Dual CTAs: Primary (Get Started) + Secondary (Sign In)
5. Trust indicators: 3 small proof points with colored dots

## Floating Widgets Animation (Framer Motion)

3D orbital animation creates the "rotating spiral" effect:

```tsx
const orbitAnimation = {
  x: [startX, endX],           // Circular path X
  y: [startY, endY],           // Circular path Y  
  rotateY: [0, 360],           // 3D spin
};

const transition = {
  duration: 20,
  repeat: Infinity,
  ease: "linear",
};
```

**Key techniques:**

- `perspective: "1000px"` on container for 3D depth
- `transformStyle: "preserve-3d"` on animated elements
- Staggered delays for multiple items
- Center glow with pulsing `scale` and `opacity`
- Orbital ring border rotating continuously

## Feature Cards with Scroll Animation

```tsx
const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.2 },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 30 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.6, ease: "easeOut" as const },
  },
};

<motion.div
  variants={containerVariants}
  initial="hidden"
  whileInView="visible"
  viewport={{ once: true }}
>
```

## Split-Screen Auth Layout

Login/signup pages use the same floating animation on the left, form on the right:

```tsx
<div className="flex min-h-screen">
  <div className="hidden w-1/2 lg:flex items-center justify-center">
    <FloatingWidgets />
    <Tagline />
  </div>
  <div className="flex w-full lg:w-1/2 items-center justify-center">
    <AuthForm />
  </div>
</div>
```

## Glassmorphism Card Style

```css
bg-card/50 backdrop-blur-xl rounded-xl border shadow-sm
```

For widget previews with gradient accents:

```css
bg-card/60 backdrop-blur-xl bg-gradient-to-br from-{color}-500/20 to-{color}-500/20
```

## Gradient Text

```tsx
<span className="bg-gradient-to-r from-primary to-primary/70 bg-clip-text text-transparent">
  Gradient headline
</span>
```

## Background Effects

Hero section layered backgrounds:

```tsx
{/* Blurred gradient orbs */}
<div className="absolute left-1/4 top-1/4 size-96 rounded-full bg-primary/10 blur-[120px]" />
<div className="absolute bottom-1/4 right-1/4 size-64 rounded-full bg-primary/5 blur-[100px]" />
```

## Motion Entrance Patterns

Staggered content reveal:

```tsx
initial={{ opacity: 0, y: 20 }}
animate={{ opacity: 1, y: 0 }}
transition={{ delay: 0.3 }}  // Increment by 0.1-0.2 per element
```

Scale-in for visual elements:

```tsx
initial={{ opacity: 0, scale: 0.8 }}
animate={{ opacity: 1, scale: 1 }}
transition={{ duration: 0.8, delay: 0.3 }}
```

## Design Principles

1. **One hero animation** — Don't scatter animations everywhere; make the hero unforgettable
2. **Gradient hierarchy** — Primary gradient for headlines, muted for backgrounds
3. **Asymmetric balance** — Content-heavy left, visual-heavy right
4. **Trust indicators** — Colored dots + short phrases beat paragraphs
5. **Dual CTAs** — Primary action (signup) always more prominent than secondary (login)
6. **Viewport once** — Scroll animations fire once, not repeatedly

## Dependencies

```json
{
  "framer-motion": "^12.x"
}
```

## Anti-Patterns

- Centered-only layouts (use split-screen for visual impact)
- Form-first landing (lead with value prop, not login)
- Static hero (animation creates memorability)
- Cluttered trust section (3 indicators max)
- Generic stock imagery (use product UI previews)
- Animation on every element (focus on hero + feature cards)
