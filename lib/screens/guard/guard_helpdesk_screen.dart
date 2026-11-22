import 'package:flutter/material.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../widgets/paged_list.dart';

class GuardHelpdeskScreen extends StatelessWidget {
  const GuardHelpdeskScreen({super.key});

  Future<void> _call(BuildContext context, String phone) async {
    try {
      if (await launchUrl(Uri(scheme: 'tel', path: phone))) return;
    } catch (_) {
      // The same message applies when the phone app cannot be opened.
    }
    if (context.mounted) {
      showMessage(context, 'Could not open the phone dialer.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Helpdesk directory',
    fillBody: true,
    body: PagedList<ServiceProvider>(
      fetch: (page) => AppServices.instance.guard.helpdesk(page: page),
      emptyTitle: 'No service contacts published',
      itemBuilder: (context, contact, _) {
        final phone = contact.phone;
        return ListRow(
          title: contact.name,
          subtitle: [contact.category, ?phone].join(' · '),
          icon: Icons2.phone,
          onTap: phone == null ? null : () => _call(context, phone),
        );
      },
    ),
  );
}
