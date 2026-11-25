import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/spacing.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/authed_image.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'guard_more_tab.dart';
import '../profile_edit_screen.dart';
import '../root_shell.dart';

/// The guard's own profile.
///
/// Reached from the photo in the gate header, and it doubles as the way back to
/// everything the removed bottom bar used to hold: the account, the shift log
/// and the rest of the gate's reference screens.
class GuardProfileScreen extends StatefulWidget {
  const GuardProfileScreen({super.key});

  @override
  State<GuardProfileScreen> createState() => _GuardProfileScreenState();
}

class _GuardProfileScreenState extends State<GuardProfileScreen> {
  late Future<String> _gate;
  String? _avatarFileId;

  @override
  void initState() {
    super.initState();
    _gate = AppServices.instance.guard.myGate();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    try {
      final profile = await AppServices.instance.guard.profile();
      if (!mounted) return;
      setState(
        () => _avatarFileId =
            asStringOrNull(profile['avatarFileId']) ??
            asStringOrNull(profile['photoFileId']),
      );
    } catch (_) {
      // A missing photo says nothing about the account; keep the initials.
    }
  }

  Future<void> _editProfile() async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ProfileEditScreen()));
    if (changed != true) return;
    await _loadPhoto();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = AppServices.instance.session;
    return AppScaffold(
      title: 'Profile',
      subtitle: session.societyName,
      body: ListView(
        padding: const EdgeInsets.only(
          left: Tokens.gutter,
          right: Tokens.gutter,
          bottom: kScreenBottomPadding,
        ),
        children: [
          _IdentityCard(
            name: session.displayName,
            society: session.societyName,
            avatarFileId: _avatarFileId,
            onEditPhoto: _editProfile,
            gate: FutureBuilder<String>(
              future: _gate,
              builder: (context, snapshot) => Text(
                snapshot.data ?? (snapshot.hasError ? 'On duty' : '…'),
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeSm,
                  color: Tokens.inkMuted,
                ),
              ),
            ),
          ),
          Panel(
            child: Column(
              children: [
                ListRow(
                  title: 'Edit profile',
                  subtitle: 'Your name, photo and email',
                  icon: Icons2.profile,
                  showChevron: true,
                  onTap: _editProfile,
                ),
                const Hairline(),
                ListRow(
                  title: 'Sign out',
                  icon: Icons2.logout,
                  onTap: () => confirmAndLogout(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          const GuardMoreList(),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.society,
    required this.avatarFileId,
    required this.onEditPhoto,
    required this.gate,
  });

  final String name;
  final String society;
  final String? avatarFileId;
  final VoidCallback onEditPhoto;

  /// The assigned gate, resolved asynchronously by the caller.
  final Widget gate;

  static const _photoSize = 88.0;

  @override
  Widget build(BuildContext context) {
    final id = avatarFileId?.trim() ?? '';
    return Padding(
      padding: EdgeInsets.only(bottom: Tokens.space6),
      child: Container(
        padding: EdgeInsets.all(Tokens.space4),
        decoration: BoxDecoration(
          color: Tokens.surface,
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          border: Border.all(color: Tokens.line),
        ),
        child: Row(
          children: [
            Material(
              color: Tokens.surfaceSunken,
              shape: CircleBorder(side: BorderSide(color: Tokens.line)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onEditPhoto,
                child: SizedBox(
                  width: _photoSize,
                  height: _photoSize,
                  child: id.isEmpty
                      ? Center(
                          child: Text(
                            name.trim().isEmpty
                                ? '?'
                                : name.trim()[0].toUpperCase(),
                            style: TextStyle(
                              fontFamily: Tokens.fontFamilyFigure,
                              fontSize: Tokens.type2Xl,
                              fontWeight: FontWeight.w600,
                              color: Tokens.inkMuted,
                            ),
                          ),
                        )
                      : AuthedImage(
                          fileId: id,
                          width: _photoSize,
                          height: _photoSize,
                          fit: BoxFit.cover,
                          fallback: Center(
                            child: Text(
                              name.trim().isEmpty
                                  ? '?'
                                  : name.trim()[0].toUpperCase(),
                              style: TextStyle(
                                fontFamily: Tokens.fontFamilyFigure,
                                fontSize: Tokens.type2Xl,
                                fontWeight: FontWeight.w600,
                                color: Tokens.inkMuted,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            SizedBox(width: Tokens.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeLg,
                      fontWeight: FontWeight.w600,
                      color: Tokens.ink,
                    ),
                  ),
                  SizedBox(height: Tokens.space1),
                  Text(
                    society,
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      color: Tokens.inkMuted,
                    ),
                  ),
                  SizedBox(height: Tokens.space1),
                  gate,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
