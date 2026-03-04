import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/child_model.dart';
import '../../models/carer_model.dart';
import '../../models/enums.dart';
import '../../models/invite_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/invite_provider.dart';
import '../../providers/repository_provider.dart';
import '../../providers/child_provider.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(allChildrenProvider);
    final invitesAsync = ref.watch(familyInvitesProvider);
    final carersAsync = ref.watch(familyCarersProvider);
    final currentUser = ref.watch(currentUserProvider);
    final family = ref.watch(selectedFamilyProvider);

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
          // --- Members section ---
          Text(
            'Members',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          carersAsync.when(
            data: (carers) {
              if (carers.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('No members')),
                );
              }

              final currentCarer = carers
                  .where((c) => c.uid == currentUser?.uid)
                  .firstOrNull;
              final isParent = currentCarer?.role == CarerRole.parent.name;

              return Column(
                children: carers.map((carer) {
                  final isCreator =
                      family != null && carer.uid == family.createdBy;
                  final isSelf = carer.uid == currentUser?.uid;
                  final canManage = isParent && !isCreator && !isSelf;

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(carer.displayName.isNotEmpty
                            ? carer.displayName[0].toUpperCase()
                            : '?'),
                      ),
                      title: Text(carer.displayName),
                      subtitle: Chip(
                        label: Text(carer.role),
                        backgroundColor:
                            carer.role == CarerRole.parent.name
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.2),
                        visualDensity: VisualDensity.compact,
                      ),
                      trailing: canManage
                          ? PopupMenuButton<String>(
                              onSelected: (action) {
                                if (action == 'role') {
                                  _showChangeRoleDialog(
                                      context, ref, carer);
                                } else if (action == 'remove') {
                                  _showRemoveMemberDialog(
                                      context, ref, carer);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'role',
                                  child: Text('Change role'),
                                ),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove'),
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          const SizedBox(height: 16),

          // --- Pending invites section ---
          invitesAsync.when(
            data: (invites) {
              final pending = invites
                  .where((i) => i.status == InviteStatus.pending)
                  .toList();
              if (pending.isEmpty) return const SizedBox.shrink();

              final currentCarer = ref
                  .read(familyCarersProvider)
                  .valueOrNull
                  ?.where((c) => c.uid == currentUser?.uid)
                  .firstOrNull;
              final isParent =
                  currentCarer?.role == CarerRole.parent.name;

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
                          trailing: isParent
                              ? IconButton(
                                  icon: const Icon(Icons.cancel_outlined),
                                  tooltip: 'Cancel invite',
                                  onPressed: () async {
                                    final repo = ref
                                        .read(inviteRepositoryProvider);
                                    await repo.cancelInvite(invite.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('Invite cancelled')),
                                      );
                                    }
                                  },
                                )
                              : null,
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
                          ? const Icon(Icons.check_circle,
                              color: Colors.green)
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

  void _showChangeRoleDialog(
      BuildContext context, WidgetRef ref, CarerModel carer) {
    String newRole = carer.role;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Role'),
          content: DropdownButtonFormField<String>(
            value: newRole,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
            items: CarerRole.values
                .map((r) => DropdownMenuItem(
                      value: r.name,
                      child: Text(
                          r.name[0].toUpperCase() + r.name.substring(1)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => newRole = v);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final familyId = ref.read(selectedFamilyIdProvider);
                if (familyId == null) return;

                final repo = ref.read(familyRepositoryProvider);
                await repo.updateCarerRole(familyId, carer.id, newRole);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Role changed to $newRole')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveMemberDialog(
      BuildContext context, WidgetRef ref, CarerModel carer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text(
            'Remove ${carer.displayName} from this family? They will lose access to all family data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final familyId = ref.read(selectedFamilyIdProvider);
              if (familyId == null) return;

              final repo = ref.read(familyRepositoryProvider);
              await repo.removeMember(
                familyId: familyId,
                memberUid: carer.uid,
                carerId: carer.id,
              );

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('${carer.displayName} removed')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
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
                        .firstOrNull ??
                    '';

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

                final repo = ref.read(inviteRepositoryProvider);
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
