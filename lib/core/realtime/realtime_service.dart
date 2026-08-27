import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';

/// The server's live channel, as a broadcast stream of decoded events.
///
/// The app already depended on `socket_io_client` and never imported it, and
/// the backend already ran a gateway that nothing could emit through. Both
/// halves existed and neither was connected, which is why a posted ride only
/// appeared after a manual refresh.
///
/// One socket for the whole app rather than one per screen. The connection is
/// authenticated in the handshake, so opening several would mean several
/// verifications of the same token, and a feed that reconnects every time a
/// screen is pushed.
class RealtimeService {
  RealtimeService(this._storage);

  final SecureStorage _storage;

  io.Socket? _socket;
  final _events = StreamController<RealtimeEvent>.broadcast();

  Stream<RealtimeEvent> get events => _events.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Opens the connection, or does nothing if one is already open.
  ///
  /// Silent on failure by design. Live updates are an improvement on the feed,
  /// not a precondition for it — if the socket never connects, pull-to-refresh
  /// still works and the user is not told about a subsystem they did not ask
  /// for.
  Future<void> connect() async {
    if (_socket != null) return;

    final token = await _storage.readAccessToken();
    if (token == null) return;

    final socket = io.io(
      // The gateway is namespaced; the origin alone connects to `/` and is
      // silently accepted, then never receives a single ride event.
      '${AppConstants.wsUrl}/rides',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          // Reconnection is the normal case, not the exception: Android
          // suspends sockets whenever the app goes to background.
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .build(),
    );

    socket.onAny((event, data) {
      if (data is Map) {
        _events.add(
          RealtimeEvent(event, Map<String, dynamic>.from(data)),
        );
      }
    });

    // The token is read once and baked into the handshake options, so an
    // automatic reconnect after the access token has been refreshed replays
    // the expired one and is rejected — forever, quietly, with the feed simply
    // never updating again. Rebuilding the socket re-reads storage.
    socket.onConnectError((_) {
      if (_reauthenticating) return;
      _reauthenticating = true;
      unawaited(
        reconnect().whenComplete(() => _reauthenticating = false),
      );
    });

    _socket = socket;
  }

  /// Guards against the reconnect storm of a failure that is not about auth:
  /// without it, each failed attempt would tear down and rebuild the socket,
  /// which fails again immediately.
  bool _reauthenticating = false;

  /// Drops the connection — on sign-out, when the token is no longer valid.
  Future<void> disconnect() async {
    _socket?.dispose();
    _socket = null;
  }

  /// Reconnects with whatever token is current. Used after a refresh, since
  /// the handshake carries the old one and the server will not re-read it.
  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    unawaited(_events.close());
  }
}

/// One server message: its name, and its decoded body.
class RealtimeEvent {
  const RealtimeEvent(this.name, this.data);

  final String name;
  final Map<String, dynamic> data;
}

/// Event names the server sends. String literals scattered across notifiers
/// are the kind of thing that silently stops matching after a rename.
abstract final class RealtimeEvents {
  /// A ride was posted that this user is entitled to see.
  static const rideCreated = 'ride:created';

  /// A ride this user is on moved forward — started, confirmed, completed.
  /// Refreshes whatever is on screen; never moves anyone.
  static const rideUpdated = 'ride:updated';

  /// Both sides confirmed the trip is over. Navigates, to the rating form.
  static const rideCompleted = 'ride:completed';

  /// A matched ride was called off before it started. Navigates, because the
  /// screen the recipient is on is now about a ride that will not happen.
  static const rideCancelled = 'ride:cancelled';

  /// This user's request was accepted. The one event that navigates, because
  /// it is the one where both people need to end up in the same place.
  static const rideMatched = 'ride:matched';
}
