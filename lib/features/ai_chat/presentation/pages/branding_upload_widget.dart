import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../bloc/chat_bloc.dart';
import '../../bloc/chat_event.dart';

/// Shows an attachment button in chat when bill branding flow is active.
/// Triggered by [BillStep.collectingLogo] or [BillStep.collectingSignature].
///
/// Usage — insert this below the chat input bar when [showType] is set:
///   BrandingUploadWidget(imageType: 'logo')
///   BrandingUploadWidget(imageType: 'signature')
class BrandingUploadWidget extends StatefulWidget {
  /// 'logo' or 'signature'
  final String imageType;

  const BrandingUploadWidget({super.key, required this.imageType});

  @override
  State<BrandingUploadWidget> createState() => _BrandingUploadWidgetState();
}

class _BrandingUploadWidgetState extends State<BrandingUploadWidget> {
  final _picker = ImagePicker();
  bool _uploading = false;

  String get _label =>
      widget.imageType == 'logo' ? 'Company Logo' : 'Signature';
  IconData get _icon =>
      widget.imageType == 'logo' ? Icons.business : Icons.draw;

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
      );
      if (picked == null) return;
      setState(() => _uploading = true);
      if (!mounted) return;
      context.read<ChatBloc>().add(BrandingImageUploadedEvent(
        imageFile: File(picked.path),
        imageType: widget.imageType,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image select nahi ho payi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: _uploading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text('Upload ho raha hai...',
                    style: theme.textTheme.bodySmall),
              ],
            )
          : Row(
              children: [
                Icon(_icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_label upload karein',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Camera button
                _SourceButton(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () => _pick(ImageSource.camera),
                ),
                const SizedBox(width: 6),
                // Gallery button
                _SourceButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () => _pick(ImageSource.gallery),
                ),
              ],
            ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onPrimary),
            const SizedBox(width: 4),
            Text(label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}
