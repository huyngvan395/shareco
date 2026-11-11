// features/wallet/presentation/screen/wallet_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/datasources/wallet_remote_datasource.dart';

class WalletScreen extends StatefulWidget {
  final int initialTabIndex;

  const WalletScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _walletDs = WalletRemoteDataSource.instance;
  final _currencyFmt = NumberFormat('#,###', 'vi_VN');

  WalletSummary _summary = const WalletSummary(
    coinBalance: 0,
    earningsBalance: 0,
  );
  List<CoinTransactionItem> _transactions = [];
  List<WithdrawalRequestItem> _withdrawals = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Top-up state
  int _selectedPackageIndex = 2; // Default 1.000 xu
  String _selectedPaymentMethod = 'VNPay QR';

  // Withdrawal form state
  final _withdrawCoinCtrl = TextEditingController(text: '1000');
  final _accountNumberCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  String _selectedBank = 'Vietcombank';

  static const List<_TopUpPackage> _packages = [
    _TopUpPackage(coins: 100, bonusCoins: 0, priceVnd: 12000),
    _TopUpPackage(coins: 500, bonusCoins: 20, priceVnd: 55000, badge: 'Phổ biến'),
    _TopUpPackage(coins: 1000, bonusCoins: 50, priceVnd: 100000, badge: 'Hot'),
    _TopUpPackage(coins: 2500, bonusCoins: 150, priceVnd: 240000),
    _TopUpPackage(coins: 5000, bonusCoins: 400, priceVnd: 470000, badge: 'Tiết kiệm'),
    _TopUpPackage(coins: 10000, bonusCoins: 1000, priceVnd: 900000, badge: 'VIP'),
  ];

  static const List<String> _paymentMethods = [
    'VNPay QR',
    'Ví MoMo',
    'ZaloPay',
    'Thẻ Ngân hàng / ATM',
  ];

  static const List<String> _banks = [
    'Vietcombank',
    'MB Bank',
    'Techcombank',
    'BIDV',
    'VietinBank',
    'ACB',
    'TPBank',
    'VPBank',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _withdrawCoinCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _walletDs.getWalletSummary(),
        _walletDs.getCoinTransactions(),
        _walletDs.getWithdrawalRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as WalletSummary;
        _transactions = results[1] as List<CoinTransactionItem>;
        _withdrawals = results[2] as List<WithdrawalRequestItem>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleTopUp() async {
    if (_isSubmitting) return;
    final pkg = _packages[_selectedPackageIndex];
    final totalCoins = pkg.coins + pkg.bonusCoins;

    setState(() => _isSubmitting = true);
    try {
      final updated = await _walletDs.topUpCoins(
        coins: totalCoins,
        amountVnd: pkg.priceVnd.toDouble(),
        method: _selectedPaymentMethod,
      );
      await _loadData();
      if (!mounted) return;
      setState(() {
        _summary = updated;
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF00B894),
          content: Text(
            '🎉 Nạp thành công +${_currencyFmt.format(totalCoins)} xu! Số dư hiện tại: ${_currencyFmt.format(updated.coinBalance)} xu',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _handleWithdrawal() async {
    if (_isSubmitting) return;
    final coinAmount = int.tryParse(_withdrawCoinCtrl.text.trim()) ?? 0;

    if (coinAmount < WalletSummary.minWithdrawCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Số xu rút tối thiểu là ${_currencyFmt.format(WalletSummary.minWithdrawCoins)} xu (100.000đ)',
          ),
        ),
      );
      return;
    }

    if (_summary.coinBalance < coinAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Số dư xu không đủ (hiện có ${_currencyFmt.format(_summary.coinBalance)} xu)',
          ),
        ),
      );
      return;
    }

