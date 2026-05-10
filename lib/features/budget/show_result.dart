import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void showAIResult(BuildContext context, String plan, {String planType = 'monthly'}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    useRootNavigator: true,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
              decoration: BoxDecoration(
                color: planType == 'monthly' ? Colors.deepPurple : Colors.teal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40.w,
                        height: 4.r,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.white, size: 24.sp),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            planType == 'monthly' ? 'AI Monthly Plan' : 'AI Yearly Plan',
                            style:  TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.white, size: 20.sp),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: SelectableText(
                        plan,
                        style: TextStyle(
                          fontSize: 15.sp,
                          height: 1.6.h,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    SizedBox(height: 24.h),

                    Text(
                      'Export Plan',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12.h),

                    Row(
                      children: [
                        Expanded(
                          child: _buildExportButton(
                            icon: Icons.picture_as_pdf,
                            label: 'PDF',
                            color: Colors.red,
                            onTap: () => _exportPDF(dialogContext, plan, planType),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildExportButton(
                            icon: Icons.table_chart,
                            label: 'CSV',
                            color: Colors.green,
                            onTap: () => _exportCSV(dialogContext, plan, planType),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildExportButton(
                            icon: Icons.share,
                            label: 'Share',
                            color: Colors.blue,
                            onTap: () => _shareText(plan),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16.h),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: plan));
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Plan copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy to Clipboard'),
                      ),
                    ),

                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildExportButton({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12.r),
    child: Container(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24.sp),
          SizedBox(height: 6.h),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _exportPDF(BuildContext context, String plan, String planType) async {
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
                  planType == 'monthly' ? 'AI Monthly Saving Plan' : 'AI Yearly Wealth Plan',
                  style: pw.TextStyle(
                    fontSize: 24.sp,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20.h),
                pw.Text(
                  'Generated on: ${DateTime.now().toString().split('.')[0]}',
                  style: pw.TextStyle(fontSize: 12.sp, color: PdfColors.grey),
                ),
                pw.SizedBox(height: 30),
                pw.Text(plan, style: pw.TextStyle(fontSize: 14.sp, lineSpacing: 1.5.w)),
              ],
            ),
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/ai_plan_${planType}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'My AI Financial Plan');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF exported successfully')),
      );
    }
  } catch (e) {
    debugPrint('PDF Error: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _exportCSV(BuildContext context, String plan, String planType) async {
  try {
    final lines = plan.split('\n');
    final csvLines = <String>[];

    csvLines.add('Section,Details');
    csvLines.add('Plan Type,$planType');
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
    final file = File('${output.path}/ai_plan_${planType}_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvContent);

    await Share.shareXFiles([XFile(file.path)], text: 'My AI Financial Plan');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV exported successfully')),
      );
    }
  } catch (e) {
    debugPrint('CSV Error: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

void _shareText(String plan) {
  Share.share(plan, subject: 'My AI Financial Plan');
}

