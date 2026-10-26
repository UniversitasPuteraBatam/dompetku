import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/user_profile.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
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
  Widget build(BuildContext context) {
    final hasPhoto = _photoBytes != null || _profilePhoto != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      decoration: BoxDecoration(
                        color: context.palette.surface,
                        border: Border.all(color: context.palette.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _isSaving ? null : _choosePhoto,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ProfileAvatar(
                                  photoBytes: _photoBytes,
                                  photoUrl: _profilePhoto,
                                  radius: 48,
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: context.palette.surface,
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.photo_camera_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Foto Profil',
                            style: TextStyle(
                              color: context.palette.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Format JPG atau PNG',
                            style: TextStyle(
                              color: context.palette.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: _photoButtonStyle,
                                  onPressed: _isSaving ? null : _choosePhoto,
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    hasPhoto ? 'Ganti Foto' : 'Pilih Foto',
                                  ),
                                ),
                              ),
                              if (hasPhoto) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: _photoButtonStyle.copyWith(
                                      foregroundColor: WidgetStatePropertyAll(
                                        context.palette.danger,
                                      ),
                                      side: WidgetStatePropertyAll(
                                        BorderSide(
                                          color: context.palette.danger
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                    onPressed: _isSaving ? null : _removePhoto,
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Hapus Foto',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Informasi Akun',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: context.palette.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                      validator: (value) =>
                          value == null || value.trim().isEmpty
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
                      style: TextStyle(color: context.palette.secondaryText),
                      decoration: InputDecoration(
                        hintText: 'nama@email.com',
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                        suffixIcon: Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: context.palette.secondaryText,
                        ),
                        helperText:
                            'Email digunakan untuk login dan tidak dapat diubah.',
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
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Simpan'),
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
}

final _photoButtonStyle = OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(42),
  padding: const EdgeInsets.symmetric(horizontal: 10),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);
