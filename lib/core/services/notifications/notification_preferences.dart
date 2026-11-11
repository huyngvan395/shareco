import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences extends ChangeNotifier {
  static const _kMaster = 'notif_pref_master';
  static const _kComments = 'notif_pref_comments';
  static const _kLikes = 'notif_pref_likes';
  static const _kMentions = 'notif_pref_mentions';
  static const _kNewVideos = 'notif_pref_new_videos';
  static const _kLivestreams = 'notif_pref_livestreams';
  static const _kFollows = 'notif_pref_follows';
  static const _kMessages = 'notif_pref_messages';
  static const _kOrdersWallet = 'notif_pref_orders_wallet';

  bool _masterEnabled = true;
  bool _commentsEnabled = true;
  bool _likesEnabled = true;
  bool _mentionsEnabled = true;
  bool _newVideosEnabled = true;
  bool _livestreamsEnabled = true;
  bool _followsEnabled = true;
  bool _messagesEnabled = true;
  bool _ordersWalletEnabled = true;

  bool get masterEnabled => _masterEnabled;
  bool get commentsEnabled => _commentsEnabled;
  bool get likesEnabled => _likesEnabled;
  bool get mentionsEnabled => _mentionsEnabled;
  bool get newVideosEnabled => _newVideosEnabled;
  bool get livestreamsEnabled => _livestreamsEnabled;
  bool get followsEnabled => _followsEnabled;
  bool get messagesEnabled => _messagesEnabled;
  bool get ordersWalletEnabled => _ordersWalletEnabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _masterEnabled = prefs.getBool(_kMaster) ?? true;
    _commentsEnabled = prefs.getBool(_kComments) ?? true;
    _likesEnabled = prefs.getBool(_kLikes) ?? true;
    _mentionsEnabled = prefs.getBool(_kMentions) ?? true;
    _newVideosEnabled = prefs.getBool(_kNewVideos) ?? true;
    _livestreamsEnabled = prefs.getBool(_kLivestreams) ?? true;
    _followsEnabled = prefs.getBool(_kFollows) ?? true;
    _messagesEnabled = prefs.getBool(_kMessages) ?? true;
    _ordersWalletEnabled = prefs.getBool(_kOrdersWallet) ?? true;
    notifyListeners();
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    notifyListeners();
  }

  Future<void> setMasterEnabled(bool v) {
    _masterEnabled = v;
    return _save(_kMaster, v);
  }

  Future<void> setCommentsEnabled(bool v) {
    _commentsEnabled = v;
    return _save(_kComments, v);
  }

  Future<void> setLikesEnabled(bool v) {
    _likesEnabled = v;
    return _save(_kLikes, v);
  }

  Future<void> setMentionsEnabled(bool v) {
    _mentionsEnabled = v;
    return _save(_kMentions, v);
  }

  Future<void> setNewVideosEnabled(bool v) {
    _newVideosEnabled = v;
    return _save(_kNewVideos, v);
  }

  Future<void> setLivestreamsEnabled(bool v) {
    _livestreamsEnabled = v;
    return _save(_kLivestreams, v);
  }

  Future<void> setFollowsEnabled(bool v) {
    _followsEnabled = v;
    return _save(_kFollows, v);
  }

  Future<void> setMessagesEnabled(bool v) {
    _messagesEnabled = v;
    return _save(_kMessages, v);
  }

  Future<void> setOrdersWalletEnabled(bool v) {
    _ordersWalletEnabled = v;
    return _save(_kOrdersWallet, v);
  }

  bool shouldShowPushForType(String type) {
    if (!_masterEnabled) return false;
    switch (type) {
      case 'comment':
      case 'comment_reply':
        return _commentsEnabled;
      case 'like':
      case 'video_like':
      case 'comment_like':
        return _likesEnabled;
      case 'mention':
        return _mentionsEnabled;
      case 'new_video':
        return _newVideosEnabled;
      case 'livestream':
      case 'gift':
        return _livestreamsEnabled;
      case 'follow':
        return _followsEnabled;
      case 'message':
        return _messagesEnabled;
      case 'order':
      case 'new_order':
      case 'order_status':
      case 'wallet':
        return _ordersWalletEnabled;
      default:
        return true;
    }
  }
}

