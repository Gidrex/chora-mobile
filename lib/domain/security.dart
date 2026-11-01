import '../data/models.dart';

/// App-wide gate threshold: notes at or above it need an unlock.
/// [open] additionally locks the whole app at start.
enum SecurityThreshold {
  none('Off', 'Nothing is locked.'),
  open('Everything', 'Unlock the app at start and every note.'),
  restricted('Restricted', 'Unlock restricted and critical notes.'),
  critical('Critical only', 'Unlock only critical notes.');

  const SecurityThreshold(this.label, this.explanation);

  final String label;
  final String explanation;
}

/// True when [level] needs an unlock under [threshold].
bool needsGate(SecurityLevel level, SecurityThreshold threshold) =>
    threshold != SecurityThreshold.none && level.index + 1 >= threshold.index;
