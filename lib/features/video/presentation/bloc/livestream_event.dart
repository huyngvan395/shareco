abstract class LivestreamEvent {
  const LivestreamEvent();
}

class LivestreamInitialize extends LivestreamEvent {
  final String channelName;
  final String token;
  final int uid;
  const LivestreamInitialize({
    required this.channelName,
    required this.token,
    required this.uid,
  });
}

class LivestreamStart extends LivestreamEvent {}
class LivestreamStop extends LivestreamEvent {}
class LivestreamSwitchCamera extends LivestreamEvent {}
class LivestreamToggleMute extends LivestreamEvent {}
class LivestreamUserJoined extends LivestreamEvent {
  final int uid;
  const LivestreamUserJoined(this.uid);
}
class LivestreamUserLeft extends LivestreamEvent {
  final int uid;
  const LivestreamUserLeft(this.uid);
}
