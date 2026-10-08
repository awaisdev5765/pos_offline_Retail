import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class ShortcutIndicator extends StatelessWidget {
  final String shortcut;
  final String? description;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;

  const ShortcutIndicator({
    super.key,
    required this.shortcut,
    this.description,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.keyboard,
            size: 14,
            color: textColor ?? const Color(0xFF64748B),
          ),
          const SizedBox(width: 4),
          Text(
            shortcut,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSize ?? 12,
              fontWeight: FontWeight.w600,
              color: textColor ?? const Color(0xFF1E293B),
            ),
          ),
          if (description != null) ...[
            const SizedBox(width: 4),
            Text(
              description!,
              style: TextStyle(
                fontSize: (fontSize ?? 12) - 1,
                color: textColor?.withOpacity(0.7) ?? const Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ShortcutTooltip extends StatelessWidget {
  final Widget child;
  final String shortcut;
  final String? description;

  const ShortcutTooltip({
    super.key,
    required this.child,
    required this.shortcut,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${description ?? 'Shortcut'}: $shortcut',
      child: child,
    );
  }
}

class ShortcutButton extends StatelessWidget {
  final String shortcut;
  final String? description;
  final VoidCallback? onPressed;
  final Widget child;
  final bool enabled;

  const ShortcutButton({
    super.key,
    required this.shortcut,
    this.description,
    this.onPressed,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ShortcutTooltip(
      shortcut: shortcut,
      description: description,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        child: child,
      ),
    );
  }
}

class ShortcutFloatingActionButton extends StatelessWidget {
  final String shortcut;
  final String? description;
  final VoidCallback? onPressed;
  final Widget child;
  final bool enabled;

  const ShortcutFloatingActionButton({
    super.key,
    required this.shortcut,
    this.description,
    this.onPressed,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ShortcutTooltip(
      shortcut: shortcut,
      description: description,
      child: FloatingActionButton(
        onPressed: enabled ? onPressed : null,
        child: child,
      ),
    );
  }
}

class ShortcutCard extends StatelessWidget {
  final String shortcut;
  final String description;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;

  const ShortcutCard({
    super.key,
    required this.shortcut,
    required this.description,
    this.onTap,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: leading ?? const Icon(Icons.keyboard),
        title: Text(description),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShortcutIndicator(shortcut: shortcut),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class ShortcutGrid extends StatelessWidget {
  final List<ShortcutItem> shortcuts;
  final int crossAxisCount;
  final double childAspectRatio;

  const ShortcutGrid({
    super.key,
    required this.shortcuts,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: shortcuts.length,
      itemBuilder: (context, index) {
        final item = shortcuts[index];
        return ShortcutCard(
          shortcut: item.shortcut,
          description: item.description,
          onTap: item.onTap,
          leading: item.leading,
          trailing: item.trailing,
        );
      },
    );
  }
}

class ShortcutItem {
  final String shortcut;
  final String description;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;

  ShortcutItem({
    required this.shortcut,
    required this.description,
    this.onTap,
    this.leading,
    this.trailing,
  });
}

class ShortcutHelpDialog extends StatelessWidget {
  final String title;
  final List<ShortcutItem> shortcuts;

  const ShortcutHelpDialog({
    super.key,
    required this.title,
    required this.shortcuts,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.keyboard, color: Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 300,
        child: ListView.builder(
          itemCount: shortcuts.length,
          itemBuilder: (context, index) {
            final item = shortcuts[index];
            return ShortcutCard(
              shortcut: item.shortcut,
              description: item.description,
              onTap: item.onTap,
              leading: item.leading,
              trailing: item.trailing,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.close'.tr()),
        ),
      ],
    );
  }
}
