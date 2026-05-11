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
];

/// Single Socket.IO connection per authenticated session. JWT is presented
/// via handshake auth; the gateway joins the relevant rooms on connect.
class SocketClient {
  SocketClient._(this._socket, this._controller);

  factory SocketClient.connect({
    required String url,
    required String accessToken,
  }) {
    final controller = StreamController<RealtimeEvent>.broadcast();
    final socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(const ['websocket'])
          .setAuth({'token': accessToken})
          .enableForceNew()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

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
