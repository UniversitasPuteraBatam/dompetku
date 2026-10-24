import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(color: context.palette.text, fontWeight: FontWeight.w600),
  );
}
