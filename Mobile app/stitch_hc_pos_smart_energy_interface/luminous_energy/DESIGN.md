---
name: Luminous Energy
colors:
  surface: '#0b1326'
  surface-dim: '#0b1326'
  surface-bright: '#31394d'
  surface-container-lowest: '#060e20'
  surface-container-low: '#131b2e'
  surface-container: '#171f33'
  surface-container-high: '#222a3d'
  surface-container-highest: '#2d3449'
  on-surface: '#dae2fd'
  on-surface-variant: '#c1c7d3'
  inverse-surface: '#dae2fd'
  inverse-on-surface: '#283044'
  outline: '#8b919d'
  outline-variant: '#414751'
  surface-tint: '#a4c9ff'
  primary: '#a4c9ff'
  on-primary: '#00315d'
  primary-container: '#60a5fa'
  on-primary-container: '#003a6b'
  inverse-primary: '#0060ac'
  secondary: '#4de082'
  on-secondary: '#003919'
  secondary-container: '#00b55d'
  on-secondary-container: '#003e1c'
  tertiary: '#ffb954'
  on-tertiary: '#452b00'
  tertiary-container: '#d8952d'
  on-tertiary-container: '#513200'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#d4e3ff'
  primary-fixed-dim: '#a4c9ff'
  on-primary-fixed: '#001c39'
  on-primary-fixed-variant: '#004883'
  secondary-fixed: '#6dfe9c'
  secondary-fixed-dim: '#4de082'
  on-secondary-fixed: '#00210c'
  on-secondary-fixed-variant: '#005227'
  tertiary-fixed: '#ffddb4'
  tertiary-fixed-dim: '#ffb954'
  on-tertiary-fixed: '#291800'
  on-tertiary-fixed-variant: '#633f00'
  background: '#0b1326'
  on-background: '#dae2fd'
  surface-variant: '#2d3449'
typography:
  headline-xl:
    fontFamily: Manrope
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Manrope
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Manrope
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
  headline-md:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Manrope
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Manrope
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  container-padding: 24px
  stack-gap: 16px
  grid-gutter: 16px
  card-padding: 24px
---

## Brand & Style
The design system focuses on a high-end, futuristic, yet approachable interface for home energy management. It employs a sophisticated **Glassmorphic** style set against a deep, immersive environment. The target audience expects a premium tool that feels intelligent and calm, turning complex data into a serene visual experience.

The aesthetic is defined by "soft tech"—blending technical precision with organic, rounded forms. It avoids the harshness of traditional dashboards in favor of a layered, translucent ecosystem that mimics the flow of energy itself.

## Colors
The palette is rooted in a deep navy-to-indigo foundation to provide maximum contrast for translucent glass layers.

- **Solar (Amber/Gold):** Used for energy generation and positive accumulation.
- **Battery (Emerald):** Denotes storage health and sustainable efficiency.
- **Grid (Cool Blue):** Represents external connectivity and standard utility flow.
- **Consumption (Violet):** Dedicated to usage metrics and appliance activity.
- **Critical (Coral):** Reserved for alerts, high-load warnings, or outages.

All colors should be applied with high saturation to ensure they "glow" when placed behind or atop frosted surfaces.

## Typography
Manrope is utilized for its modern, geometric construction and slightly rounded terminals, which complement the "soft-tech" brand personality. 

- **Headlines:** Use tight letter-spacing and bold weights to anchor the glass cards. 
- **Numerical Data:** For energy readings (kWh, %), use `headline-xl` or `headline-lg` with medium weights to ensure high legibility against blurred backgrounds.
- **Labels:** Use `label-sm` in uppercase for category headers to provide a structured, organized feel to data-heavy views.

## Layout & Spacing
The system uses a fluid vertical stack for mobile and a 12-column grid for tablet/desktop. 

- **Margins:** Consistent 24px outer margins provide breathable space for the glowing card edges.
- **Grouping:** Use 16px gaps between related energy metrics and 32px gaps between distinct functional sections (e.g., between "Live Flow" and "Historical Data").
- **Adaptation:** On mobile, cards span the full width of the safe area. On tablet/desktop, cards cluster into functional zones (Generation, Storage, Usage) to minimize eye travel.

## Elevation & Depth
Depth is created through transparency and refraction rather than traditional black shadows.

- **Surface:** All primary containers use a background of `rgba(255, 255, 255, 0.06)` with a `backdrop-filter: blur(12px)`.
- **Borders:** Every glass element must have a 1px solid border of `rgba(255, 255, 255, 0.15)` to define its edges against the dark background.
- **Glows:** Interactive elements (active buttons or status rings) use a colored outer glow (`box-shadow`) matching the semantic color of the data, with a 15-20px spread at 30% opacity.
- **Layering:** Background "orbs" of soft color (indigo and teal) should be placed behind the glass layers to create a sense of three-dimensional space.

## Shapes
The shape language is extremely soft and continuous. 

- **Cards:** Use a radius of 28px for large dashboard containers.
- **Buttons & Chips:** Always use pill-shaped (fully rounded) ends to evoke a friendly, touch-optimized feel.
- **Selection States:** Use "squircle" or high-radius inner containers (16px) for items nested within the main glass cards.

## Components

- **Glass Cards:** The primary container. Features a 1px top-weighted highlight and 24px internal padding. Content should be strictly aligned to a vertical axis.
- **Pill Buttons:** High-contrast backgrounds (using semantic colors). On hover/active, increase the outer glow intensity.
- **Segmented Toggles:** A frosted glass track with a secondary glass "pill" that slides behind the text. The active segment should have a subtle 1px border.
- **Progress Rings:** Use a 12px stroke width with rounded caps. The track is `rgba(255,255,255,0.1)`, and the progress fill is a linear gradient of the respective semantic color.
- **Bottom Navigation:** A floating frosted bar with 32px radius. The active state is indicated by a glowing dot and a subtle vertical shift of the icon.
- **Input Fields:** Semi-transparent wells with 20px radius. The border color changes to the Primary (Grid) color upon focus, accompanied by a soft glow.