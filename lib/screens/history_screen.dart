import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Color _hexColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null)
      return const Scaffold(body: Center(child: Text('Chưa đăng nhập')));

    return Scaffold(
      backgroundColor: SGColor.bg,
      appBar: AppBar(
        title: const Text('Lịch sử dự báo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Xóa tất cả',
            onPressed: () async {
              final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                        title: const Text('Xóa lịch sử?'),
                        content:
                            const Text('Toàn bộ lịch sử sẽ bị xóa vĩnh viễn.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Hủy')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Xóa',
                                  style: TextStyle(color: SGColor.riskHigh))),
                        ],
                      ));
              if (ok == true) {
                final col = FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('predictions');
                final snap = await col.get();
                final batch = FirebaseFirestore.instance.batch();
                for (final d in snap.docs) {
                  batch.delete(d.reference);
                }
                await batch.commit();
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('predictions')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.history_rounded, size: 72, color: Colors.grey),
              SizedBox(height: 16),
              Text('Chưa có lịch sử dự báo', style: SGText.h3),
              SizedBox(height: 6),
              Text('Thực hiện phân tích để xem kết quả tại đây',
                  style: SGText.body),
            ]));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final scanStatus = d['scan_status'] as String?;
              final timestamp = d['timestamp'];
              final ts =
                  timestamp is String ? DateTime.tryParse(timestamp) : null;
              if (scanStatus != null && scanStatus != 'success') {
                return SGCard(
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: SGColor.riskMid),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Lần quét tự động chưa hoàn tất',
                                style: SGText.h3),
                            const SizedBox(height: 4),
                            Text(
                              d['scan_message'] ?? 'Không lấy được kết quả.',
                              style: SGText.body,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ts != null
                                  ? DateFormat('dd/MM/yyyy  HH:mm').format(ts)
                                  : '—',
                              style: SGText.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final prob = (d['ensemble'] ?? 0).toDouble();
              final level = d['risk_level'] ?? 'THẤP';
              final color = _hexColor(d['risk_color'] ?? '#4CAF50');
              final lr = (d['lr'] ?? 0).toDouble();
              final dt = (d['dt'] ?? 0).toDouble();
              final rf = (d['rf'] ?? 0).toDouble();

              return SGCard(
                child: Column(children: [
                  Row(children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.12),
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Center(
                          child: Text('${(prob * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text('Nguy cơ $level',
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                              '${ts != null ? DateFormat('dd/MM/yyyy  HH:mm').format(ts) : '—'}'
                              '${d['is_background'] == true ? ' · Quét tự động' : ''}',
                              style: SGText.caption),
                        ])),
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ]),
                  if (lr > 0 || dt > 0 || rf > 0) ...[
                    const Divider(height: 16),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _mini('LR', lr, Colors.blue),
                          _mini('DT', dt, Colors.orange),
                          _mini('RF', rf, Colors.green),
                        ]),
                  ],
                ]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _mini(String label, double v, Color c) => Column(children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: SGColor.textSub)),
        const SizedBox(height: 2),
        Text('${(v * 100).toStringAsFixed(0)}%',
            style:
                TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c)),
      ]);
}
