import 'package:flutter/material.dart';

/// One short line of feedback; replaces the previous snackbar.
void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
