import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../state/providers.dart';
import 'theme.dart';

/// "< TODAY >" header shared by Dashboard and Log.
class DateSwitcher extends ConsumerWidget {
  const DateSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final date = ref.watch(selectedDateProvider);
    final today = DateUtils.dateOnly(DateTime.now());
    final diff = date.difference(today).inDays;
    final label = switch (diff) {
      0 => 'Today',
      -1 => 'Yesterday',
      1 => 'Tomorrow',
      _ => DateFormat('EEE d MMM').format(date),
    };
    final n = ref.read(selectedDateProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(onPressed: () => n.shift(-1), icon: Icon(Icons.chevron_left, color: t.ink)),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: today.add(const Duration(days: 365)),
            );
            if (picked != null) n.set(picked);
          },
          child: Text(label.toUpperCase(), style: NType.mono(13, t.ink, weight: FontWeight.w700)),
        ),
        IconButton(onPressed: () => n.shift(1), icon: Icon(Icons.chevron_right, color: t.ink)),
      ],
    );
  }
}
