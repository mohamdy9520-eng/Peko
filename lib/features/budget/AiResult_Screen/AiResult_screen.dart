import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:go_router/go_router.dart';

class AIResultScreen extends StatelessWidget {
  final String plan;
  final String planType;

  const AIResultScreen({
    super.key,
    required this.plan,
    required this.planType,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ حماية قصوى من أي null أو empty
    final safePlan = plan.isEmpty ? 'No plan data available.' : plan;
    final safePlanType = planType.isEmpty ? 'monthly' : planType;
    final isMonthly = safePlanType == 'monthly';
    final primaryColor = isMonthly ? Colors.deepPurple : Colors.teal;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          // ✅ AppBar Collapsible
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: primaryColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              // ✅ استخدم GoRouter.pop() بدل context.pop() عشان يرجع صح
              onPressed: () => GoRouter.of(context).pop(),
            ),
            title: Text(
              isMonthly ? '🤖 AI Monthly Plan' : '🤖 AI Yearly Plan',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      primaryColor.withOpacity(0.7),
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_awesome,
                    size: 50,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
          ),

          // ✅ Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plan Card
                  _buildPlanCard(primaryColor, safePlan),

                  const SizedBox(height: 24),

                  // Export Section
                  _buildExportSection(context, primaryColor, safePlan, safePlanType),

                  const SizedBox(height: 24),

                  // Quick Actions
                  _buildQuickActions(context, safePlan),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Color primaryColor, String safePlan) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.psychology,
                    color: primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Personalized Plan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      Text(
                        'Generated on ${DateTime.now().toString().split('.')[0]}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            // ✅ استخدم Markdown بدل SelectableText لو الـ plan فيه تنسيق
            _buildPlanContent(safePlan),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanContent(String safePlan) {
    // ✅ لو الـ plan فيه Markdown (##, **, إلخ)، استخدم MarkdownBody
    if (safePlan.contains('#') ||
        safePlan.contains('**') ||
        safePlan.contains('*') ||
        safePlan.contains('- ')) {
      return MarkdownBody(
        data: safePlan,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(
            fontSize: 15,
            height: 1.8,
            color: Colors.black87,
          ),
          h1: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          h2: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          listBullet: const TextStyle(
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
      );
    }

    // ✅ لو مفيش Markdown، استخدم SelectableText العادي
    return SelectableText(
      safePlan,
      style: const TextStyle(
        fontSize: 15,
        height: 1.8,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildExportSection(BuildContext context, Color primaryColor, String safePlan, String safePlanType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Export Plan',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Save or share your financial plan',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildExportTile(
                icon: Icons.picture_as_pdf,
                label: 'PDF',
                color: Colors.red,
                onTap: () => _exportPDF(context, safePlan, safePlanType),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildExportTile(
                icon: Icons.table_chart,
                label: 'CSV',
                color: Colors.green,
                onTap: () => _exportCSV(context, safePlan, safePlanType),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildExportTile(
                icon: Icons.share,
                label: 'Share',
                color: Colors.blue,
                onTap: () => _shareText(safePlan),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExportTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, String safePlan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        _buildActionTile(
          icon: Icons.copy,
          title: 'Copy to Clipboard',
          subtitle: 'Copy plan text to paste anywhere',
          onTap: () {
            Clipboard.setData(ClipboardData(text: safePlan));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Plan copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.refresh,
          title: 'Generate New Plan',
          subtitle: 'Create a different plan based on your data',
          // ✅ استخدم GoRouter.pop() بدل context.pop()
          onTap: () => GoRouter.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.grey[700]),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }

  // ═══════════════════════════════════════════════════════
  // EXPORT FUNCTIONS
  // ═══════════════════════════════════════════════════════
  Future<void> _exportPDF(BuildContext context, String safePlan, String safePlanType) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context pdfContext) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    safePlanType == 'monthly' ? 'AI Monthly Saving Plan' : 'AI Yearly Wealth Plan',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Container(
                    color: PdfColors.grey300,
                    height: 2,
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Generated on: ${DateTime.now().toString().split('.')[0]}',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey,
                    ),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Text(
                    safePlan,
                    style: const pw.TextStyle(
                      fontSize: 14,
                      lineSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/ai_plan_${safePlanType}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'My AI Financial Plan');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ PDF exported successfully')),
        );
      }
    } catch (e) {
      debugPrint('PDF Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ PDF Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportCSV(BuildContext context, String safePlan, String safePlanType) async {
    try {
      final lines = safePlan.split('\n');
      final csvLines = <String>[];

      csvLines.add('Section,Details');
      csvLines.add('Plan Type,$safePlanType');
      csvLines.add('Generated,${DateTime.now().toString()}');
      csvLines.add('');

      for (final line in lines) {
        if (line.trim().isNotEmpty) {
          final cleanLine = line.replaceAll(',', ';').replaceAll('\n', ' ');
          csvLines.add('Detail,$cleanLine');
        }
      }

      final csvContent = csvLines.join('\n');

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/ai_plan_${safePlanType}_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvContent);

      await Share.shareXFiles([XFile(file.path)], text: 'My AI Financial Plan');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ CSV exported successfully')),
        );
      }
    } catch (e) {
      debugPrint('CSV Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ CSV Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareText(String safePlan) {
    Share.share(safePlan, subject: 'My AI Financial Plan');
  }
}