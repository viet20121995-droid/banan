import 'dart:async';

import 'package:banan_core/banan_core.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Realtime event from the backend gateway. `event` matches the contract
/// defined in `docs/02-api-contract.md` (e.g. `order.created`, `order.status_changed`).
class RealtimeEvent {
  const RealtimeEvent({required this.event, required this.data});
  final String event;
  final Map<String, dynamic> data;
}

const _kEvents = [
  'order.created',
  'order.status_changed',
  'order.kitchen_status_changed',
  'kitchen.batch_updated',
  'payment.updated',
  'notification.new',
  // Realtime catalog sync (M11): merchant writes broadcast these to the
  // `public` room so every client refetches without a manual refresh.
  'catalog.changed',
  'config.changed',
];

/// Single Socket.IO connection. When [accessToken] is null the client
/// connects anonymously (guest) — the gateway still joins it to the `public`
/// room so it receives catalog/config broadcasts. With a token, the gateway
/// also joins the user's role-specific rooms.
class SocketClient {
  SocketClient._(this._socket, this._controller);

  factory SocketClient.connect({
    required String url,
    String? accessToken,
  }) {
    final controller = StreamController<RealtimeEvent>.broadcast();
    final builder = io.OptionBuilder()
        .setTransports(const ['websocket'])
        .enableForceNew()
        .enableReconnection()
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000);
    if (accessToken != null && accessToken.isNotEmpty) {
      builder.setAuth({'token': accessToken});
    }
    final socket = io.io(url, builder.build());

    for (final name in _kEvents) {
      socket.on(name, (data) {
        if (data is Map) {
          controller.add(
            RealtimeEvent(
              event: name,
              data: Map<String, dynamic>.from(data),
            ),
          );
        }
      });
    }
    socket
      ..onConnectError((err) => log('ws').warning('connect error: $err'))
      ..onError((err) => log('ws').warning('error: $err'));

    return SocketClient._(socket, controller);
  }

  final io.Socket _socket;
  final StreamController<RealtimeEvent> _controller;

  Stream<RealtimeEvent> get events => _controller.stream;
  bool get connected => _socket.connected;

  /// Joins the per-order room so the customer's tracking screen receives
  /// fine-grained kitchen status events.
  void subscribeToOrder(String orderId) {
    _socket.emit('order:subscribe', {'orderId': orderId});
  }

  Future<void> dispose() async {
    _socket.dispose();
    await _controller.close();
  }
}
