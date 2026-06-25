---
name: Đỉnh Phong Premium CRM
colors:
  surface: '#fcf9f3'
  surface-dim: '#dcdad4'
  surface-bright: '#fcf9f3'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3ed'
  surface-container: '#f0eee8'
  surface-container-high: '#ebe8e2'
  surface-container-highest: '#e5e2dc'
  on-surface: '#1c1c18'
  on-surface-variant: '#514539'
  inverse-surface: '#31312d'
  inverse-on-surface: '#f3f0ea'
  outline: '#837567'
  outline-variant: '#d5c4b4'
  surface-tint: '#835414'
  primary: '#805211'
  on-primary: '#ffffff'
  primary-container: '#9d6a29'
  on-primary-container: '#fffbff'
  inverse-primary: '#f9ba72'
  secondary: '#645d57'
  on-secondary: '#ffffff'
  secondary-container: '#ebe1d8'
  on-secondary-container: '#6a635d'
  tertiary: '#645a4f'
  on-tertiary: '#ffffff'
  tertiary-container: '#7e7367'
  on-tertiary-container: '#fffbff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffddba'
  primary-fixed-dim: '#f9ba72'
  on-primary-fixed: '#2b1700'
  on-primary-fixed-variant: '#663d00'
  secondary-fixed: '#ebe1d8'
  secondary-fixed-dim: '#cfc5bd'
  on-secondary-fixed: '#201b16'
  on-secondary-fixed-variant: '#4c4640'
  tertiary-fixed: '#efe0d1'
  tertiary-fixed-dim: '#d2c4b6'
  on-tertiary-fixed: '#211a11'
  on-tertiary-fixed-variant: '#4f453b'
  background: '#fcf9f3'
  on-background: '#1c1c18'
  surface-variant: '#e5e2dc'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  title-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 48px
  sidebar-width: 280px
  container-max: 1440px
---

## Brand & Style
This design system is tailored for the high-end, artisanal beef industry, where tradition meets modern efficiency. The aesthetic is "Frosted Cream"—a sophisticated blend of **Minimalism** and **Glassmorphism**. It evokes a sense of heritage through a warm, organic color palette, while maintaining a cutting-edge feel through translucent layers and precise typography.

The target audience consists of luxury estate managers and wholesale distributors who value clarity, exclusivity, and tactile quality. The UI should feel airy yet grounded, using soft blurs and subtle textures to simulate a premium boutique experience rather than a cold, industrial tool.

## Colors
The palette is rooted in the "Butcher Gold" primary accent, representing quality and excellence. The base of the application utilizes "Warm Ivory" to reduce eye strain and provide a more natural, parchment-like canvas compared to pure white. 

- **Primary (#B9823F):** Used for key call-to-actions, active states, and heritage-focused highlights.
- **Surface Layering:** The sidebar uses a deeper ivory (#F4EDE2) to provide structural hierarchy.
- **Typography:** Charcoal Brown (#241F1A) ensures high legibility with a softer edge than black, while Warm Gray Brown (#7A6F63) is reserved for secondary metadata and inactive states.

## Typography
The system uses **Inter** exclusively to maintain a systematic, professional, and utilitarian feel. To offset the organic warmth of the colors, the typography remains strictly modern and clean.

- **Headlines:** Use tighter letter-spacing and semi-bold weights to create a sense of authority.
- **Body Text:** Standard weight with generous line heights to ensure readability during long administrative tasks.
- **Labels:** Uppercase styling is recommended for small labels (e.g., SKU numbers, status badges) to improve scannability.

## Layout & Spacing
The layout follows a **Fixed Grid** philosophy for the main content area, centered within the viewport once the sidebar is accounted for.

- **Grid:** 12-column system for desktop with 24px gutters.
- **Margins:** 32px page padding for desktop, scaling down to 16px for mobile.
- **Sidebar:** A fixed-width left navigation bar at 280px provides the primary anchor for the application.
- **Rhythm:** All spatial relationships are multiples of 4px, emphasizing a rigorous, professional structure.

## Elevation & Depth
Depth is achieved through "Frosted Cream" glassmorphism rather than heavy shadows.

- **Surface Tiers:** The base level is #FAF7F1. Overlays (cards, modals) use `rgba(255, 255, 255, 0.68)` with a `blur(16px)` to create a sense of light passing through dense cream.
- **Shadows:** Shadows should be minimal and "tinted." Instead of grey, use a soft brown-tinted shadow (`rgba(36, 31, 26, 0.04)`) with a high spread and low opacity to maintain the warm aesthetic.
- **Borders:** All elevated elements must have a 1px solid border in #E3D8CA to define their boundaries against the warm background.

## Shapes
The design system employs a "Rounded" language to communicate approachability and luxury. 

- **Cards & Modals:** Use a consistent 20px (1.25rem) radius to match the "Frosted Cream" component style.
- **Buttons & Inputs:** Follow the `rounded-lg` (1rem) standard.
- **Small Elements:** Tooltips and tags should use `rounded-sm` (0.25rem) to maintain precision at smaller scales.

## Components

### Navigation (Sidebar)
- **Inactive Items:** Text color #7A6F63, transparent background.
- **Active State:** Background #F3E3CF, Text #9F6D33. A 4px vertical border in Butcher Gold (#B9823F) must be placed on the absolute left edge of the active item.
- **Hover State:** Background `rgba(185, 130, 63, 0.08)`.

### Buttons
- **Primary:** Solid #B9823F background, #FFFFFF text. Hover state shifts to #9F6D33.
- **Secondary (Ghost):** 1px border #E3D8CA, text #241F1A. 
- **Shape:** All buttons should have a 1rem (16px) border radius.

### Cards (Frosted Cream)
- **Background:** `rgba(255, 255, 255, 0.68)`
- **Effect:** `backdrop-filter: blur(16px)`
- **Border:** 1px solid #E3D8CA
- **Radius:** 20px
- **Shadow:** 0px 4px 20px rgba(122, 111, 99, 0.08)

### Input Fields
- **Default:** Background #FFFFFF, border 1px solid #E3D8CA, 8px padding.
- **Focus:** Border color #B9823F with a 2px outer glow of `rgba(185, 130, 63, 0.2)`.

### Specialized Components
- **Status Chips:** High-quality beef grading badges (e.g., A5, Prime) should use the primary accent color with gold-tinted backgrounds.
- **Data Tables:** Use #F4EDE2 for header rows to distinguish from the "Frosted Cream" card body.