import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/family_model.dart';
import '../../models/child_model.dart';
import '../../models/carer_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/repository_provider.dart';
import '../../providers/child_provider.dart';

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

    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _saving = false);
      return;
    }

    try {
      final uuid = const Uuid();
      final childId = uuid.v4();
      final familyId = uuid.v4();
      final carerId = uuid.v4();
      final now = DateTime.now();

      final family = FamilyModel(
        id: familyId,
        name: '$name\'s Family',
        createdBy: user.uid,
        memberUids: [user.uid],
        createdAt: now,
        modifiedAt: now,
      );

      final child = ChildModel(
        id: childId,
        name: name,
        dateOfBirth: _dateOfBirth!,
        createdAt: now,
        modifiedAt: now,
      );

      final carer = CarerModel(
        id: carerId,
        uid: user.uid,
        displayName: user.displayName.isNotEmpty ? user.displayName : 'Parent',
        role: 'parent',
        createdAt: now,
        modifiedAt: now,
      );

      final repo = ref.read(familyRepositoryProvider);
      await repo.createFamilyWithChild(
        family: family,
        child: child,
        carer: carer,
      );

      ref.read(selectedFamilyIdProvider.notifier).state = familyId;
      ref.read(selectedChildIdProvider.notifier).state = childId;
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create child: $e')),
        );
      }
    }
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
                'Welcome to DataBabe',
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
