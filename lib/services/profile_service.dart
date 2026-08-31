import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileAvatarOption {
  const ProfileAvatarOption(this.id, this.label, this.asset);

  final String id;
  final String label;
  final String asset;
}

class ProfileService extends ChangeNotifier {
  ProfileService(this.uid);

  final String uid;

  static const builtins = <ProfileAvatarOption>[
    ProfileAvatarOption('wolf', 'Wolf', 'assets/avatars/wolf.png'),
    ProfileAvatarOption('fox', 'Fox', 'assets/avatars/fox.png'),
    ProfileAvatarOption('cat', 'Cat', 'assets/avatars/cat.png'),
    ProfileAvatarOption('panda', 'Panda', 'assets/avatars/panda.png'),
    ProfileAvatarOption('owl', 'Owl', 'assets/avatars/owl.png'),
    ProfileAvatarOption('fern', 'Fern', 'assets/avatars/fern.png'),
    ProfileAvatarOption('koi', 'Koi', 'assets/avatars/koi.png'),
    ProfileAvatarOption('moth', 'Moth', 'assets/avatars/moth.png'),
    ProfileAvatarOption('stag', 'Stag', 'assets/avatars/stag.png'),
  ];

  String displayName = '';
  String avatarAsset = builtins.first.asset;
  String? avatarFilePath;
  bool ready = false;

  bool get hasCustomFile =>
      avatarFilePath != null && File(avatarFilePath!).existsSync();

  ImageProvider get imageProvider {
    if (hasCustomFile) return FileImage(File(avatarFilePath!));
    return AssetImage(avatarAsset);
  }

  String get greetingName {
    final n = displayName.trim();
    if (n.isNotEmpty) return n;
    final user = FirebaseAuth.instance.currentUser;
    final named = user?.displayName?.trim();
    if (named != null && named.isNotEmpty) return named;
    final email = user?.email ?? '';
    final at = email.indexOf('@');
    if (at > 0) return email.substring(0, at);
    return 'You';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    displayName = prefs.getString('profile_name_$uid') ?? '';
    avatarAsset = prefs.getString('profile_avatar_$uid') ?? builtins.first.asset;
    avatarFilePath = prefs.getString('profile_avatar_file_$uid');
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data()?['profile'] as Map<String, dynamic>?;
      if (data != null) {
        displayName = (data['displayName'] as String?) ?? displayName;
        avatarAsset = (data['avatarAsset'] as String?) ?? avatarAsset;
      }
    } catch (_) {}
    ready = true;
    notifyListeners();
  }

  Future<void> setDisplayName(String name) async {
    displayName = name.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && displayName.isNotEmpty) {
      try {
        await user.updateDisplayName(displayName);
      } catch (_) {}
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setBuiltinAvatar(String asset) async {
    avatarAsset = asset;
    avatarFilePath = null;
    await _persist();
    notifyListeners();
  }

  Future<void> setUploadedAvatar(String sourcePath) async {
    final dir = await getApplicationSupportDirectory();
    final folder = Directory('${dir.path}/avatars');
    if (!folder.existsSync()) {
      await folder.create(recursive: true);
    }
    final ext = sourcePath.contains('.')
        ? sourcePath.substring(sourcePath.lastIndexOf('.'))
        : '.png';
    final dest = File('${folder.path}/$uid$ext');
    await File(sourcePath).copy(dest.path);
    avatarFilePath = dest.path;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name_$uid', displayName);
    await prefs.setString('profile_avatar_$uid', avatarAsset);
    if (avatarFilePath == null) {
      await prefs.remove('profile_avatar_file_$uid');
    } else {
      await prefs.setString('profile_avatar_file_$uid', avatarFilePath!);
    }
    if (uid.isEmpty || uid == 'NO_USER') return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'profile': {
          'displayName': displayName,
          'avatarAsset': avatarAsset,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.profile,
    this.size = 32,
  });

  final ProfileService profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image(
        image: profile.imageProvider,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => CircleAvatar(
          radius: size / 2,
          child: Text(
            profile.greetingName.isEmpty
                ? '?'
                : profile.greetingName[0].toUpperCase(),
          ),
        ),
      ),
    );
  }
}
