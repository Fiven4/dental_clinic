import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/payment.dart';

class CellText extends StatelessWidget {
  final String text;
  final double maxWidth;

  const CellText(this.text, {super.key, this.maxWidth = 200});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
  );
}

class TitleCell extends StatelessWidget {
  final String title;
  final bool deleted;

  const TitleCell({super.key, required this.title, required this.deleted});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(title),
          if (deleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'удалена',
                style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
              ),
            ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final AppointmentStatus status;

  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      AppointmentStatus.planned => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      AppointmentStatus.done => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      AppointmentStatus.cancelled => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status.label, style: TextStyle(fontSize: 12, color: fg)),
    );
  }
}

String payMethodLabel(PayMethod m) => m.label;
