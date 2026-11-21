import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/repositories/retailer_repository.dart';

class RetailerProductImagePicker extends StatefulWidget {
  final String? initialImageUrl;
  final ValueChanged<String> onImageChanged;
  final String label;

  const RetailerProductImagePicker({
    super.key,
    this.initialImageUrl,
    required this.onImageChanged,
    this.label = 'Product / Dish Image',
  });

  @override
  State<RetailerProductImagePicker> createState() => _RetailerProductImagePickerState();
}

class _RetailerProductImagePickerState extends State<RetailerProductImagePicker> {
  String? _currentImage;
  bool _isUploading = false;
  final TextEditingController _urlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentImage = widget.initialImageUrl;
    if (_currentImage != null && _currentImage!.startsWith('http')) {
      _urlCtrl.text = _currentImage!;
    }
  }

  @override
  void didUpdateWidget(covariant RetailerProductImagePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImageUrl != oldWidget.initialImageUrl && widget.initialImageUrl != _currentImage) {
      setState(() {
        _currentImage = widget.initialImageUrl;
        if (_currentImage != null && _currentImage!.startsWith('http')) {
          _urlCtrl.text = _currentImage!;
        }
      });
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isUploading = true);
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (picked != null) {
        setState(() {
          _currentImage = picked.path;
          _urlCtrl.text = picked.path;
        });

        final repo = sl.isRegistered<IRetailerRepository>() ? sl<IRetailerRepository>() : null;
        if (repo != null) {
          final res = await repo.uploadDocument(picked.path, folder: 'products');
          if (mounted) {
            res.fold(
              (failure) {
                widget.onImageChanged(picked.path);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Attached locally. Server upload deferred: ${failure.message}'),
                    backgroundColor: const Color(0xFFD97706),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              (fileUpload) {
                final cloudUrl = fileUpload.url.isNotEmpty ? fileUpload.url : picked.path;
                setState(() {
                  _currentImage = cloudUrl;
                  _urlCtrl.text = cloudUrl;
                });
                widget.onImageChanged(cloudUrl);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Product image uploaded successfully!'),
                    backgroundColor: Color(0xFF059669),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            );
          }
        } else {
          widget.onImageChanged(picked.path);
        }
        if (mounted) setState(() => _isUploading = false);
      } else {
        if (mounted) setState(() => _isUploading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not attach image: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF10B981), size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Image Source',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF059669)),
                  ),
                  title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Snap a real-time picture of the product', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF2563EB)),
                  ),
                  title: const Text('Upload from Gallery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Choose a photo from your device storage', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.link_rounded, color: Color(0xFF9333EA)),
                  ),
                  title: const Text('Enter Web Image URL', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Paste a public HTTPS link to product picture', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showUrlInputDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUrlInputDialog() {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter Image URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: _urlCtrl,
          decoration: InputDecoration(
            hintText: 'https://example.com/item.jpg',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final link = _urlCtrl.text.trim();
              if (link.isNotEmpty) {
                setState(() => _currentImage = link);
                widget.onImageChanged(link);
              }
              Navigator.pop(dlgCtx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Save URL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _removeImage() {
    setState(() {
      _currentImage = null;
      _urlCtrl.clear();
    });
    widget.onImageChanged('');
  }

  Widget _buildImageWidget(String path) {
    final clean = path.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return Image.network(
        clean,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderError(),
      );
    } else {
      final actualPath = clean.startsWith('file://') ? clean.replaceFirst('file://', '') : clean;
      final file = File(actualPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholderError(),
        );
      }
      return _buildPlaceholderError();
    }
  }

  Widget _buildPlaceholderError() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 36),
            SizedBox(height: 6),
            Text('Image not found', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _currentImage != null && _currentImage!.trim().isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double containerHeight = constraints.maxWidth < 350 ? 130 : 150;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(width: 4),
                const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                const Spacer(),
                if (hasImage)
                  InkWell(
                    onTap: _showImageSourceSheet,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Change Image',
                        style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_isUploading)
              Container(
                height: containerHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF10B981)),
                      SizedBox(height: 10),
                      Text('Attaching image...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              )
            else if (hasImage)
              // Uploaded Preview Card (Responsive)
              Container(
                height: containerHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImageWidget(_currentImage!),
                      // Gradient scrim at bottom for text contrast
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      // Top Action Buttons
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          children: [
                            Material(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                onTap: _showImageSourceSheet,
                                borderRadius: BorderRadius.circular(20),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text('Edit', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Material(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.85),
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: _removeImage,
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(5),
                                  child: Icon(Icons.close_rounded, color: Colors.white, size: 15),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Bottom label
                      Positioned(
                        left: 10,
                        bottom: 8,
                        right: 10,
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 14),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _currentImage!.startsWith('http') ? 'Live Image Link Attached' : 'Local Photo Attached',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Upload Trigger Box (Responsive Dashed Aesthetic)
              InkWell(
                onTap: _showImageSourceSheet,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: containerHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF059669), size: 26),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Upload Product Image',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Camera • Gallery • Web URL',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
