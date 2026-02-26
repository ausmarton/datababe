import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/child_model.dart';
import '../../models/enums.dart';
import '../../models/invite_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/invite_provider.dart';
import '../../providers/repository_provider.dart';
import '../../providers/child_provider.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(allChildrenProvider);
    final invitesAsync = ref.watch(familyInvitesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Invite carer',
            onPressed: () => _showInviteDialog(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddChildDialog(context, ref),
        child: const Icon(Icons.person_add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Pending invites section ---
          invitesAsync.when(
            data: (invites) {
              final pending = invites
                  .where((i) => i.status == InviteStatus.pending)
                  .toList();
              if (pending.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending Invites',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...pending.map((invite) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.mail_outline),
                          title: Text(invite.inviteeEmail),
                          subtitle: Text(
                              'Role: ${invite.role} — invited by ${invite.invitedByName}'),
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // --- Children section ---
          Text(
            'Children',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          childrenAsync.when(
            data: (children) {
              if (children.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('No children added yet')),
                );
              }
              return Column(
                children: children.map((child) {
                  final isSelected =
                      ref.watch(selectedChildIdProvider) == child.id;
                  return Card(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(child.name[0].toUpperCase()),
                      ),
                      title: Text(child.name),
                      subtitle: Text(
                        'Born: ${child.dateOfBirth.day}/${child.dateOfBirth.month}/${child.dateOfBirth.year}',
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () {
                        ref.read(selectedChildIdProvider.notifier).state =
                            child.id;
                      },
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    String selectedRole = CarerRole.parent.name;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Invite Carer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: CarerRole.values
                    .map((r) => DropdownMenuItem(
                          value: r.name,
                          child: Text(r.name[0].toUpperCase() +
                              r.name.substring(1)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => selectedRole = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final email = emailController.text.trim().toLowerCase();
                if (email.isEmpty || !email.contains('@')) return;

                final user = ref.read(currentUserProvider);
                final familyId = ref.read(selectedFamilyIdProvider);
                final families =
                    ref.read(userFamiliesProvider).valueOrNull ?? [];

                if (user == null || familyId == null) return;

                final familyName = families
                    .where((f) => f.id == familyId)
                    .map((f) => f.name)
                    .firstOrNull ?? '';

                final invite = InviteModel(
                  id: InviteModel.computeId(familyId, email),
                  familyId: familyId,
                  familyName: familyName,
                  invitedByUid: user.uid,
                  invitedByName: user.displayName ?? 'Unknown',
                  inviteeEmail: email,
                  role: selectedRole,
                  status: InviteStatus.pending,
                  createdAt: DateTime.now(),
                );

                final repo = ref.read(familyRepositoryProvider);
                await repo.createInvite(invite);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invite sent to $email')),
                  );
                }
              },
              child: const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddChildDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    DateTime? dateOfBirth;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Child'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  dateOfBirth == null
                      ? 'Date of birth'
                      : '${dateOfBirth!.day}/${dateOfBirth!.month}/${dateOfBirth!.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate:
                        DateTime.now().subtract(const Duration(days: 90)),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => dateOfBirth = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty || dateOfBirth == null) return;

                final familyId = ref.read(selectedFamilyIdProvider);
                if (familyId == null) return;

                final childId = const Uuid().v4();
                final now = DateTime.now();
                final repo = ref.read(familyRepositoryProvider);

                final child = ChildModel(
                  id: childId,
                  name: name,
                  dateOfBirth: dateOfBirth!,
                  createdAt: now,
                );

                await repo.createChild(familyId, child);

                ref.read(selectedChildIdProvider.notifier).state = childId;
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
