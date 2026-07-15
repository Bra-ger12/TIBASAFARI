import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PageScaffold extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> actions;
  final Widget child;
  final Widget? leading;
  const PageScaffold({
    super.key,
    required this.title,
    this.description,
    this.actions = const [],
    required this.child,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppFonts.sora(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary)),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Text(description!,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textMuted)),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
        const SizedBox(height: 20),
        child,
      ],
    );
  }
}

class SectionCard extends StatelessWidget {
  final String? title;
  final String? description;
  final Widget? action;
  final Widget child;
  final EdgeInsets padding;
  const SectionCard({
    super.key,
    this.title,
    this.description,
    this.action,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title!,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        if (description != null)
                          Text(description!,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  ?action,
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final Widget? value;
  const InfoRow({super.key, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
                letterSpacing: 0.4)),
        const SizedBox(height: 4),
        value ?? const Text('—',
            style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
      ],
    );
  }
}

class LoadingRows extends StatelessWidget {
  final int count;
  const LoadingRows({super.key, this.count = 5});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    );
  }
}

class LoadingCards extends StatelessWidget {
  final int count;
  const LoadingCards({super.key, this.count = 4});
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (int i = 0; i < count; i++)
          Container(
            width: 240,
            height: 112,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      this.description});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.textMuted, size: 24),
          ),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(description!,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textMuted)),
          ],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF2F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: Color(0xFFDC2626), size: 24),
          ),
          const SizedBox(height: 8),
          const Text('Couldn\'t load this page',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
