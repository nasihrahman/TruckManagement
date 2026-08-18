import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

/// Picks a photo (camera or gallery), compresses it client-side via
/// [ImagePicker]'s own quality/dimension constraints before it ever leaves
/// the device, uploads it, and reports back the hosted URL.
class PhotoPickerField extends StatefulWidget {
  const PhotoPickerField({
    super.key,
    required this.apiService,
    required this.photoUrl,
    required this.onChanged,
  });

  final ApiService apiService;
  final String? photoUrl;
  final ValueChanged<String?> onChanged;

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  bool _isUploading = false;

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? picked;
    try {
      picked = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1600,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await widget.apiService.uploadImage(bytes, picked.name);
      widget.onChanged(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _showSourcePicker() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pick(source);
  }

  @override
  Widget build(BuildContext context) {
    if (_isUploading) {
      return const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final photoUrl = widget.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              photoUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 160,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton.filled(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => widget.onChanged(null),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
            ),
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: _showSourcePicker,
      icon: const Icon(Icons.add_a_photo_outlined),
      label: const Text('Add Photo'),
    );
  }
}
