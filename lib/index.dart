import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'sheet_editor.dart';
import 'models.dart';
import 'pdf_service.dart';

class IndexPage extends StatelessWidget {
  const IndexPage({super.key});

  // Reusable Dialog for Adding or Renaming
  void _showSheetDialog(BuildContext context, {Sheet? sheet}) {
    final isEditing = sheet != null;
    final nameController = TextEditingController(text: isEditing ? sheet.name : '');
    // Default threshold is 72
    final thresholdController = TextEditingController(text: isEditing ? sheet.slabThreshold.toString() : '72');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Rename Sheet' : 'New Sheet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Sheet Name'),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            if (!isEditing) ...[
              const SizedBox(height: 15),
              TextField(
                controller: thresholdController,
                decoration: const InputDecoration(
                  labelText: 'Slab Lower Limit (Inches)',
                  hintText: 'e.g. 72',
                ),
                keyboardType: TextInputType.number,
              ),
            ]
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final threshold = double.tryParse(thresholdController.text) ?? 72.0;

              if (name.isNotEmpty) {
                final provider = Provider.of<SheetProvider>(context, listen: false);
                if (isEditing) {
                  provider.renameSheet(sheet.id, name);
                } else {
                  provider.addSheet(name, threshold);
                }
                Navigator.pop(ctx);
              }
            },
            child: Text(isEditing ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Sheets"),
      ),
      body: Column(
        children: [
          // --- Search Bar ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search sheets...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) {
                // Connects directly to the Provider logic
                Provider.of<SheetProvider>(context, listen: false).setSearchQuery(val);
              },
            ),
          ),

          // --- The List ---
          Expanded(
            child: Consumer<SheetProvider>(
              builder: (context, provider, child) {
                final sheets = provider.sheets;

                if (sheets.isEmpty) {
                  return const Center(child: Text("No sheets found."));
                }

                return ListView.separated(
                  itemCount: sheets.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final sheet = sheets[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.description)),
                      title: Text(sheet.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        // Displaying Date
                        "Created: ${DateFormat('MMM d, yyyy • h:mm a').format(sheet.createdAt)}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'share',
                              child: Row(children: [Icon(Icons.share, size: 20), SizedBox(width: 8), Text("Share")])
                          ),
                          const PopupMenuItem(
                              value: 'download',
                              child: Row(children: [Icon(Icons.download, size: 20), SizedBox(width: 8), Text("Download PDF")])
                          ),
                          const PopupMenuItem(
                              value: 'rename',
                              child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text("Rename")])
                          ),
                          const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'share') {
                            PdfService.sharePdf(sheet);
                          } else if (value == 'download') {
                            PdfService.generateAndSavePdf(sheet);
                          } else if (value == 'rename') {
                            _showSheetDialog(context, sheet: sheet);
                          } else if (value == 'delete') {
                            provider.deleteSheet(sheet.id);
                          }
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SheetEditorPage(sheetId: sheet.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSheetDialog(context),
        label: const Text("New Sheet"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}