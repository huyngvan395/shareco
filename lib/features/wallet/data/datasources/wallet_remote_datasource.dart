// features/wallet/data/datasources/wallet_remote_datasource.dart

import '../../../../core/services/supabase/index.dart';

class WalletSummary {
  final int coinBalance;
  final int earningsBalance;

  const WalletSummary({
    required this.coinBalance,
    required this.earningsBalance,
  });

  static const int minWithdrawCoins = 1000;
  static const int vndPerCoin = 100; // 1 xu = 100 VNĐ -> 1.000 xu = 100.000 VNĐ

  int get withdrawableVnd => coinBalance * vndPerCoin;
  bool get canWithdraw => coinBalance >= minWithdrawCoins;

  WalletSummary copyWith({
    int? coinBalance,
    int? earningsBalance,
  }) {
    return WalletSummary(
      coinBalance: coinBalance ?? this.coinBalance,
      earningsBalance: earningsBalance ?? this.earningsBalance,
    );
  }
}

class CoinTransactionItem {
  final String id;
  final String type; // 'topup', 'gift_sent', 'gift_received', 'withdraw', 'withdraw_refund'
  final int amount;
  final int balanceAfter;
  final String description;
  final DateTime createdAt;

  const CoinTransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    required this.createdAt,
  });

  factory CoinTransactionItem.fromMap(Map<String, dynamic> map) {
    return CoinTransactionItem(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'topup',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      balanceAfter: (map['balance_after'] as num?)?.toInt() ?? 0,
      description: map['description']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class WithdrawalRequestItem {
  final String id;
  final int coinAmount;
  final double vndAmount;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String status; // 'pending', 'approved', 'rejected'
  final String? note;
  final DateTime createdAt;

  const WithdrawalRequestItem({
    required this.id,
    required this.coinAmount,
    required this.vndAmount,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.status,
    this.note,
    required this.createdAt,
  });

  factory WithdrawalRequestItem.fromMap(Map<String, dynamic> map) {
    return WithdrawalRequestItem(
      id: map['id']?.toString() ?? '',
      coinAmount: (map['coin_amount'] as num?)?.toInt() ?? 0,
      vndAmount: (map['vnd_amount'] as num?)?.toDouble() ?? 0,
      bankName: map['bank_name']?.toString() ?? '',
      accountNumber: map['account_number']?.toString() ?? '',
      accountName: map['account_name']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      note: map['note']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class GiftCatalogItem {
  final String id;
  final String name;
  final String icon;
  final int coinPrice;
  final int sortOrder;

  const GiftCatalogItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.coinPrice,
    this.sortOrder = 0,
  });

  factory GiftCatalogItem.fromMap(Map<String, dynamic> map) {
    return GiftCatalogItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Quà tặng',
      icon: map['icon']?.toString() ?? '🎁',
      coinPrice: (map['coin_price'] as num?)?.toInt() ?? 1,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  static const List<GiftCatalogItem> defaultGifts = [
    GiftCatalogItem(
      id: 'default-rose',
      name: 'Hoa hồng',
      icon: '🌹',
      coinPrice: 1,
      sortOrder: 1,
    ),
    GiftCatalogItem(
      id: 'default-heart',
      name: 'Thả tim',
      icon: '💖',
      coinPrice: 5,
      sortOrder: 2,
    ),
    GiftCatalogItem(
      id: 'default-boba',
      name: 'Trà sữa',
      icon: '🧋',
      coinPrice: 10,
      sortOrder: 3,
    ),
    GiftCatalogItem(
      id: 'default-bear',
      name: 'Gấu bông',
      icon: '🧸',
      coinPrice: 25,
      sortOrder: 4,
    ),
    GiftCatalogItem(
      id: 'default-ring',
      name: 'Nhẫn kim cương',
      icon: '💍',
      coinPrice: 99,
      sortOrder: 5,
    ),
    GiftCatalogItem(
      id: 'default-crown',
      name: 'Vương miện',
      icon: '👑',
      coinPrice: 299,
      sortOrder: 6,
    ),
    GiftCatalogItem(
      id: 'default-supercar',
      name: 'Siêu xe',
      icon: '🏎️',
      coinPrice: 500,
      sortOrder: 7,
    ),
    GiftCatalogItem(
      id: 'default-rocket',
      name: 'Tên lửa ShareCo',
      icon: '🚀',
      coinPrice: 1000,
      sortOrder: 8,
    ),
  ];
}

class WalletRemoteDataSource {
  WalletRemoteDataSource._();
  static final WalletRemoteDataSource instance = WalletRemoteDataSource._();

  // In-memory cache fallback so the UI remains responsive even before SQL migration is run
  int _cachedCoinBalance = 0;
  int _cachedEarningsBalance = 0;
  final List<CoinTransactionItem> _localTransactions = [];
  final List<WithdrawalRequestItem> _localWithdrawals = [];

  Future<WalletSummary> getWalletSummary() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      return WalletSummary(
        coinBalance: _cachedCoinBalance,
        earningsBalance: _cachedEarningsBalance,
      );
    }

    try {
      final res = await SupabaseService.from('profiles')
          .select('coin_balance, earnings_balance')
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        _cachedCoinBalance = (res['coin_balance'] as num?)?.toInt() ?? 0;
        _cachedEarningsBalance =
            (res['earnings_balance'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {
      // Fallback to cached values if columns not yet migrated
    }

    return WalletSummary(
      coinBalance: _cachedCoinBalance,
      earningsBalance: _cachedEarningsBalance,
    );
  }

  Future<WalletSummary> topUpCoins({
    required int coins,
    required double amountVnd,
    required String method,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('Vui lòng đăng nhập để nạp xu');
    }
    if (coins <= 0) {
      throw Exception('Số xu nạp phải lớn hơn 0');
    }

    try {
      final res = await SupabaseService.rpc(
        'topup_coins',
        params: {
          'p_coins': coins,
          'p_amount_vnd': amountVnd,
          'p_method': method,
        },
      );

      if (res is Map) {
        _cachedCoinBalance =
            (res['coin_balance'] as num?)?.toInt() ?? (_cachedCoinBalance + coins);
        _cachedEarningsBalance =
            (res['earnings_balance'] as num?)?.toInt() ?? _cachedEarningsBalance;
        return WalletSummary(
          coinBalance: _cachedCoinBalance,
          earningsBalance: _cachedEarningsBalance,
        );
      }
    } catch (_) {
      // Fallback: update profiles & coin_transactions directly
      try {
        final current = await getWalletSummary();
        final newBalance = current.coinBalance + coins;
        await SupabaseService.from('profiles').update({
          'coin_balance': newBalance,
        }).eq('id', userId);

        await SupabaseService.from('coin_transactions').insert({
          'user_id': userId,
          'type': 'topup',
          'amount': coins,
          'balance_after': newBalance,
          'description': 'Nạp $coins xu qua $method',
        });

        _cachedCoinBalance = newBalance;
        return WalletSummary(
          coinBalance: _cachedCoinBalance,
          earningsBalance: _cachedEarningsBalance,
        );
      } catch (_) {
        // Local memory fallback if DB migration hasn't been executed yet
        _cachedCoinBalance += coins;
        _localTransactions.insert(
          0,
          CoinTransactionItem(
            id: 'local-${DateTime.now().millisecondsSinceEpoch}',
            type: 'topup',
            amount: coins,
            balanceAfter: _cachedCoinBalance,
            description: 'Nạp $coins xu qua $method',
            createdAt: DateTime.now(),
          ),
        );
      }
    }

    return WalletSummary(
      coinBalance: _cachedCoinBalance,
      earningsBalance: _cachedEarningsBalance,
    );
  }

  Future<WalletSummary> requestWithdrawal({
    required int coinAmount,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('Vui lòng đăng nhập để rút tiền');
    }
    if (coinAmount < WalletSummary.minWithdrawCoins) {
      throw Exception(
        'Số xu rút tối thiểu là ${WalletSummary.minWithdrawCoins} xu (tương đương 100.000đ)',
      );
    }

    final current = await getWalletSummary();
    if (current.coinBalance < coinAmount) {
      throw Exception(
        'Số dư xu không đủ (hiện có ${current.coinBalance} xu, cần $coinAmount xu)',
      );
    }

    try {
      final res = await SupabaseService.rpc(
        'request_coin_withdrawal',
        params: {
          'p_coin_amount': coinAmount,
          'p_bank_name': bankName.trim(),
          'p_account_number': accountNumber.trim(),
          'p_account_name': accountName.trim().toUpperCase(),
        },
      );

      if (res is Map) {
        _cachedCoinBalance =
            (res['coin_balance'] as num?)?.toInt() ??
            (current.coinBalance - coinAmount);
        _cachedEarningsBalance =
            (res['earnings_balance'] as num?)?.toInt() ??
            _cachedEarningsBalance;
        return WalletSummary(
          coinBalance: _cachedCoinBalance,
          earningsBalance: _cachedEarningsBalance,
        );
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Số dư xu không đủ') ||
          msg.contains('Số xu rút tối thiểu')) {
        rethrow;
      }

      // Fallback if RPC not yet created
      final newBalance = current.coinBalance - coinAmount;
      final newEarnings = (current.earningsBalance - coinAmount) < 0
          ? 0
          : (current.earningsBalance - coinAmount);
      final vndAmount = coinAmount * WalletSummary.vndPerCoin.toDouble();

      try {
        await SupabaseService.from('profiles').update({
          'coin_balance': newBalance,
          'earnings_balance': newEarnings,
        }).eq('id', userId);

        final inserted = await SupabaseService.from('withdrawal_requests')
            .insert({
              'user_id': userId,
              'coin_amount': coinAmount,
              'vnd_amount': vndAmount,
              'bank_name': bankName.trim(),
              'account_number': accountNumber.trim(),
              'account_name': accountName.trim().toUpperCase(),
              'status': 'pending',
            })
            .select('id')
            .maybeSingle();

        await SupabaseService.from('coin_transactions').insert({
          'user_id': userId,
          'type': 'withdraw',
          'amount': -coinAmount,
          'balance_after': newBalance,
          'reference_id': inserted?['id'],
          'description':
              'Rút $coinAmount xu (${vndAmount.toStringAsFixed(0)}đ) về ${bankName.trim()} - ${accountNumber.trim()}',
        });
      } catch (_) {
        _localWithdrawals.insert(
          0,
          WithdrawalRequestItem(
            id: 'local-w-${DateTime.now().millisecondsSinceEpoch}',
            coinAmount: coinAmount,
            vndAmount: vndAmount,
            bankName: bankName.trim(),
            accountNumber: accountNumber.trim(),
            accountName: accountName.trim().toUpperCase(),
            status: 'pending',
            createdAt: DateTime.now(),
          ),
        );
        _localTransactions.insert(
          0,
          CoinTransactionItem(
            id: 'local-tx-${DateTime.now().millisecondsSinceEpoch}',
            type: 'withdraw',
            amount: -coinAmount,
            balanceAfter: newBalance,
            description:
                'Rút $coinAmount xu (${vndAmount.toStringAsFixed(0)}đ) về ${bankName.trim()}',
            createdAt: DateTime.now(),
          ),
        );
      }

      _cachedCoinBalance = newBalance;
      _cachedEarningsBalance = newEarnings;
    }

    return WalletSummary(
      coinBalance: _cachedCoinBalance,
      earningsBalance: _cachedEarningsBalance,
    );
  }

  Future<List<CoinTransactionItem>> getCoinTransactions({int limit = 40}) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return _localTransactions;

    try {
      final rows = await SupabaseService.from('coin_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List)
          .map((e) => CoinTransactionItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return _localTransactions;
    }
  }

  Future<List<WithdrawalRequestItem>> getWithdrawalRequests({
    int limit = 20,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return _localWithdrawals;

    try {
      final rows = await SupabaseService.from('withdrawal_requests')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List)
          .map(
            (e) => WithdrawalRequestItem.fromMap(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (_) {
      return _localWithdrawals;
    }
  }

  Future<List<GiftCatalogItem>> getGiftCatalog() async {
    try {
      final rows = await SupabaseService.from('gift_catalog')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final items = (rows as List)
          .map((e) => GiftCatalogItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      if (items.isNotEmpty) return items;
    } catch (_) {}
    return GiftCatalogItem.defaultGifts;
  }

  Future<Map<String, int>> sendLivestreamGift({
    required String livestreamId,
    required GiftCatalogItem gift,
    required int quantity,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('Vui lòng đăng nhập để tặng quà');
    }

    final totalCoins = gift.coinPrice * quantity;
    final current = await getWalletSummary();
    if (current.coinBalance < totalCoins) {
      throw Exception(
        'Số dư xu không đủ (cần $totalCoins xu, hiện có ${current.coinBalance} xu). Hãy nạp thêm xu nhé!',
      );
    }

    try {
      if (!gift.id.startsWith('default-') &&
          !livestreamId.startsWith('local-')) {
        final res = await SupabaseService.rpc(
          'send_livestream_gift',
          params: {
            'p_livestream_id': livestreamId,
            'p_gift_id': gift.id,
            'p_quantity': quantity,
          },
        );
        if (res is Map) {
          _cachedCoinBalance =
              (res['coin_balance'] as num?)?.toInt() ??
              (current.coinBalance - totalCoins);
          final streamCoins =
              (res['total_gift_coins'] as num?)?.toInt() ?? totalCoins;
          return {
            'coin_balance': _cachedCoinBalance,
            'total_gift_coins': streamCoins,
          };
        }
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Số dư xu không đủ')) rethrow;
    }

    // Fallback when using default gift IDs or before RPC migration
    final newBalance = current.coinBalance - totalCoins;
    _cachedCoinBalance = newBalance;

    try {
      await SupabaseService.from('profiles').update({
        'coin_balance': newBalance,
      }).eq('id', userId);

      if (!livestreamId.startsWith('local-')) {
        await SupabaseService.from('livestream_comments').insert({
          'livestream_id': livestreamId,
          'user_id': userId,
          'content':
              'đã tặng ${quantity}x ${gift.icon} ${gift.name} ($totalCoins xu)',
          'type': 'gift',
          'gift_name': gift.name,
          'gift_icon': gift.icon,
          'gift_quantity': quantity,
          'gift_coins': totalCoins,
        });
      }

      await SupabaseService.from('coin_transactions').insert({
        'user_id': userId,
        'type': 'gift_sent',
        'amount': -totalCoins,
        'balance_after': newBalance,
        'description':
            'Tặng ${quantity}x ${gift.icon} ${gift.name} trong Livestream',
      });
    } catch (_) {
      _localTransactions.insert(
        0,
        CoinTransactionItem(
          id: 'local-gift-${DateTime.now().millisecondsSinceEpoch}',
          type: 'gift_sent',
          amount: -totalCoins,
          balanceAfter: newBalance,
          description:
              'Tặng ${quantity}x ${gift.icon} ${gift.name} trong Livestream',
          createdAt: DateTime.now(),
        ),
      );
    }

    return {
      'coin_balance': _cachedCoinBalance,
      'total_gift_coins': totalCoins,
    };
  }
}

