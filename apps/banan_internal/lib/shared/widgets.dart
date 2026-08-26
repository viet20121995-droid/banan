import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final vnDate = DateFormat('dd/MM/yyyy');
final vnDateTime = DateFormat('HH:mm dd/MM/yyyy');
final vnTime = DateFormat('HH:mm');
final vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

/// Standard loading / error / data body for a fetch-once screen.
class FetchBody<T> extends StatelessWidget {
  const FetchBody({
    required this.state,
    required this.builder,
    required this.onRetry,
    super.key,
  });

  /// null = loading; Failure = error; Success = data.
  final Result<T, AppFailure>? state;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s == null) return const Center(child: CircularProgressIndicator());
    return s.when(
      success: builder,
      failure: (f) => ErrorState(message: authFailureMessage(f), onRetry: onRetry),
    );
  }
}

/// Yes/No confirmation. Returns true only on explicit confirm.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Xác nhận',
  bool danger = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return res ?? false;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void showFailure(BuildContext context, AppFailure failure) {
  showSnack(context, failure.message ?? authFailureMessage(failure));
}

StatusIntent qcOutcomeIntent(String? outcome) => switch (outcome) {
      'PASS' => StatusIntent.success,
      'FAIL' => StatusIntent.warning,
      'CRITICAL_FAIL' => StatusIntent.danger,
      _ => StatusIntent.neutral,
    };

String qcOutcomeLabel(String? outcome) => switch (outcome) {
      'PASS' => 'Đạt',
      'FAIL' => 'Không đạt',
      'CRITICAL_FAIL' => 'Critical fail',
      _ => 'Chưa có kết quả',
    };

StatusIntent qcStatusIntent(String status) => switch (status) {
      'COMPLETED' => StatusIntent.success,
      'IN_PROGRESS' => StatusIntent.progress,
      _ => StatusIntent.neutral,
    };

String qcStatusLabel(String status) => switch (status) {
      'DRAFT' => 'Nháp',
      'IN_PROGRESS' => 'Đang chấm',
      'COMPLETED' => 'Hoàn tất',
      _ => status,
    };

String msStatusLabel(String status) => switch (status) {
      'DRAFT' => 'Nháp',
      'ASSIGNED' => 'Đã tạo link',
      'OPENED' => 'Đã mở link',
      'SUBMITTED' => 'Đã nộp',
      'NEEDS_REVISION' => 'Chờ bổ sung',
      'APPROVED' => 'Đã duyệt',
      'REVOKED' => 'Đã thu hồi',
      'EXPIRED' => 'Hết hạn',
      _ => status,
    };

StatusIntent msStatusIntent(String status) => switch (status) {
      'APPROVED' => StatusIntent.success,
      'SUBMITTED' => StatusIntent.info,
      'NEEDS_REVISION' => StatusIntent.warning,
      'REVOKED' || 'EXPIRED' => StatusIntent.danger,
      'OPENED' => StatusIntent.progress,
      _ => StatusIntent.neutral,
    };

String trainingCategoryLabel(String category) => switch (category) {
      'PHA_CHE' => 'Pha chế',
      'CHE_BIEN' => 'Chế biến',
      'ATVSTP' => 'ATVSTP',
      'QUY_DINH' => 'Quy định',
      'DICH_VU_KHACH_HANG' => 'Dịch vụ khách hàng',
      _ => category,
    };

String progressStatusLabel(String status) => switch (status) {
      'NOT_STARTED' => 'Chưa học',
      'IN_PROGRESS' => 'Đang học',
      'COMPLETED' => 'Hoàn thành',
      'EXPIRED' => 'Quá hạn',
      _ => status,
    };

StatusIntent progressStatusIntent(String status) => switch (status) {
      'COMPLETED' => StatusIntent.success,
      'IN_PROGRESS' => StatusIntent.progress,
      'EXPIRED' => StatusIntent.danger,
      _ => StatusIntent.neutral,
    };
