import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'models.dart';

class PdfService {
  // --- CORE PDF DESIGN ---
  static Future<pw.Document> _buildPdf(Sheet sheet) async {
    final pdf = pw.Document();
    final filledRows = sheet.rows.where((r) => r.lIn != null || r.hIn != null).toList();
    double undersizeUpper = sheet.slabThreshold - 1;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Sheet: ${sheet.name}", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text("Created: ${sheet.createdAt.toString().split(' ')[0]}"),
              ],
            ),
          ),

          // Summary Section using custom thresholds
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("SUMMARY", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("Total Sft: ${sheet.totalSft.toStringAsFixed(2)}"),
                  pw.Text("Slabs (>=${sheet.slabThreshold.toInt()}): ${sheet.slabsSft.toStringAsFixed(2)}"),
                ]),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("Undersize (45-${undersizeUpper.toInt()}): ${sheet.undersizeSft.toStringAsFixed(2)}"),
                  pw.Text("Below Size (<=44): ${sheet.belowSizeSft.toStringAsFixed(2)}"),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          pw.TableHelper.fromTextArray(
            headers: ['S.No', 'L (in)', 'H (in)', 'L (cm)', 'H (cm)', 'Sft (in)'],
            data: List.generate(filledRows.length, (index) {
              final row = filledRows[index];
              return [
                index + 1,
                row.lIn?.toStringAsFixed(2) ?? '-',
                row.hIn?.toStringAsFixed(2) ?? '-',
                row.lCm,
                row.hCm,
                row.sftIn,
              ];
            }),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
            cellAlignment: pw.Alignment.center,
          ),
        ],
      ),
    );
    return pdf;
  }

  // --- DOWNLOAD / PRINT ---
  static Future<void> generateAndSavePdf(Sheet sheet) async {
    final pdf = await _buildPdf(sheet);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${sheet.name}.pdf',
    );
  }

  // --- DIRECT SHARE (WhatsApp, Email, etc.) ---
  static Future<void> sharePdf(Sheet sheet) async {
    final pdf = await _buildPdf(sheet);
    final bytes = await pdf.save();

    await Printing.sharePdf(
      bytes: bytes,
      filename: '${sheet.name}.pdf',
    );
  }
}