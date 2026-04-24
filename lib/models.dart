import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ---------------------------------------------------------------------------
// 1. ROW MODEL
// ---------------------------------------------------------------------------
class SheetRow {
  double? lIn;
  double? hIn;

  SheetRow({this.lIn, this.hIn});

  // Convert to CM for display
  String get lCm => lIn != null ? (lIn! * 2.54).toStringAsFixed(2) : '-';
  String get hCm => hIn != null ? (hIn! * 2.54).toStringAsFixed(2) : '-';

  // Math for Square Feet (Inches)
  double get sftInValue {
    if (lIn != null && hIn != null) return (lIn! * hIn!) / 144.0;
    return 0.0;
  }

  String get sftIn => sftInValue > 0 ? sftInValue.toStringAsFixed(2) : '-';

  // JSON Conversion for encrypted storage
  Map<String, dynamic> toJson() => {'lIn': lIn, 'hIn': hIn};

  factory SheetRow.fromJson(Map<String, dynamic> json) {
    return SheetRow(
      lIn: json['lIn'] != null ? (json['lIn'] as num).toDouble() : null,
      hIn: json['hIn'] != null ? (json['hIn'] as num).toDouble() : null,
    );
  }
}

// ---------------------------------------------------------------------------
// 2. SHEET MODEL
// ---------------------------------------------------------------------------
class Sheet {
  final String id;
  String name;
  final DateTime createdAt;
  final double slabThreshold; // Dynamic threshold set by user
  List<SheetRow> rows;

  Sheet({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.rows,
    required this.slabThreshold,
  });

  // --- AUTOMATED CALCULATIONS ---

  double get totalSft => rows.fold(0.0, (sum, row) => sum + row.sftInValue);

  // Slabs: Length >= User Defined Threshold
  double get slabsSft => rows.fold(0.0, (sum, row) {
    if (row.lIn != null && row.lIn! >= slabThreshold) return sum + row.sftInValue;
    return sum;
  });

  // Undersize: 45 to (Threshold - 1)
  double get undersizeSft => rows.fold(0.0, (sum, row) {
    if (row.lIn != null && row.lIn! >= 45 && row.lIn! < slabThreshold) {
      return sum + row.sftInValue;
    }
    return sum;
  });

  // Below Size: Length <= 44
  double get belowSizeSft => rows.fold(0.0, (sum, row) {
    if (row.lIn != null && row.lIn! <= 44) return sum + row.sftInValue;
    return sum;
  });

  // JSON Conversion
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'slabThreshold': slabThreshold,
    'rows': rows.map((r) => r.toJson()).toList(),
  };

  factory Sheet.fromJson(Map<String, dynamic> json) {
    var rowList = <SheetRow>[];
    if (json['rows'] != null) {
      rowList = (json['rows'] as List).map((i) => SheetRow.fromJson(i)).toList();
    } else {
      rowList = List.generate(500, (_) => SheetRow());
    }
    return Sheet(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.parse(json['createdAt']),
      slabThreshold: (json['slabThreshold'] as num?)?.toDouble() ?? 72.0,
      rows: rowList,
    );
  }
}

// ---------------------------------------------------------------------------
// 3. SECURE SHEET PROVIDER (STATE MANAGEMENT)
// ---------------------------------------------------------------------------
class SheetProvider with ChangeNotifier {
  List<Sheet> _sheets = [];
  String _searchQuery = '';

  // Storage Keys
  static const String _boxName = 'secure_sheets_vault';
  static const String _secureKeyName = 'secret_encryption_key';

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  SheetProvider() {
    _initializeSecureStorage();
  }

  // --- INITIALIZE ENCRYPTED DATABASE ---
  Future<void> _initializeSecureStorage() async {
    await Hive.initFlutter();

    const secureStorage = FlutterSecureStorage();

    // Check if we already have an encryption key stored in hardware
    String? base64Key = await secureStorage.read(key: _secureKeyName);

    if (base64Key == null) {
      // Generate a new 256-bit secure key
      final key = Hive.generateSecureKey();
      await secureStorage.write(key: _secureKeyName, value: base64UrlEncode(key));
      base64Key = base64UrlEncode(key);
    }

    final encryptionKey = base64Url.decode(base64Key);

    // Open the Hive Box with AES-256 Encryption
    final box = await Hive.openBox(
        _boxName,
        encryptionCipher: HiveAesCipher(encryptionKey)
    );

    // Load data from the box
    final List<dynamic>? rawData = box.get('sheets_data');
    if (rawData != null) {
      _sheets = rawData
          .map((item) => Sheet.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  // --- GETTERS ---
  List<Sheet> get sheets {
    if (_searchQuery.isEmpty) {
      return List.from(_sheets)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return _sheets
        .where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Sheet getSheetById(String id) => _sheets.firstWhere((s) => s.id == id);

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // --- CRUD OPERATIONS ---

  void addSheet(String name, double threshold) {
    final newSheet = Sheet(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now(),
      slabThreshold: threshold,
      rows: List.generate(500, (_) => SheetRow()),
    );
    _sheets.add(newSheet);
    _syncToDisk();
    notifyListeners();
  }

  void renameSheet(String id, String newName) {
    final index = _sheets.indexWhere((s) => s.id == id);
    if (index != -1) {
      _sheets[index].name = newName;
      _syncToDisk();
      notifyListeners();
    }
  }

  void deleteSheet(String id) {
    _sheets.removeWhere((s) => s.id == id);
    _syncToDisk();
    notifyListeners();
  }

  void updateCell(String sheetId, int rowIndex, {String? lIn, String? hIn}) {
    final sheetIndex = _sheets.indexWhere((s) => s.id == sheetId);
    if (sheetIndex == -1) return;

    if (lIn != null) _sheets[sheetIndex].rows[rowIndex].lIn = double.tryParse(lIn);
    if (hIn != null) _sheets[sheetIndex].rows[rowIndex].hIn = double.tryParse(hIn);

    _syncToDisk();
    notifyListeners();
  }

  // --- PRIVATE SYNC METHOD ---
  Future<void> _syncToDisk() async {
    final box = Hive.box(_boxName);
    final dataToSave = _sheets.map((s) => s.toJson()).toList();
    await box.put('sheets_data', dataToSave);
  }
}