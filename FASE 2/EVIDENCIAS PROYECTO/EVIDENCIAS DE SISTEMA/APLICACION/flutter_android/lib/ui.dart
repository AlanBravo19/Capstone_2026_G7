import 'package:flutter/services.dart';

import 'package:flutter/material.dart';

const navy = Color(0xff10213c);
const teal = Color(0xff8ec9ff);
const paper = Color(0xff10151e);
const ink = Color(0xfff1f5fc);
const muted = Color(0xffaab8cc);
const cardSurface = Color(0xff191f2b);
const raisedSurface = Color(0xff222c3b);
const outline = Color(0xff343f51);
const blueHighlight = Color(0xff253850);

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Manrope',
  brightness: Brightness.dark,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: teal,
        brightness: Brightness.dark,
        primary: teal,
        secondary: const Color(0xffb7aff1),
        surface: cardSurface,
      ).copyWith(
        onPrimary: paper,
        onSurface: ink,
        onSurfaceVariant: muted,
        outline: outline,
      ),
  scaffoldBackgroundColor: paper,
  dividerColor: outline,
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    height: 63,
    indicatorColor: blueHighlight,
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    foregroundColor: ink,
    centerTitle: false,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: SystemUiOverlayStyle.light,
  ),
  listTileTheme: const ListTileThemeData(iconColor: teal, textColor: ink),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: raisedSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: outline),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
);

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: cardSurface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: outline),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class GlassDock extends StatelessWidget {
  final Widget child;
  const GlassDock({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: paper,
      border: Border(top: BorderSide(color: outline)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xf018202c),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: outline),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class ActionGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const ActionGroup({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 9),
        child: Text(
          title,
          style: const TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -.35,
          ),
        ),
      ),
      Panel(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0)
                const Divider(
                  height: 1,
                  indent: 66,
                  endIndent: 12,
                  color: outline,
                ),
              children[index],
            ],
          ],
        ),
      ),
    ],
  );
}

class ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? detail;
  final VoidCallback onTap;
  const ActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    leading: Container(
      width: 39,
      height: 39,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: blueHighlight,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: teal, size: 22),
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: ink,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
    ),
    subtitle: detail == null
        ? null
        : Text(detail!, style: const TextStyle(color: muted, fontSize: 13)),
    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: muted),
    onTap: onTap,
  );
}

class SectionTitle extends StatelessWidget {
  final String title, eyebrow;
  const SectionTitle(this.title, {super.key, this.eyebrow = ''});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow.isNotEmpty)
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              color: teal,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: ink,
            letterSpacing: -.7,
          ),
        ),
      ],
    ),
  );
}

class Note extends StatelessWidget {
  final String text;
  const Note(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: muted, height: 1.5),
    ),
  );
}

class FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  const FormSection(this.title, {super.key, required this.icon});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 16),
    child: Row(
      children: [
        Icon(icon, color: teal, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ),
      ],
    ),
  );
}

void feedback(BuildContext context, Object message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message is PlatformException
            ? message.message ??
                  'Android no pudo completar la operación (${message.code}).'
            : message.toString(),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Widget gap([double size = 16]) => SizedBox(height: size);
String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Completa este dato' : null;

class StateChip extends StatelessWidget {
  final String text;
  const StateChip(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: blueHighlight,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text.replaceAll('_', ' '),
      style: const TextStyle(
        color: teal,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
