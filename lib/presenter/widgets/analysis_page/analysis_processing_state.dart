import 'package:flutter/material.dart';

/// A bounded status area remains usable on small screens and large text sizes.
class AnalysisProcessingState extends StatelessWidget {
  const AnalysisProcessingState({
    required this.strings,
    this.onRetry,
    super.key,
  });
  final Map<String, String> strings;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onRetry == null)
            const CircularProgressIndicator()
          else
            const Icon(Icons.error_outline_rounded, size: 32),
          const SizedBox(height: 16),
          Text(
            strings[onRetry == null
                ? 'analysisProcessing'
                : 'analysisProcessingError']!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(strings['analysisProcessingRetry']!),
            ),
          ],
        ],
      ),
    ),
  );
}
