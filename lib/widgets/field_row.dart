import 'package:flutter/material.dart';

/// A single labeled text field used throughout the review form.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
