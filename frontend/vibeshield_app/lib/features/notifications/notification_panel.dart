import 'package:flutter/material.dart';
import '../../services/notification_service.dart';

/// Bell icon button with unread badge. 
class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationService.instance,
      builder: (context, _) {
        final count = NotificationService.instance.unreadCount;
        final label = count > 99 ? '99+' : '$count';

        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => _openNotificationCenter(context),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined),
              if (count > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openNotificationCenter(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => const _NotificationCenterSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification Center Bottom Sheet
// ---------------------------------------------------------------------------

class _NotificationCenterSheet extends StatelessWidget {
  const _NotificationCenterSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.70,
        child: ListenableBuilder(
          listenable: NotificationService.instance,
          builder: (context, _) {
            final svc = NotificationService.instance;
            final items = svc.items;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_outlined, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Notifications',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      if (items.isNotEmpty) ...[
                        TextButton(
                          onPressed: svc.markAllRead,
                          child: const Text('Read all'),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () {
                            svc.clearAll();
                          },
                          child: Text('Clear', style: TextStyle(color: scheme.error)),
                        ),
                      ],
                      // Browser notification toggle
                      if (!svc.browserPermissionGranted)
                        IconButton(
                          tooltip: 'Enable browser notifications',
                          onPressed: () async {
                            final ok = await svc.requestBrowserPermission();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Browser notifications enabled!'
                                        : 'Permission denied. Check browser settings.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: Icon(Icons.notifications_off, color: scheme.error, size: 20),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Agent activity & threat alerts. Enable browser push for background alerts.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.notifications_none, size: 48, color: Colors.grey[600]),
                              const SizedBox(height: 12),
                              Text(
                                'No notifications yet',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Agent alerts will appear here',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                          itemBuilder: (context, index) {
                            final n = items[index];
                            return _NotificationTile(
                              notification: n,
                              onTap: () {
                                svc.markRead(n.id);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual notification tile
// ---------------------------------------------------------------------------

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final scheme = Theme.of(context).colorScheme;

    final (IconData icon, Color color) = switch (n.level) {
      NotifLevel.critical => (Icons.shield, Colors.red),
      NotifLevel.warning => (Icons.warning_amber_rounded, Colors.orange),
      NotifLevel.success => (Icons.check_circle, Colors.green),
      NotifLevel.info => (Icons.info_outline, Colors.blue),
    };

    final timeDiff = DateTime.now().difference(n.timestamp);
    final timeStr = timeDiff.inMinutes < 1
        ? 'Just now'
        : timeDiff.inMinutes < 60
            ? '${timeDiff.inMinutes}m ago'
            : timeDiff.inHours < 24
                ? '${timeDiff.inHours}h ago'
                : '${timeDiff.inDays}d ago';

    return ListTile(
      onTap: onTap,
      dense: true,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        n.title,
        style: TextStyle(
          fontWeight: n.read ? FontWeight.normal : FontWeight.bold,
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        n.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(timeStr, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          if (!n.read)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
