import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    this.photoBytes,
    this.photoUrl,
    this.radius = 42,
  });

  final Uint8List? photoBytes;
  final String? photoUrl;
  final double radius;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool _networkPhotoFailed = false;

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) _networkPhotoFailed = false;
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = widget.photoUrl;
    final isNetworkPhoto =
        photoUrl != null &&
        !_networkPhotoFailed &&
        (Uri.tryParse(photoUrl)?.scheme == 'http' ||
            Uri.tryParse(photoUrl)?.scheme == 'https');
    final ImageProvider? image = widget.photoBytes != null
        ? MemoryImage(widget.photoBytes!)
        : isNetworkPhoto
        ? NetworkImage(photoUrl)
        : null;

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: const Color(0xFFDBEAFE),
      backgroundImage: image,
      onBackgroundImageError: image is NetworkImage
          ? (_, _) {
              if (mounted) setState(() => _networkPhotoFailed = true);
            }
          : null,
      child: image == null
          ? Icon(
              Icons.person_rounded,
              size: widget.radius,
              color: AppColors.primary,
            )
          : null,
    );
  }
}
