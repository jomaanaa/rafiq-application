import 'package:flutter/foundation.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

class JitsiService {
  static final _jitsi = JitsiMeet();

  static Future<void> joinCall({
    required int bookingId,
    required String displayName,
    required String userEmail,
    VoidCallback? onCallEnded,
  }) async {
    final roomName = 'rafiq-booking-$bookingId';

    final options = JitsiMeetConferenceOptions(
      serverURL: 'https://meet.ffmuc.net',
      room: roomName,
      configOverrides: {
        'startWithAudioMuted': false,
        'startWithVideoMuted': false,
        'subject': 'RafiQ Interpreter Session',
        'lobby.enabled': false,
        'prejoinPageEnabled': false,
        'roomPasswordNumberOfDigits': false,  // ADD THIS - disables password prompt
        'enableLobbyChat': false,             // ADD THIS
      },
      featureFlags: {
        'unsaferoomwarning.enabled': false,
        'invite.enabled': false,
        'recording.enabled': false,
        'live-streaming.enabled': false,
        'meeting-name.enabled': true,
      },
      userInfo: JitsiMeetUserInfo(
        displayName: displayName,
        email: userEmail,
      ),
    );

    bool _callEndedFired = false;

    final listener = JitsiMeetEventListener(
      conferenceTerminated: (url, error) {
        if (!_callEndedFired) {
          _callEndedFired = true;
          onCallEnded?.call();
        }
      },
      readyToClose: () {
        if (!_callEndedFired) {
          _callEndedFired = true;
          onCallEnded?.call();
        }
      },
    );

    await _jitsi.join(options, listener);
  }
}