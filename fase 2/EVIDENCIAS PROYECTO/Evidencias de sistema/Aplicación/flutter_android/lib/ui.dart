import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const navy = Color(0xff10213c);
const teal = Color(0xff2867d8);
const paper = Color(0xffeaf1fb);
const muted = Color(0xff50647f);

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: teal,
    primary: teal,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: paper,
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    height: 66,
    indicatorColor: Color(0xffd4e5ff),
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(color: navy, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    foregroundColor: navy,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xfff7f9fd),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xffdce4f0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xffdce4f0)),
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
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xfffbfdff), Color(0xffeff6ff)],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white),
      boxShadow: const [
        BoxShadow(
          color: Color(0x11274470),
          offset: Offset(0, 4),
          blurRadius: 14,
        ),
      ],
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
      gradient: LinearGradient(
        colors: [Color(0xffe9f0fa), Color(0xffc4dcf6), Color(0xffdce9fa)],
      ),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xd9ffffff),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white),
              ),
              child: child,
            ),
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
            color: navy,
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
                  color: Color(0xffdbe6f4),
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
        color: const Color(0xffdfebff),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: const Color(0xff205bb5), size: 22),
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: navy,
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
            color: navy,
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

void feedback(BuildContext context, Object message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message.toString()),
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
      color: const Color(0xffe7efff),
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
