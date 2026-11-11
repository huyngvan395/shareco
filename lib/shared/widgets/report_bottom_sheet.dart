import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/helpers/require_auth.dart';
import '../../core/services/supabase/index.dart';

class ReportBottomSheet extends StatefulWidget {
  final String targetType; // 'video' | 'user' | 'conversation' | 'product'
  final String targetId;
  final String title;

  const ReportBottomSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.title,
  });

  static Future<void> show(
    BuildContext context, {
    required String targetType,
    required String targetId,
    required String title,
  }) async {
    context.requireAuth(() async {
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => ReportBottomSheet(
          targetType: targetType,
          targetId: targetId,
          title: title,
        ),
      );
    });
  }

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  static const List<String> _reasons = [
    'Nội dung spam hoặc gây hiểu nhầm',
    'Ngôn từ gây thù ghét hoặc quấy rối',
    'Hàng giả, lừa đảo hoặc gian lận mua bán',
    'Nội dung phản cảm / không phù hợp',
    'Vi phạm bản quyền / quyền sở hữu trí tuệ',
    'Lý do khác',
  ];

  String _selectedReason = _reasons.first;
  final TextEditingController _detailsCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      await SupabaseService.from('reports').insert({
        'reporter_id': uid,
        'target_type': widget.targetType,
        'target_id': widget.targetId,
        'reason': _selectedReason,
        'details': _detailsCtrl.text.trim().isEmpty
            ? null
            : _detailsCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã gửi báo cáo. Đội ngũ kiểm duyệt ShareCo sẽ xem xét sớm nhất.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã ghi nhận phản hồi báo cáo của bạn. Cảm ơn bạn đã đóng góp!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Vui lòng chọn lý do báo cáo để chúng tôi xử lý chính xác hơn:',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          RadioGroup<String>(
            groupValue: _selectedReason,
            onChanged: (v) {
              if (v != null) setState(() => _selectedReason = v);
            },
            child: Column(
              children: _reasons
                  .map(
                    (reason) => RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: reason,
                      title: Text(
                        reason,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _detailsCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Mô tả thêm chi tiết (không bắt buộc)...',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
              filled: true,
              fillColor: const Color(0xFFF6F7F9),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Gửi báo cáo',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

