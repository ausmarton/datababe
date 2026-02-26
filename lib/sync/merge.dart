import 'dart:convert';

/// Result of merging local and cloud data.
class MergeResult {
  final String mergedJson;
  final bool localChanged;
  final bool cloudChanged;
  final int addedToLocal;
  final int addedToCloud;
  final int updatedLocal;
  final int updatedCloud;

  const MergeResult({
    required this.mergedJson,
    required this.localChanged,
    required this.cloudChanged,
    this.addedToLocal = 0,
    this.addedToCloud = 0,
    this.updatedLocal = 0,
    this.updatedCloud = 0,
  });

  bool get hasChanges => localChanged || cloudChanged;
}

/// Merge two JSON backup strings per-record.
///
/// For each table, records are matched by ID. When both sides have the same
/// record, the one with the newer timestamp wins (local wins ties).
MergeResult mergeBackups(String localJson, String cloudJson) {
  final local = jsonDecode(localJson) as Map<String, dynamic>;
  final cloud = jsonDecode(cloudJson) as Map<String, dynamic>;

  var addedToLocal = 0;
  var addedToCloud = 0;
  var updatedLocal = 0;
  var updatedCloud = 0;

  // Merge each table
  final familiesResult = _mergeTable(
    _asList(local, 'families'),
    _asList(cloud, 'families'),
    idKey: 'id',
    timestampKey: 'createdAt',
  );
  addedToLocal += familiesResult.addedToLocal;
  addedToCloud += familiesResult.addedToCloud;
  updatedLocal += familiesResult.updatedLocal;
  updatedCloud += familiesResult.updatedCloud;

  final childrenResult = _mergeTable(
    _asList(local, 'children'),
    _asList(cloud, 'children'),
    idKey: 'id',
    timestampKey: 'createdAt',
  );
  addedToLocal += childrenResult.addedToLocal;
  addedToCloud += childrenResult.addedToCloud;
  updatedLocal += childrenResult.updatedLocal;
  updatedCloud += childrenResult.updatedCloud;

  final carersResult = _mergeTable(
    _asList(local, 'carers'),
    _asList(cloud, 'carers'),
    idKey: 'id',
    timestampKey: 'createdAt',
  );
  addedToLocal += carersResult.addedToLocal;
  addedToCloud += carersResult.addedToCloud;
  updatedLocal += carersResult.updatedLocal;
  updatedCloud += carersResult.updatedCloud;

  final familyCarersResult = _mergeTable(
    _asList(local, 'familyCarers'),
    _asList(cloud, 'familyCarers'),
    compositeKey: (r) => '${r['familyId']}|${r['carerId']}',
    timestampKey: 'joinedAt',
  );
  addedToLocal += familyCarersResult.addedToLocal;
  addedToCloud += familyCarersResult.addedToCloud;
  updatedLocal += familyCarersResult.updatedLocal;
  updatedCloud += familyCarersResult.updatedCloud;

  final activitiesResult = _mergeTable(
    _asList(local, 'activities'),
    _asList(cloud, 'activities'),
    idKey: 'id',
    timestampKey: 'modifiedAt',
  );
  addedToLocal += activitiesResult.addedToLocal;
  addedToCloud += activitiesResult.addedToCloud;
  updatedLocal += activitiesResult.updatedLocal;
  updatedCloud += activitiesResult.updatedCloud;

  final merged = {
    'version': local['version'] ?? cloud['version'] ?? 1,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'schemaVersion': local['schemaVersion'] ?? cloud['schemaVersion'],
    'families': familiesResult.merged,
    'children': childrenResult.merged,
    'carers': carersResult.merged,
    'familyCarers': familyCarersResult.merged,
    'activities': activitiesResult.merged,
  };

  final localChanged = addedToLocal > 0 || updatedLocal > 0;
  final cloudChanged = addedToCloud > 0 || updatedCloud > 0;

  return MergeResult(
    mergedJson: jsonEncode(merged),
    localChanged: localChanged,
    cloudChanged: cloudChanged,
    addedToLocal: addedToLocal,
    addedToCloud: addedToCloud,
    updatedLocal: updatedLocal,
    updatedCloud: updatedCloud,
  );
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _asList(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return [];
  return (value as List).cast<Map<String, dynamic>>();
}

DateTime _parseTimestamp(dynamic value) {
  if (value is String) return DateTime.parse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime(2000); // fallback for missing timestamps
}

typedef _KeyFn = String Function(Map<String, dynamic>);

class _TableMergeResult {
  final List<Map<String, dynamic>> merged;
  final int addedToLocal;
  final int addedToCloud;
  final int updatedLocal;
  final int updatedCloud;

  const _TableMergeResult({
    required this.merged,
    this.addedToLocal = 0,
    this.addedToCloud = 0,
    this.updatedLocal = 0,
    this.updatedCloud = 0,
  });
}

_TableMergeResult _mergeTable(
  List<Map<String, dynamic>> localRecords,
  List<Map<String, dynamic>> cloudRecords, {
  String? idKey,
  _KeyFn? compositeKey,
  required String timestampKey,
}) {
  final keyFn = compositeKey ?? ((r) => r[idKey!] as String);

  final localMap = {for (final r in localRecords) keyFn(r): r};
  final cloudMap = {for (final r in cloudRecords) keyFn(r): r};

  final allKeys = {...localMap.keys, ...cloudMap.keys};
  final merged = <Map<String, dynamic>>[];

  var addedToLocal = 0;
  var addedToCloud = 0;
  var updatedLocal = 0;
  var updatedCloud = 0;

  for (final key in allKeys) {
    final localRec = localMap[key];
    final cloudRec = cloudMap[key];

    if (localRec != null && cloudRec == null) {
      // Only in local → new for cloud
      merged.add(localRec);
      addedToCloud++;
    } else if (localRec == null && cloudRec != null) {
      // Only in cloud → new for local
      merged.add(cloudRec);
      addedToLocal++;
    } else {
      // In both → newer wins, local wins ties
      final localTs = _parseTimestamp(localRec![timestampKey]);
      final cloudTs = _parseTimestamp(cloudRec![timestampKey]);

      if (cloudTs.isAfter(localTs)) {
        merged.add(cloudRec);
        updatedLocal++;
      } else {
        merged.add(localRec);
        if (localTs.isAfter(cloudTs)) {
          updatedCloud++;
        }
        // Equal timestamps: keep local, no change counted
      }
    }
  }

  return _TableMergeResult(
    merged: merged,
    addedToLocal: addedToLocal,
    addedToCloud: addedToCloud,
    updatedLocal: updatedLocal,
    updatedCloud: updatedCloud,
  );
}
