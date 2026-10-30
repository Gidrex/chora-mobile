import 'package:flutter/material.dart';

import '../app_state.dart';

/// Inherited hand-out for repositories and controllers (T2.2+).
/// Today it carries [AppState]; screens keep constructor injection until
/// the shell migration (T2.6) removes the cross-widget `GlobalKey` calls.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.state, required super.child});

  final AppState state;

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found above this widget');
    return scope!.state;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => state != oldWidget.state;
}
