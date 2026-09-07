---
name: Sequoia Fin Desktop
colors:
  surface: '#faf9fe'
  surface-dim: '#dad9df'
  surface-bright: '#faf9fe'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f4f3f8'
  surface-container: '#eeedf3'
  surface-container-high: '#e9e7ed'
  surface-container-highest: '#e3e2e7'
  on-surface: '#1a1b1f'
  on-surface-variant: '#414755'
  inverse-surface: '#2f3034'
  inverse-on-surface: '#f1f0f5'
  outline: '#717786'
  outline-variant: '#c1c6d7'
  surface-tint: '#005bc1'
  primary: '#0058bc'
  on-primary: '#ffffff'
  primary-container: '#0070eb'
  on-primary-container: '#fefcff'
  inverse-primary: '#adc6ff'
  secondary: '#006e28'
  on-secondary: '#ffffff'
  secondary-container: '#6ffb85'
  on-secondary-container: '#00732a'
  tertiary: '#4c4aca'
  on-tertiary: '#ffffff'
  tertiary-container: '#6664e4'
  on-tertiary-container: '#fffbff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d8e2ff'
  primary-fixed-dim: '#adc6ff'
  on-primary-fixed: '#001a41'
  on-primary-fixed-variant: '#004493'
  secondary-fixed: '#72fe88'
  secondary-fixed-dim: '#53e16f'
  on-secondary-fixed: '#002107'
  on-secondary-fixed-variant: '#00531c'
  tertiary-fixed: '#e2dfff'
  tertiary-fixed-dim: '#c2c1ff'
  on-tertiary-fixed: '#0c006a'
  on-tertiary-fixed-variant: '#3631b4'
  background: '#faf9fe'
  on-background: '#1a1b1f'
  surface-variant: '#e3e2e7'
typography:
  display-hero:
    fontFamily: Inter
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.03em
  title-1:
    fontFamily: Inter
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.02em
  title-2:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: -0.015em
  headline:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: -0.01em
  body:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: -0.005em
  body-medium:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
    letterSpacing: -0.005em
  sidebar-item:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
    letterSpacing: -0.005em
  sidebar-header:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.03em
  numeric-data:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
    letterSpacing: 0.01em
  caption:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '400'
    lineHeight: 14px
    letterSpacing: 0em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  window-radius: 12px
  traffic-lights-gap: 8px
  sidebar-width-min: 220px
  sidebar-width-default: 260px
  sidebar-item-height: 32px
  sidebar-item-padding-x: 10px
  sidebar-item-padding-y: 6px
  space-2xs: 2px
  space-xs: 4px
  space-sm: 8px
  space-md: 12px
  space-lg: 16px
  space-xl: 24px
  space-2xl: 32px
  space-3xl: 48px
---

## Brand & Style

This design system delivers an authentic, precision-crafted macOS desktop experience modeled after Apple Human Interface Guidelines and modern macOS Sequoia patterns. Built specifically for personal wealth and asset tracking, the UI projects quiet confidence, institutional trust, and surgical clarity.

The aesthetic philosophy centers on **Modern macOS Vignette & Vibrancy**:
- **Native Materiality:** Translucent acrylic sidebar material with underlying desktop blur (`NSVisualEffectView` aesthetic), paired with an opaque, pristine canvas in the primary workspace.
- **Micro-Delight & Precision:** High pixel density, subtle 1px border dividers (`separatorColor`), and calibrated active selection pills.
- **Information Clarity:** Financial numbers, currency badges, and hierarchy tiers are spaced to allow rapid visual parsing without visual fatigue.
- **Platform Authenticity:** Window chrome with integrated traffic lights (close, minimize, zoom), seamless unified titlebars, and native macOS control physics.

## Colors

The color system directly reflects native macOS system dynamic colors:
- **System Accent (`#007AFF`):** Apple system blue. Utilized for primary navigation selections, focused states, interactive toggles, and primary action buttons.
- **Positive Balance / Growth (`#34C759`):** System green, used for positive yields, active asset badges, and upward liquidity trends.
- **Secondary Accent (`#5856D6`):** System indigo, reserved for specialized investment categories, portfolio allocations, and multi-currency analytics.
- **Neutral System Palette:**
  - Window Background (Content): `#FFFFFF`
  - Sidebar Background: `rgba(246, 246, 248, 0.78)` with `backdrop-filter: blur(28px) saturate(190%)`
  - Label Primary: `#1C1C1E` (system dynamic label)
  - Label Secondary: `#8E8E93` (system dynamic secondaryLabel)
  - Label Tertiary: `#AEAEB2` (system dynamic tertiaryLabel)
  - Window Divider: `rgba(60, 60, 67, 0.12)` (system separator)
  - Traffic Light Close: `#FF5F56`
  - Traffic Light Minimize: `#FFBD2E`
  - Traffic Light Maximize: `#27C93F`

## Typography

Typography adheres to Apple’s typographic scale with strict adherence to system layout rules:
- **Font Stack:** Configured with `Inter` as the robust cross-platform proxy to Apple's San Francisco (`-apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display"`).
- **Tabular Figures:** All currency amounts, balances, and numerical list columns must enforce `font-variant-numeric: tabular-nums` to guarantee aligned decimal and balance values across nested tables and lists.
- **Section Headers:** Sidebar group titles (e.g. `ACCOUNTS`) are rendered in uppercase `sidebar-header` styling with muted secondary label tones.
- **Hero Balances:** Metric totals feature deep bold weights with negative tracking (`-0.03em`) for high visual presence without requiring excessive vertical footprint.

