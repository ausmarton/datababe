import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/invite_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/repository_provider.dart';

/// Shown when the user has pending invites but no family yet.
/// Offers Accept/Decline for each invite, plus a fallback to create own family.
class InvitePendingPrompt extends ConsumerStatefulWidget {
  final List<InviteModel> invites;
  final VoidCallback onCreateOwn;

  const InvitePendingPrompt({
    super.key,
    required this.invites,
    required this.onCreateOwn,
  });

  @override
  ConsumerState<InvitePendingPrompt> createState() =>
      _InvitePendingPromptState();
}

class _InvitePendingPromptState extends ConsumerState<InvitePendingPrompt> {
  String? _processingId;

  Future<void> _accept(InviteModel invite) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _processingId = invite.id);
    try {
      final repo = ref.read(familyRepositoryProvider);
      await repo.acceptInvite(
        invite: invite,
        uid: user.uid,
        displayName: user.displayName ?? 'Carer',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept invite: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _decline(InviteModel invite) async {
    setState(() => _processingId = invite.id);
    try {
      final repo = ref.read(familyRepositoryProvider);
      await repo.declineInvite(invite.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline invite: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
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
                Icons.mail,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'You have been invited!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Accept an invite to join an existing family, or create your own.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ...widget.invites.map((invite) {
                final isProcessing = _processingId == invite.id;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invite.familyName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Invited by ${invite.invitedByName} as ${invite.role}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed:
                                  isProcessing ? null : () => _decline(invite),
                              child: const Text('Decline'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed:
                                  isProcessing ? null : () => _accept(invite),
                              child: isProcessing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('Accept'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: widget.onCreateOwn,
                icon: const Icon(Icons.add),
                label: const Text('Create my own family instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
