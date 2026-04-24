import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for InputFormatter
import 'package:provider/provider.dart';
import 'models.dart';

class SheetEditorPage extends StatelessWidget {
  final String sheetId;

  const SheetEditorPage({super.key, required this.sheetId});

  void _showSummary(BuildContext context, Sheet sheet) {
    // Calculate the upper range of undersize automatically
    double undersizeUpper = sheet.slabThreshold - 1;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Sheet Summary"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryRow(label: "Total", value: sheet.totalSft, isBold: true),
            const Divider(),
            _SummaryRow(label: "Slabs (≥ ${sheet.slabThreshold.toInt()})", value: sheet.slabsSft),
            _SummaryRow(label: "Undersize (45 - ${undersizeUpper.toInt()})", value: sheet.undersizeSft),
            _SummaryRow(label: "Below Size (≤ 44)", value: sheet.belowSizeSft),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<SheetProvider>(
          builder: (context, provider, child) {
            try {
              final sheet = provider.getSheetById(sheetId);
              return Text(sheet.name);
            } catch (e) {
              return const Text("Editor");
            }
          },
        ),
        actions: [
          // SUMMARY BUTTON
          Consumer<SheetProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: const Icon(Icons.analytics_outlined),
                tooltip: "View Summary",
                onPressed: () {
                  try {
                    final sheet = provider.getSheetById(sheetId);
                    _showSummary(context, sheet);
                  } catch (e) {
                    // Handle error
                  }
                },
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          // --- HEADER ROW ---
          Container(
            color: Colors.blueGrey[50],
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: const [
                SizedBox(width: 40, child: Text("S.No", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text("L (in)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text("H (in)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text("L (cm)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(child: Text("H (cm)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(child: Text("Sft (in)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                // REMOVED Sft (cm) Header
              ],
            ),
          ),
          const Divider(height: 1),

          // --- DATA ROWS ---
          Expanded(
            child: Consumer<SheetProvider>(
              builder: (context, provider, child) {
                Sheet sheet;
                try {
                  sheet = provider.getSheetById(sheetId);
                } catch (e) {
                  return const Center(child: Text("Sheet not found"));
                }

                return ListView.separated(
                  itemCount: sheet.rows.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1, color: Colors.black12),
                  itemBuilder: (context, index) {
                    final row = sheet.rows[index];

                    return Container(
                      color: index % 2 == 0 ? Colors.white : Colors.grey[50],
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          // 1. S.No
                          SizedBox(
                            width: 40,
                            child: Text("${index + 1}", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),

                          // 2. L_in (Editable, 2 decimals max)
                          Expanded(
                            child: _EditableCell(
                              initialValue: row.lIn,
                              onChanged: (val) => provider.updateCell(sheetId, index, lIn: val),
                            ),
                          ),

                          // 3. H_in (Editable, 2 decimals max)
                          Expanded(
                            child: _EditableCell(
                              initialValue: row.hIn,
                              onChanged: (val) => provider.updateCell(sheetId, index, hIn: val),
                            ),
                          ),

                          // 4. L_cm (Read Only)
                          Expanded(child: _ReadOnlyCell(text: row.lCm)),

                          // 5. H_cm (Read Only)
                          Expanded(child: _ReadOnlyCell(text: row.hCm)),

                          // 6. Sft_in (Read Only)
                          Expanded(child: _ReadOnlyCell(text: row.sftIn)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- HELPER WIDGETS ---

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;

  const _SummaryRow({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value.toStringAsFixed(2), style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _EditableCell extends StatelessWidget {
  final double? initialValue;
  final Function(String) onChanged;

  const _EditableCell({required this.initialValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: TextFormField(
        initialValue: initialValue?.toString() ?? '',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        // --- INPUT FORMATTER FOR 2 DECIMAL PLACES ---
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        ],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          border: OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _ReadOnlyCell extends StatelessWidget {
  final String text;

  const _ReadOnlyCell({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13, color: Colors.black87),
    );
  }
}