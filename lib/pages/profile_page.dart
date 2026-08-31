import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import '../theme/design_tokens.dart';
import '../ui/sg_primitives.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.profile});

  final ProfileService profile;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.displayName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    await widget.profile.setUploadedAvatar(path);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final user = FirebaseAuth.instance.currentUser;
    return AnimatedBuilder(
      animation: widget.profile,
      builder: (context, _) {
        return SafeArea(
          child: ListView(
            padding: EdgeInsets.all(t.gap(2)),
            children: [
              Row(
                children: [
                  ProfileAvatar(profile: widget.profile, size: 72),
                  SizedBox(width: t.gap(2)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.profile.greetingName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (user?.email != null)
                          Text(
                            user!.email!,
                            style: TextStyle(color: t.textMuted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.gap(2.5)),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                ),
                onSubmitted: widget.profile.setDisplayName,
              ),
              SizedBox(height: t.gap(1)),
              Align(
                alignment: Alignment.centerLeft,
                child: SgSecondaryButton(
                  label: 'Save name',
                  onPressed: () =>
                      widget.profile.setDisplayName(_nameCtrl.text),
                ),
              ),
              SizedBox(height: t.gap(3)),
              Text('Picture', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: t.gap(1)),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final opt in ProfileService.builtins)
                    _AvatarChoice(
                      asset: opt.asset,
                      label: opt.label,
                      selected: !widget.profile.hasCustomFile &&
                          widget.profile.avatarAsset == opt.asset,
                      onTap: () => widget.profile.setBuiltinAvatar(opt.asset),
                    ),
                ],
              ),
              SizedBox(height: t.gap(2)),
              SgSecondaryButton(
                label: 'Upload a photo',
                icon: Icons.add_photo_alternate_outlined,
                onPressed: _upload,
              ),
              SizedBox(height: t.gap(3)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.asset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String asset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? t.primaryAction : t.border,
                  width: selected ? 3 : 1,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  asset,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
