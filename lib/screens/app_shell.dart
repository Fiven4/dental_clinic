import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/access.dart';
import '../state/auth_notifier.dart';

const _icons = {
  Section.mySchedule: Icons.today_outlined,
  Section.schedule: Icons.calendar_view_week_outlined,
  Section.appointments: Icons.event_note_outlined,
  Section.patients: Icons.people_outline,
  Section.cards: Icons.folder_shared_outlined,
  Section.doctors: Icons.medical_services_outlined,
  Section.services: Icons.healing_outlined,
  Section.categories: Icons.category_outlined,
  Section.specializations: Icons.school_outlined,
  Section.cabinets: Icons.meeting_room_outlined,
  Section.cash: Icons.point_of_sale_outlined,
  Section.report: Icons.insights_outlined,
  Section.users: Icons.manage_accounts_outlined,
};

class AppShell extends StatelessWidget {
  final String location;
  final Widget child;

  const AppShell({super.key, required this.location, required this.child});

  void _logout(BuildContext context) {
    context.read<AuthNotifier>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    final sections = sectionsFor(auth.role);
    final current = sectionOfPath(location);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    Widget navigation({required bool inDrawer}) => _Navigation(
      sections: sections,
      current: current,
      userName: user?.name ?? '',
      roleLabel: user?.role.label ?? '',
      onSelect: (s) {
        if (inDrawer) Navigator.pop(context);
        context.go(s.path);
      },
      onLogout: () => _logout(context),
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(width: 248, child: navigation(inDrawer: false)),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(current?.label ?? 'Клиника'),
        actions: [
          IconButton(
            key: const ValueKey('logout-button'),
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      drawer: Drawer(child: navigation(inDrawer: true)),
      body: SafeArea(child: child),
    );
  }
}

class _Navigation extends StatelessWidget {
  final List<Section> sections;
  final Section? current;
  final String userName;
  final String roleLabel;
  final ValueChanged<Section> onSelect;
  final VoidCallback onLogout;

  const _Navigation({
    required this.sections,
    required this.current,
    required this.userName,
    required this.roleLabel,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.medical_services_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Улыбка', style: theme.textTheme.titleLarge),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final s in sections)
                  ListTile(
                    key: ValueKey('nav-${s.name}'),
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    leading: Icon(_icons[s]),
                    title: Text(s.label),
                    selected: s == current,
                    selectedTileColor: theme.colorScheme.secondaryContainer,
                    onTap: () => onSelect(s),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              child: Text(userName.isEmpty ? '?' : userName[0].toUpperCase()),
            ),
            title: Text(userName, overflow: TextOverflow.ellipsis),
            subtitle: Text(roleLabel, key: const ValueKey('nav-role')),
            trailing: IconButton(
              key: const ValueKey('nav-logout'),
              tooltip: 'Выйти',
              icon: const Icon(Icons.logout),
              onPressed: onLogout,
            ),
          ),
        ],
      ),
    );
  }
}
