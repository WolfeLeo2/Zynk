# Zynk Design System (v2.0)

## 1. Visual Identity: "Playful Precision"
**Target Audience:** Gen-Z / Millennial SME Owners (20s - 30s).
**Vibe:** A professional financial tool that feels as tactile and engaging as a consumer social app. High utility, low anxiety. "It works like a Swiss Watch but looks like a Toy."

### Inspiration Sources
*   **Playfulness:**
    *   **Zenly (RIP):** The gold standard for "squishy" UI, rubber-banding lists, and joyous interactions.
    *   **Cash App:** Bold, confident, and simple. Uses scale and roundedness to make money feel accessible.
    *   **Duolingo:** The mastery of "Success States" (sound, animation, haptics) to make chores fun.
*   **Utility/POS:**
    *   **Shopify POS:** Clean, grid-based, professional.
    *   **Linear:** For the "Command Palette" and keyboard-first density in the admin dashboard.

### Micro-Interactions (The "Juice")
1.  **The "Squish":** All buttons scale down (`scale: 0.95`) on press using a spring curve.
2.  **Staggered Entry:** Lists don't just appear; items slide in one by one (10ms delay per item).
3.  **Haptic Success:** Adding a new stock item gives a heavy impact haptic feedback.
4.  **Bouncy Sheets:** Bottom sheets over-scroll and bounce back like a physical card.

---

## 2. Token-Based Architecture

We will move away from raw `Color(0xFF...)` usage in widgets. Instead, we define **Semantic Tokens**.

### A. Color Palette (The "Vibrant" Update)
*   **Primary Brand:** `Electric Blue` (Core action)
*   **Secondary Brand:** `Neon Lime` (Success / Money / Growth)
*   **Accent:** `Hot Pink` (Notifications / Alerts / "Love" moments)
*   **Backgrounds:**
    *   `Midnight`: deeply desaturated cool blue-black (Not pure #000).
    *   `Surface`: slightly lighter cool grey-blue.
    *   `SurfaceHighlight`: for hover states.

### B. Semantic Tokens (Usage)
*   `bg.canvas`: The absolute background of the app.
*   `bg.surface`: Cards, sheets, panels.
*   `bg.surface.subtle`: Secondary areas within cards.
*   `text.primary`: High contrast (nearly white).
*   `text.muted`: Low contrast (grey-blue).
*   `border.subtle`: For dividers (low opacity).
*   `border.focus`: High visibility selection ring.

### C. Typography
*   **Headings (Display):** **Clash Display** (Variable Font Asset).
    *   *Why?* You added it! It's bold, quirky, and authoritative.
    *   *Usage:* Headlines, Big Stats, Empty States.
*   **Body (UI):** **Outfit** (Google Fonts).
    *   *Why?* It is geometric, modern, and highly legible for numbers/data (crucial for pricing). It feels cleaner and more "neutral-but-friendly" than Google Sans.
    *   *Constraint:* **Google Sans Flex** will be kept as a fallback or for specific "Brand" illustrations, but Outfit is the workhorse.

---

## 3. Theme Implementation Strategy

### Do we define Card/Text Themes?
**YES.**
Defining `cardTheme`, `inputDecorationTheme`, etc., in the global `ThemeData` is critical for:
1.  **Consistency:** Every default `Card` looks correct without parameters.
2.  **Maintenance:** Change the `borderRadius` in one place, update the whole app.
3.  **Clean Code:** `TextField()` vs `TextField(decoration: InputDecoration(border: OutlineInputBorder(...)))` x 100 files.

### The `AppTheme` Class Structure
```dart
class AppTheme {
  /// 1. Primitive Tokens (Private)
  static const _brandBlue = Color(0xFF2E69FF);
  // ...

  /// 2. Semantic Tokens (Public - via ThemeExtension if needed, or static getters)
  static Color get canvas => ...

  /// 3. Theme Factory
  static ThemeData get darkTheme => ThemeData(
    // ...
    extensions: [
      ZynkColors(
        success: _neonLime,
        danger: _hotPink,
        // ...
      ),
    ],
  );
}
```

---

## 4. Component Styling Rules (The "Playful" Touch)

*   **Borders:**
    *   Standard Radius: `16px` (Mobile friendly).
    *   Small Radius: `8px` (Inner elements).
    *   Pill Shape: `100px` (Buttons, Tags).
*   **Depth:**
    *   Avoid heavy drop shadows. Use **Inner Glows** or **Outlines** to define separation.
    *   "Glassmorphism" for floating overlays (Store switcher, bottom nav).
*   **Motion:**
    *   All interactions use **Spring** curves (bouncy), not just "Ease In/Out".

## 5. Next Steps
1.  Add `google_fonts` (or assets) for Clash Display / Outfit.
2.  Refactor `app_theme.dart` to use this new architecture.
3.  Create a "Theme Gallery" page to verify the new look.
