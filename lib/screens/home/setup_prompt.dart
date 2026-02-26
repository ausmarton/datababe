import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';

import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/child_provider.dart';
import '../../providers/sync_provider.dart';

/// Shown when no child is set up yet. Prompts the user to add a child.
class SetupPrompt extends ConsumerStatefulWidget {
  const SetupPrompt({super.key});

  @override
  ConsumerState<SetupPrompt> createState() => _SetupPromptState();
}

class _SetupPromptState extends ConsumerState<SetupPrompt> {
  final _nameController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 90)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _dateOfBirth == null) return;

    setState(() => _saving = true);

    final uuid = const Uuid();
    final childId = uuid.v4();
    final familyId = uuid.v4();
    final carerId = uuid.v4();
    final now = DateTime.now();

    final familyDao = ref.read(familyDaoProvider);

    await familyDao.insertFamily(FamiliesCompanion(
      id: Value(familyId),
      name: Value('$name\'s Family'),
      createdAt: Value(now),
    ));

    await familyDao.insertCarer(CarersCompanion(
      id: Value(carerId),
      displayName: const Value('Parent'),
      role: const Value('parent'),
      createdAt: Value(now),
    ));

    await familyDao.addCarerToFamily(FamilyCarersCompanion(
      familyId: Value(familyId),
      carerId: Value(carerId),
      joinedAt: Value(now),
    ));

    await familyDao.insertChild(ChildrenCompanion(
      id: Value(childId),
      familyId: Value(familyId),
      name: Value(name),
      dateOfBirth: Value(_dateOfBirth!),
      createdAt: Value(now),
    ));

    ref.read(selectedChildIdProvider.notifier).state = childId;
    ref.read(autoSyncProvider).onDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.child_care,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to Filho',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Add your child to get started',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Child\'s name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  _dateOfBirth == null
                      ? 'Date of birth'
                      : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
                onTap: _pickDate,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('Add Child'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
