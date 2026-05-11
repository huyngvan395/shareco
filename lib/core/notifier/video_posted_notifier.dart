// core/notifier/video_posted_notifier.dart

import 'package:flutter/material.dart';

class VideoPostedNotifier {
  VideoPostedNotifier._();
  static final instance = VideoPostedNotifier._();

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback cb) => _listeners.add(cb);
  void removeListener(VoidCallback cb) => _listeners.remove(cb);

  void notify() {
    for (final cb in _listeners) {
      cb();
    }
  }
}