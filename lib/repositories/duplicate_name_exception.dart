/// Thrown when creating or renaming an entity would produce a duplicate name
/// within the same family.
class DuplicateNameException implements Exception {
  final String entityType;
  final String name;

  const DuplicateNameException({required this.entityType, required this.name});

  @override
  String toString() =>
      '$entityType "$name" already exists';
}
