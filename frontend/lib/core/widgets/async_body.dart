import 'package:flutter/material.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/core/widgets/error_state.dart';
import 'package:sprout/core/widgets/loading_state.dart';

class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.isLoading,
    required this.error,
    required this.data,
    required this.onRetry,
    required this.builder,
  });

  final bool isLoading;
  final Object? error;
  final T? data;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    final value = data;
    if (value == null && isLoading) return const LoadingState();

    final failure = error;
    if (value == null && failure != null) {
      final message = failure is AppException
          ? failure.message
          : 'Something went wrong.';
      return ErrorState(message: message, onRetry: onRetry);
    }

    if (value == null) return const LoadingState();
    return builder(value);
  }
}
