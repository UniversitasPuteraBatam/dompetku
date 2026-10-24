import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/user_profile.dart';
import '../services/auth_service.dart';
import '../widgets/field_label.dart';
import '../widgets/profile_avatar.dart';

typedef ProfilePhotoPicker = Future<Uint8List?> Function();

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
    required this.authService,
    this.photoPicker,
  });

  final UserProfile profile;
  final AuthService authService;
  final ProfilePhotoPicker? photoPicker;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  Uint8List? _photoBytes;
  String? _profilePhoto;
  bool _photoChanged = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.profile.name;
    _emailController.text = widget.profile.email;
    _photoBytes = widget.profile.photoBytes;
    _profilePhoto = widget.profile.profilePhoto;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      var user = await widget.authService.updateProfile(
        name: _nameController.text.trim(),
      );
      if (_photoChanged) {
        final photoBytes = _photoBytes;
        user = photoBytes != null
            ? await widget.authService.uploadProfilePhoto(photoBytes)
            : await widget.authService.deleteProfilePhoto();
      }
      if (!mounted) return;

      Navigator.pop(
        context,
        UserProfile(
          name: user.name,
          email: user.email,
          photoBytes: _photoBytes,
          profilePhoto: widget.authService.resolvePhotoUrl(user.profilePhoto),
        ),
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat terhubung ke server. Periksa koneksi.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _removePhoto() {
    setState(() {
      _photoBytes = null;
      _profilePhoto = null;
      _photoChanged = true;
    });
  }

  Future<void> _choosePhoto() async {
    try {
      final Uint8List? photoBytes;
      if (widget.photoPicker != null) {
        photoBytes = await widget.photoPicker!.call();
      } else {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1200,
          imageQuality: 85,
          requestFullMetadata: false,
        );
        if (image == null) return;
        photoBytes = await image.readAsBytes();
      }
      if (photoBytes == null || !mounted) return;
      setState(() {
        _photoBytes = photoBytes;
        _photoChanged = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto tidak dapat dipilih. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit Profile')),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Column(
                      children: [
                        ProfileAvatar(
                          photoBytes: _photoBytes,
                          photoUrl: _profilePhoto,
                          radius: 52,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _choosePhoto,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(
                            _photoBytes == null ? 'Pilih Foto' : 'Ganti Foto',
                          ),
                        ),
                        if (_photoBytes != null || _profilePhoto != null) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _isSaving ? null : _removePhoto,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Hapus Foto Profil'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const FieldLabel('Nama lengkap'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Nama lengkap',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nama wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  const FieldLabel('Email'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    readOnly: true,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    onFieldSubmitted: (_) => _save(),
                    decoration: const InputDecoration(
                      hintText: 'nama@email.com',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'Email wajib diisi';
                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(email)) {
                        return 'Masukkan alamat email yang valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: const Text('Simpan'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
