abstract class LivestreamEvent {
  const LivestreamEvent();
}

class LivestreamInitialize extends LivestreamEvent {
  final String channelName;
  final String token;
  final int uid;
  final bool isBroadcaster;

  const LivestreamInitialize({
    required this.channelName,
    this.token = '',
    required this.uid,
    this.isBroadcaster = true,
  });
}

class LivestreamStart extends LivestreamEvent {
  final String? channelName;
  const LivestreamStart({this.channelName});
}

class LivestreamJoinChannel extends LivestreamEvent {
  final String channelName;
  final bool isBroadcaster;

  const LivestreamJoinChannel({
    required this.channelName,
    required this.isBroadcaster,
  });
}

class LivestreamStop extends LivestreamEvent {}

class LivestreamSwitchCamera extends LivestreamEvent {}

class LivestreamToggleMute extends LivestreamEvent {}

class LivestreamChannelJoined extends LivestreamEvent {
  final String channelName;
  final int localUid;
  const LivestreamChannelJoined({
    required this.channelName,
    required this.localUid,
  });
}

class LivestreamUserJoined extends LivestreamEvent {
  final int uid;
  const LivestreamUserJoined(this.uid);
}

class LivestreamUserLeft extends LivestreamEvent {
  final int uid;
  const LivestreamUserLeft(this.uid);
}

class LivestreamErrorOccurred extends LivestreamEvent {
  final String message;
  const LivestreamErrorOccurred(this.message);
}
