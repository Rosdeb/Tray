import 'package:flutter/material.dart';
import 'package:flutter_advanced_switch/flutter_advanced_switch.dart';

class SettingSwitchTile extends StatefulWidget {
  const SettingSwitchTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<SettingSwitchTile> createState() => _SettingSwitchTileState();
}

class _SettingSwitchTileState extends State<SettingSwitchTile> {
  late final ValueNotifier<bool> _controller;

  @override
  void initState() {
    super.initState();
    _controller = ValueNotifier(widget.value);
  }

  @override
  void didUpdateWidget(covariant SettingSwitchTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_controller.value != widget.value) {
      _controller.value = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      onTap: () {
        final newVal = !_controller.value;
        _controller.value = newVal;
        widget.onChanged(newVal);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            AdvancedSwitch(
              controller: _controller,
              width: 38,
              height: 20,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              activeColor: Colors.green,
              inactiveColor: theme.brightness == Brightness.dark
                  ? colors.surfaceContainerHighest
                  : Colors.grey.shade300,
              onChanged: (value) {
                _controller.value = value;
                widget.onChanged(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}
