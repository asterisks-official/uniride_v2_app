import 'dart:async';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../shared/widgets/app_snack.dart';
import '../di/providers.dart';
import '../router/app_router.dart';
import 'realtime_service.dart';

/// Makes the other phone buzz, and moves it where it needs to be.
///
/// The person who accepted a request is already on the ride — this is for the
/// other one, who could be anywhere in the app and would otherwise have to be
/// told to go and look. Two people about to meet in traffic should be reading
/// the same screen.
///
/// Lives above the router rather than on any screen, because the whole point
/// is that the recipient is not on the screen that would hear it. Watched once
/// from the app root; watching it anywhere else would open a second listener
/// and navigate twice.
final realtimeNavigatorProvider = Provider<void>((ref) {
  final realtime = ref.watch(realtimeServiceProvider);
  unawaited(realtime.connect());

  final sub = realtime.events.listen((event) {
    // `ride:updated` is the only event the server sends to one side alone —
    // the rider starting, the passenger confirming the start. It moves nobody
    // and needs no guard: if it arrived, the *other* person did something.
    //
    // A buzz rather than a banner because of where the phones are. This is a
    // bike, in traffic, and the person being told is wearing a helmet with the
    // handset in a pocket. A screen they are not looking at cannot tell them
    // anything.
    if (event.name == RealtimeEvents.rideUpdated) {
      HapticFeedback.mediumImpact();
      return;
    }

    // The only two events that move anyone. Both are moments where the two
    // people need to be on the same screen at the same time, which is exactly
    // what an ordinary state change is not.
    final target = switch (event.name) {
      RealtimeEvents.rideMatched => '/rides/{id}',
      // Payment first, rating second. The money is settled on the pavement
      // in the half-minute after the ride ends; asking for stars before the
      // fare has changed hands puts the two in the wrong order.
      RealtimeEvents.rideCompleted => '/rides/{id}/pay',
      // Nowhere on the ride: it is not happening. Back to the feed, which is
      // the only useful thing to do next — find another one.
      RealtimeEvents.rideCancelled => '/home',
      _ => null,
    };
    if (target == null) return;

    final id = event.data['id'];
    if (id is! String || id.isEmpty) return;

    final router = ref.read(routerProvider);
    final path = target.replaceFirst('{id}', id);

    if (event.name == RealtimeEvents.rideCancelled) {
      _announceCancellation(ref, event.data);
    }

    // Either party may already be on the destination — the requester who
    // stayed on the ride page after sliding, or whoever confirmed completion
    // last and was navigated a moment earlier. Pushing again would stack a
    // second copy and put a back button between them and the app.
    final here = router.routerDelegate.currentConfiguration.uri.path;
    if (here == path) return;

    // After the guard, so it fires for the person being told and not for the
    // one who did it — whoever acted has already arrived under their own
    // steam and felt the slider's own haptic on the way. Two buzzes for one
    // action reads as a stutter.
    //
    // `vibrate`, not an impact: matched, ended and cancelled are the three
    // things worth noticing from inside a pocket.
    HapticFeedback.vibrate();

    // `go`, not `push`, for a cancellation: the ride's screens are behind it
    // in the stack and every one of them is now about something that is not
    // going to happen. Leaving a back button to them is an invitation to sit
    // on a dead "you're matched" page.
    if (event.name == RealtimeEvents.rideCancelled) {
      router.go(path);
    } else {
      router.push(path);
    }
  });

  ref.onDispose(sub.cancel);
});

/// Says who called it off, and why if they said.
///
/// The same event reaches both people, so the wording is chosen here rather
/// than on the server: telling someone "Rahim cancelled the ride" when they
/// are Rahim reads as a bug.
void _announceCancellation(Ref ref, Map<String, dynamic> ride) {
  final auth = ref.read(authNotifierProvider);
  final me = auth is Authenticated ? auth.user.id : null;

  // Only the creator can cancel, so the creator is who did it.
  final creator = ride['creator'];
  final byMe = creator is Map && creator['id'] == me;
  final name = creator is Map ? creator['name'] as String? : null;

  final reason = ride['cancelReason'] as String?;
  final tail = (reason != null && reason.trim().isNotEmpty)
      ? ' — ${reason.trim()}'
      : '';

  showGlobalSnack(
    byMe
        ? 'Ride cancelled.$tail'
        : '${name ?? 'The other rider'} cancelled the ride.$tail',
    isError: !byMe,
  );
}
