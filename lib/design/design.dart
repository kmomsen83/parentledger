import 'package:flutter/material.dart';

class PLDesign {

/// ================= COLORS =================

static const bgTop = Color(0xff18263a);
static const bgBottom = Color(0xff0b1220);

static const surface = Color(0xff111827);
static const card = Color(0xff0f172a);
static const border = Color(0xff1f2937);

static const primary = Color(0xff3b82f6);
static const success = Color(0xff34d399);
static const warning = Color(0xfff59e0b);
static const danger = Color(0xffef4444);
static const info = Color(0xff38bdf8);
static const ai = Color(0xff8b5cf6);

static const textPrimary = Colors.white;
static const textMuted = Color(0xff94a3b8);

static const Color background = Color(0xff0b1220);

/// ================= SPACING =================

static const s4 = 4.0;
static const s8 = 8.0;
static const s12 = 12.0;
static const s16 = 16.0;
static const s20 = 20.0;
static const s24 = 24.0;
static const s32 = 32.0;
static const s40 = 40.0;

/// ================= RADIUS =================

static const r12 = BorderRadius.all(Radius.circular(12));
static const r16 = BorderRadius.all(Radius.circular(16));
static const r20 = BorderRadius.all(Radius.circular(20));

static const double radiusL = 24;
static const double radiusXL = 32;

/// ================= GRADIENTS =================

static const BoxDecoration screenGradient = BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [bgTop, bgBottom],
),
);

static const LinearGradient primaryGradient = LinearGradient(
colors: [Color(0xff4f7cff), Color(0xff6366f1)],
);

static const LinearGradient glassGradient = LinearGradient(
begin: Alignment.topLeft,
end: Alignment.bottomRight,
colors: [
Color(0x22FFFFFF),
Color(0x08FFFFFF),
],
);

static const LinearGradient cardGradient = LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
Color(0xff111827),
Color(0xff0b1220),
],
);

static const LinearGradient pageGradient = LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
bgTop,
bgBottom,
],
);

static const LinearGradient legalGradient = LinearGradient(
begin: Alignment.topLeft,
end: Alignment.bottomRight,
colors: [
Color(0xff1e293b),
Color(0xff0b1220),
],
);

/// ================= TYPOGRAPHY =================

static const heroTitle = TextStyle(
fontSize: 32,
fontWeight: FontWeight.w800,
color: Colors.white,
);

static const pageTitle = TextStyle(
fontSize: 34,
fontWeight: FontWeight.w500,
fontFamily: "Georgia",
color: Colors.white,
);

static const sectionTitle = TextStyle(
fontSize: 18,
fontWeight: FontWeight.w600,
color: Colors.white,
);

static const body = TextStyle(
fontSize: 14,
color: textMuted,
);

static const caption = TextStyle(
fontSize: 12,
color: Color(0xff64748b),
);

static const statNumber = TextStyle(
fontSize: 24,
fontWeight: FontWeight.w700,
color: Colors.white,
);

static const timelineTitle = TextStyle(
fontSize: 16,
fontWeight: FontWeight.w600,
color: Colors.white,
);

static const timelineMeta = TextStyle(
fontSize: 12,
color: textMuted,
);

static const legalBody = TextStyle(
fontSize: 15,
height: 1.5,
color: Colors.white,
);

static const buttonText = TextStyle(
fontSize: 16,
fontWeight: FontWeight.w700,
color: Colors.white,
);

static const secondaryButtonText = TextStyle(
fontSize: 15,
fontWeight: FontWeight.w600,
color: Colors.white,
);

/// ================= SHADOWS =================

static List<BoxShadow> glowShadow = [
BoxShadow(
color: primary.withOpacity(.35),
blurRadius: 40,
spreadRadius: 2,
),
];

static const List<BoxShadow> softShadow = [
BoxShadow(
color: Colors.black54,
blurRadius: 18,
offset: Offset(0, 10),
)
];

/// ================= DECORATIONS =================

static BoxDecoration elevatedCard = BoxDecoration(
color: card,
borderRadius: r16,
border: Border.all(color: border),
boxShadow: softShadow,
);

