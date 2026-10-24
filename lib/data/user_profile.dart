import 'dart:typed_data';

class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    this.photoBytes,
    this.profilePhoto,
  });

  final String name;
  final String email;

  /// Photo picked in this session, shown right away instead of downloading
  /// the uploaded copy again.
  final Uint8List? photoBytes;

  /// Full URL of the photo stored on the server.
  final String? profilePhoto;
}
