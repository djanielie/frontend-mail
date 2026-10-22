import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/account_unread.dart';
import '../providers/auth_controller.dart';
import '../providers/mail_preferences.dart';
import 'glass.dart';

class AccountUnreadBadge extends StatelessWidget {
  const AccountUnreadBadge({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: child,
    );
  }
}

String emailInitials(String email) {
  final local = email.split('@').first.trim();
  if (local.isEmpty) return '?';
  final parts = local.split(RegExp(r'[.\-_ ]')).where((part) => part.isNotEmpty).toList();
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
  return local.substring(0, local.length >= 2 ? 2 : 1).toUpperCase();
}

class AccountSwitcher extends ConsumerStatefulWidget {
  const AccountSwitcher({super.key});

  @override
  ConsumerState<AccountSwitcher> createState() => _AccountSwitcherState();
}

class _AccountSwitcherState extends ConsumerState<AccountSwitcher> {
  var _open = false;
  var _drag = 0.0;

  void _toggle({bool? open}) {
    final next = open ?? !_open;
    setState(() {
      _open = next;
      _drag = 0;
    });
    if (next) ref.read(accountUnreadProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final prefs = ref.watch(mailPreferencesProvider);
    final unread = ref.watch(accountUnreadProvider);
    final scheme = Theme.of(context).colorScheme;
    final email = auth.email ?? '';
    final name = prefs.displayName.trim().isEmpty ? email.split('@').first : prefs.displayName.trim();
    int countFor(String value) => unread[value.toLowerCase()] ?? 0;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 0) {
          _drag += details.delta.dy;
          if (_drag > 28 && !_open) _toggle(open: true);
        } else if (details.delta.dy < -8 && _open) {
          _toggle(open: false);
        }
      },
      onVerticalDragEnd: (_) => _drag = 0,
      child: GlassPanel(
        margin: const EdgeInsets.fromLTRB(4, 4, 4, 12),
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  AccountUnreadBadge(
                    count: countFor(email),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: prefs.accountColor.withValues(alpha: 0.28),
                      foregroundColor: scheme.primary,
                      child: Text(
                        emailInitials(email),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Compte' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.25,
                              ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    for (final account in auth.accounts)
                      if (account.email.toLowerCase() != email.toLowerCase())
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: AccountUnreadBadge(
                            count: countFor(account.email),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: scheme.primaryContainer.withValues(alpha: 0.7),
                              foregroundColor: scheme.primary,
                              child: Text(
                                emailInitials(account.email),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                              ),
                            ),
                          ),
                          title: Text(account.email, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: countFor(account.email) > 0
                              ? Text(
                                  '${countFor(account.email)}',
                                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
                                )
                              : null,
                          onTap: () {
                            ref.read(authControllerProvider.notifier).switchAccount(account.email);
                            _toggle(open: false);
                          },
                        ),
                    if (auth.accounts.length <= 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Glissez vers le bas ou touchez pour changer de compte.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
              crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),
          ],
        ),
      ),
    );
  }
}
