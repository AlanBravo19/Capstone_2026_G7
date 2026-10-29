import 'package:flutter/material.dart';

const navy = Color(0xff112a36);
const teal = Color(0xff087f80);
const paper = Color(0xfff3f7f6);
const muted = Color(0xff657a80);

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: teal,
    primary: teal,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: paper,
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    foregroundColor: navy,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xfff6f9f8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xffdae4e2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xffdae4e2)),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xffdce7e4)),
    ),
    child: child,
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
      color: const Color(0xffe6f3ee),
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
