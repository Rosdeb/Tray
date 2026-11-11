import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/log_entry.dart';
import '../../providers/app_providers.dart';

class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(appLoggerProvider).entries.reversed.toList(growable: false);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Logs', style: Theme.of(context).textTheme.headlineSmall)),
              OutlinedButton.icon(
                onPressed: () => ref.read(emulatorControllerProvider.notifier).refresh(),
                icon: const Icon(CupertinoIcons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: logs.isEmpty
                ? const Center(child: Text('No logs recorded for this session.'))
                : ListView.separated(
                    itemCount: logs.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _LogTile(entry: logs[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final icon = switch (entry.level) {
      LogLevel.info => CupertinoIcons.info_circle,
      LogLevel.warning => CupertinoIcons.exclamationmark_triangle,
      LogLevel.error => CupertinoIcons.exclamationmark_circle,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(entry.message),
      subtitle: Text(DateFormat.yMMMd().add_jms().format(entry.timestamp)),
    );
  }
}
