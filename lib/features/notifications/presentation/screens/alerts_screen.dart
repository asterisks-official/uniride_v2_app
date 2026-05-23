import 'package:flutter/material.dart';

import '../../../../shared/widgets/empty_state.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: const EmptyState(
        icon: Icons.notifications_outlined,
        title: 'No notifications',
        subtitle: 'Ride updates and alerts will appear here.',
      ),
    );
  }
}