    if (_accountNumberCtrl.text.trim().isEmpty ||
        _accountNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Vui lòng nhập đầy đủ số tài khoản và tên chủ tài khoản nhận tiền',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final updated = await _walletDs.requestWithdrawal(
        coinAmount: coinAmount,
        bankName: _selectedBank,
        accountNumber: _accountNumberCtrl.text.trim(),
        accountName: _accountNameCtrl.text.trim(),
      );
      await _loadData();
      if (!mounted) return;
      setState(() {
        _summary = updated;
        _isSubmitting = false;
      });
      final vnd = coinAmount * WalletSummary.vndPerCoin;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF00B894),
          content: Text(
            '✅ Đã tạo lệnh rút ${_currencyFmt.format(coinAmount)} xu (${_currencyFmt.format(vnd)}đ) về $_selectedBank!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        title: const Text(
          'Ví Xu & Rút Tiền',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          dividerColor: AppColors.borderSubtle,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: const [
            Tab(text: 'Nạp Xu'),
            Tab(text: 'Rút Tiền'),
            Tab(text: 'Lịch Sử'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildBalanceHeader(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTopUpTab(),
                      _buildWithdrawTab(),
                      _buildTransactionsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceHeader() {
    final progress = (_summary.coinBalance / WalletSummary.minWithdrawCoins)
        .clamp(0.0, 1.0);
    final remaining =
        (WalletSummary.minWithdrawCoins - _summary.coinBalance).clamp(
          0,
          WalletSummary.minWithdrawCoins,
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF281538), Color(0xFF161B2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Số dư Xu khả dụng',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _currencyFmt.format(_summary.coinBalance),
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Xu',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '≈ ${_currencyFmt.format(_summary.withdrawableVnd)} ₫',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Quà nhận từ Live',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '💎 ${_currencyFmt.format(_summary.earningsBalance)} xu',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                _summary.canWithdraw ? AppColors.emerald : AppColors.gold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _summary.canWithdraw
                      ? '✅ Đủ điều kiện rút tiền mặt (Tối thiểu 1.000 xu)'
                      : 'Cần thêm ${_currencyFmt.format(remaining)} xu để đủ mốc rút tiền (1.000 xu)',
                  style: TextStyle(
                    color: _summary.canWithdraw
                        ? AppColors.emerald
                        : Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(_summary.coinBalance).clamp(0, WalletSummary.minWithdrawCoins)}/1.000',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopUpTab() {
    final selectedPkg = _packages[_selectedPackageIndex];
    final totalCoins = selectedPkg.coins + selectedPkg.bonusCoins;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chọn gói Nạp Xu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Xu dùng để tặng quà cho Streamer yêu thích trong phòng Livestream',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _packages.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
            ),
            itemBuilder: (context, index) {
              final pkg = _packages[index];
              final isSelected = index == _selectedPackageIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedPackageIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.16)
                        : AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.borderSubtle,
                      width: isSelected ? 1.8 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      if (pkg.badge != null)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pkg.badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              const Text('🪙', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Text(
                                '${_currencyFmt.format(pkg.coins)} Xu',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          if (pkg.bonusCoins > 0) ...[
                            const SizedBox(height: 3),
                            Text(
                              '+Tặng thêm ${_currencyFmt.format(pkg.bonusCoins)} xu',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            '${_currencyFmt.format(pkg.priceVnd)} ₫',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          const Text(
            'Phương thức thanh toán',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ..._paymentMethods.map((method) {
            final selected = method == _selectedPaymentMethod;
            return GestureDetector(
              onTap: () => setState(() => _selectedPaymentMethod = method),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : AppColors.borderSubtle,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      method.contains('QR')
                          ? Icons.qr_code_scanner_rounded
                          : method.contains('Thẻ')
                          ? Icons.credit_card_rounded
                          : Icons.account_balance_wallet_rounded,
                      color: selected ? AppColors.primary : Colors.white60,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        method,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: selected ? AppColors.primary : Colors.white38,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleTopUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Nạp ${_currencyFmt.format(totalCoins)} Xu • ${_currencyFmt.format(selectedPkg.priceVnd)} ₫',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawTab() {
    final inputCoins = int.tryParse(_withdrawCoinCtrl.text.trim()) ?? 0;
    final estimatedVnd = inputCoins * WalletSummary.vndPerCoin;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Quy định rút tiền: Tối thiểu 1.000 xu/lần rút.\nTỷ lệ quy đổi: 1 Xu = 100 VNĐ (1.000 Xu = 100.000 VNĐ).',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Số xu muốn rút',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _withdrawCoinCtrl,
            keyboardType: TextInputType.number,
            cursorColor: AppColors.primary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Nhập số xu (tối thiểu 1000)',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('🪙', style: TextStyle(fontSize: 18)),
              ),
              suffixIcon: TextButton(
                onPressed: () {
                  if (_summary.coinBalance > 0) {
                    _withdrawCoinCtrl.text = _summary.coinBalance.toString();
                    setState(() {});
                  }
                },
                child: const Text(
                  'Tối đa',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              filled: true,
              fillColor: AppColors.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [1000, 2000, 5000, 10000].map((preset) {
              return ActionChip(
                backgroundColor: AppColors.surfaceCard,
                side: const BorderSide(color: Colors.white12),
                label: Text(
                  '${_currencyFmt.format(preset)} xu',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                onPressed: () {
                  _withdrawCoinCtrl.text = preset.toString();
                  setState(() {});
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Số tiền thực nhận:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '${_currencyFmt.format(estimatedVnd)} VNĐ',
                  style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ngân hàng thụ hưởng',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedBank,
            dropdownColor: AppColors.surfaceCard,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: _banks
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedBank = val);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountNumberCtrl,
            keyboardType: TextInputType.number,
            cursorColor: AppColors.primary,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Số tài khoản ngân hàng',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: AppColors.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountNameCtrl,
            textCapitalization: TextCapitalization.characters,
            cursorColor: AppColors.primary,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Tên chủ tài khoản (Không dấu)',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: AppColors.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: _summary.canWithdraw ? AppColors.emeraldGradient : null,
              color: _summary.canWithdraw ? null : AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _handleWithdrawal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.payments_outlined),
                label: Text(
                  _summary.canWithdraw
                      ? 'Yêu cầu Rút ${_currencyFmt.format(estimatedVnd)} ₫'
                      : 'Chưa đủ 1.000 xu để rút tiền',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
          if (_withdrawals.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Lịch sử yêu cầu rút tiền',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ..._withdrawals.map((w) {
              final statusColor = w.status == 'approved'
                  ? const Color(0xFF00E676)
                  : w.status == 'rejected'
                  ? AppColors.error
                  : Colors.amber;
              final statusLabel = w.status == 'approved'
                  ? 'Đã duyệt'
                  : w.status == 'rejected'
                  ? 'Từ chối'
                  : 'Đang xử lý';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${w.bankName} • ${w.accountNumber}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Rút ${_currencyFmt.format(w.coinAmount)} xu → ${_currencyFmt.format(w.vndAmount)} ₫',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, color: Colors.white24, size: 54),
            SizedBox(height: 12),
            Text(
              'Chưa có giao dịch xu nào',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final isPositive = tx.amount >= 0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isPositive
                    ? const Color(0xFF00E676).withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.15),
                child: Icon(
                  tx.type == 'topup'
                      ? Icons.add_card_rounded
                      : tx.type == 'withdraw'
                      ? Icons.account_balance_rounded
                      : Icons.card_giftcard_rounded,
                  color: isPositive
                      ? const Color(0xFF00E676)
                      : AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description.isNotEmpty
                          ? tx.description
                          : tx.type.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(tx.createdAt.toLocal()),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isPositive ? '+' : ''}${_currencyFmt.format(tx.amount)} xu',
                    style: TextStyle(
                      color: isPositive
                          ? const Color(0xFF00E676)
                          : Colors.redAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Dư: ${_currencyFmt.format(tx.balanceAfter)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopUpPackage {
  final int coins;
  final int bonusCoins;
  final int priceVnd;
  final String? badge;

  const _TopUpPackage({
    required this.coins,
    required this.bonusCoins,
    required this.priceVnd,
    this.badge,
  });
}