static BoxDecoration aiSurface = BoxDecoration(
gradient: LinearGradient(
colors: [
ai.withOpacity(.18),
primary.withOpacity(.10),
],
),
borderRadius: r20,
border: Border.all(color: ai.withOpacity(.4)),
);

static BoxDecoration alertDanger = BoxDecoration(
color: danger.withOpacity(.08),
borderRadius: r16,
border: Border.all(color: danger.withOpacity(.4)),
);

static BoxDecoration alertWarning = BoxDecoration(
color: warning.withOpacity(.08),
borderRadius: r16,
border: Border.all(color: warning.withOpacity(.4)),
);

static BoxDecoration legalCard = BoxDecoration(
gradient: legalGradient,
borderRadius: r20,
border: Border.all(color: const Color(0xff26324d)),
boxShadow: const [
BoxShadow(
color: Colors.black87,
blurRadius: 22,
offset: Offset(0, 14),
)
],
);

static BoxDecoration exportTileDecoration = BoxDecoration(
color: const Color(0xff0f172a),
borderRadius: r20,
border: Border.all(color: const Color(0xff26324d)),
boxShadow: softShadow,
);

static BoxDecoration gradientCard = BoxDecoration(
gradient: legalGradient,
borderRadius: r20,
border: Border.all(color: const Color(0xff26324d)),
boxShadow: softShadow,
);

static BoxDecoration cardDecoration = elevatedCard;

/// ================= COMPONENTS =================

static Widget cardBox({required Widget child, EdgeInsets? padding}) {
return Container(
padding: padding ?? const EdgeInsets.all(20),
decoration: elevatedCard,
child: child,
);
}

static Widget primaryButton({
required String label,
required VoidCallback onTap,
}) {
return GestureDetector(
onTap: onTap,
child: Container(
height: 56,
decoration: const BoxDecoration(
gradient: primaryGradient,
borderRadius: r16,
),
child: Center(child: Text(label, style: buttonText)),
),
);
}

/// ================= SCREEN WRAPPER =================

static Widget screen({
required String title,
required Widget child,
List<Widget>? actions,
}) {
return Container(
decoration: PLDesign.screenGradient,
child: SafeArea(
child: ListView(
padding: const EdgeInsets.all(24),
children: [
Row(
children: [
Expanded(child: Text(title, style: pageTitle)),
if (actions != null) ...actions
],
),
const SizedBox(height: 24),
child,
],
),
),
);
}
}

/// 🔥🔥🔥 THIS IS WHAT FIXES YOUR ERROR 🔥🔥🔥
/// MUST BE OUTSIDE THE CLASS

final ThemeData appTheme = ThemeData(
brightness: Brightness.dark,

scaffoldBackgroundColor: Colors.transparent,

colorScheme: const ColorScheme.dark(
primary: PLDesign.primary,
secondary: PLDesign.info,
surface: PLDesign.surface,
),

appBarTheme: const AppBarTheme(
backgroundColor: Colors.transparent,
elevation: 0,
titleTextStyle: PLDesign.sectionTitle,
iconTheme: IconThemeData(color: Colors.white),
),

cardColor: PLDesign.card,

dividerColor: PLDesign.border,

textTheme: const TextTheme(
bodyMedium: TextStyle(color: Colors.white),
),

elevatedButtonTheme: ElevatedButtonThemeData(
style: ElevatedButton.styleFrom(
backgroundColor: PLDesign.primary,
foregroundColor: Colors.white,
elevation: 0,
padding: const EdgeInsets.symmetric(vertical: 16),
shape: const RoundedRectangleBorder(
borderRadius: BorderRadius.all(Radius.circular(16)),
),
),
),

inputDecorationTheme: InputDecorationTheme(
filled: true,
fillColor: PLDesign.surface,
contentPadding: const EdgeInsets.symmetric(
horizontal: 16,
vertical: 14,
),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(16),
borderSide: const BorderSide(color: PLDesign.border),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(16),
borderSide: const BorderSide(color: PLDesign.border),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(16),
borderSide: const BorderSide(color: PLDesign.primary, width: 1.5),
),
),

snackBarTheme: const SnackBarThemeData(
backgroundColor: PLDesign.card,
contentTextStyle: TextStyle(color: Colors.white),
behavior: SnackBarBehavior.floating,
),
);
