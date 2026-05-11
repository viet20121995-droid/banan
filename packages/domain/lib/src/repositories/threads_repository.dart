import 'package:banan_core/banan_core.dart';

import '../entities/thread.dart';

class ThreadDraft {
  const ThreadDraft({
    required this.title,
    required this.body,
    this.imageUrl,
    this.publish = false,
  });

  final String title;
  final String body;
  final String? imageUrl;
  final bool publish;

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
        'publish': publish,
      };
}

abstract class ThreadsRepository {
  /// Public — published threads only, newest first.
  Future<Result<List<Thread>, AppFailure>> published({
    String? storeId,
    int limit = 10,
  });

  /// Merchant — drafts + published.
  Future<Result<List<Thread>, AppFailure>> storeThreads();

  Future<Result<Thread, AppFailure>> get(String id);

  Future<Result<Thread, AppFailure>> create(ThreadDraft draft);

  Future<Result<Thread, AppFailure>> update(String id, ThreadDraft draft);

  Future<Result<void, AppFailure>> delete(String id);
}