## Layout & Spacing

The layout is architected around the standard macOS **Two-Column Split-View Window Architecture**:

1. **Window Frame & Chrome:**
   - Outer window uses a continuous rounded border (`12px` to `16px`) with hardware-accelerated clipping.
   - Traffic lights are positioned at top-left: `x: 18px, y: 18px`, separated by `8px` center-to-center.
   - Window titlebar height is unified at `52px` seamlessly integrating into the sidebar and main view without harsh structural breaks.

2. **Sidebar Structure:**
   - Default width of `260px` (resizable between `200px` and `320px`).
   - Padding container: `12px` horizontal margin from the window edge.
   - Item row height is fixed at `32px` with a `2px` vertical gap between rows.
   - Nested account indentation is standard `16px` per hierarchy level with disclosure triangles aligned at `8px`.

3. **Content Canvas:**
   - Primary view operates on a fluid layout with comfortable margins (`32px` to `48px`).
   - Center-staged account balances and cards align along an optical grid centered at the 40% vertical mark of the viewport.

## Elevation & Depth

This design system uses macOS macOS Sequoia translucent elevation layers rather than aggressive drop shadows:

- **Window Base Drop Shadow:**
  - Ambient window halo: `0 24px 64px rgba(0, 0, 0, 0.22), 0 4px 12px rgba(0, 0, 0, 0.08)`.
  - Rim stroke: `0.5px solid rgba(255, 255, 255, 0.2)` on dark / `0.5px solid rgba(0, 0, 0, 0.15)` on light.
- **Sidebar Vibrancy:**
  - `rgba(246, 246, 248, 0.72)` combined with background blur `24px` and saturation `180%`.
  - Divider between sidebar and main workspace: `1px solid rgba(60, 60, 67, 0.12)`.
- **Active Navigation Pill:**
  - Solid `#007AFF` accent background with subtle inner highlight: `inset 0 1px 0 rgba(255, 255, 255, 0.18)` and no external shadow. Text and icons turn to solid `#FFFFFF`.
- **Hover States:**
  - Muted interaction overlay: `rgba(0, 0, 0, 0.05)` with `transition: background 0.12s ease-in-out`.
- **Modals & Flyouts:**
  - Native popovers utilize `0 12px 30px rgba(0, 0, 0, 0.14)` with a `0.5px` border line.

## Shapes

The design uses Apple's refined continuous curve geometry (`squircle` / smooth curvature):
- **Window Corners:** `12px` border radius with exact window clipping.
- **Sidebar Selection Pills:** `6px` radius (`rounded-md`), inset by `8px` from sidebar margins for the native floating highlight appearance.
- **Buttons & Control Inputs:** `6px` radius for standard push buttons, search fields, and currency toggles.
- **Badges & Currency Chips:** `4px` subtle radius for currency tags, keeping data dense and clean.
- **Status Avatars / Profile:** Full circle (`9999px`) matching native macOS account pickers in the bottom utility bar.

## Components

### Window Chrome & Traffic Lights
- Three buttons positioned top-left: Close (`#FF5F56`), Minimize (`#FFBD2E`), Fullscreen (`#27C93F`), sized at `12px × 12px` with 1px inset borders.
- Top-right window actions: Glass toggle button for Sidebar Collapse/Expand using standard native glyphs.

### Sidebar Navigation & Hierarchy
- **Active Navigation Item:** Solid `#007AFF` fill, white typography, white icon tinting, 6px border radius, 32px height.
- **Standard Navigation Item:** Transparent fill, `#1C1C1E` typography, `#007AFF` or neutral icon tint, hover background `rgba(0,0,0,0.04)`.
- **Section Headers:** Uppercase, 11px semi-bold, `#8E8E93`, accompanied by an interactive disclosure chevron (`rotate(90deg)` on open).
- **Nested Financial Items:** Indented by `16px`, displaying account title on the left with truncation, accompanied by right-aligned tabular currency labels (e.g. `26000 USD`, `1000 KZT`).

### Metric Display & Balance Cards
- **Hero Balance Display:** Centered stack; caption label (`Total balance` in `#8E8E93`), leading into `40px` bold sum with embedded currency code (`KZT`, `USD`, `EUR`).
- **Cards:** Crisp `#FFFFFF` surface with `1px solid rgba(60, 60, 67, 0.08)` border, padded with `20px`. Zero intrusive elevation.

### Desktop Form Controls & Buttons
- **Push Button Primary:** `#007AFF` background, `#FFFFFF` text, `height: 28px`, `padding: 0 14px`, `font-size: 13px`, font-weight `500`.
- **Push Button Secondary:** `background: rgba(0, 0, 0, 0.05)`, border `0.5px solid rgba(0, 0, 0, 0.1)`, `#1C1C1E` text.
- **Text & Search Inputs:** Inset background `rgba(0, 0, 0, 0.04)`, `1px solid rgba(0, 0, 0, 0.08)`, focus ring `3px solid rgba(0, 122, 255, 0.35)`.

### User Profile Status Bar
- Fixed bottom-left footer in the sidebar: profile picture with status badge, display name (`Yevgeniy`), and settings access gear, separated by a delicate top border (`1px solid rgba(60, 60, 67, 0.08)`).