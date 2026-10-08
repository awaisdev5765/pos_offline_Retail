import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/app_snack_bar.dart';

/// A widget that wraps content with drag-and-drop file upload support
class DragDropArea extends StatefulWidget {
  final Widget child;
  final Function(List<File>)? onFilesDropped;
  final List<String>? allowedExtensions;
  final String? allowedExtensionsMessage;
  final bool enabled;

  const DragDropArea({
    super.key,
    required this.child,
    this.onFilesDropped,
    this.allowedExtensions,
    this.allowedExtensionsMessage,
    this.enabled = true,
  });

  @override
  State<DragDropArea> createState() => _DragDropAreaState();
}

class _DragDropAreaState extends State<DragDropArea> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    // Only enable drag-and-drop on desktop platforms
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return widget.child;
    }

    if (!widget.enabled) {
      return widget.child;
    }

    return DropTarget(
      onDragDone: (detail) async {
        if (widget.onFilesDropped == null) return;

        try {
          final files = <File>[];
          for (final file in detail.files) {
            final filePath = file.path;
            if (filePath.isNotEmpty) {
              final fileObj = File(filePath);
              if (await fileObj.exists()) {
                // Check file extension if specified
                if (widget.allowedExtensions != null) {
                  final extension = filePath.split('.').last.toLowerCase();
                  if (widget.allowedExtensions!
                      .any((ext) => ext.toLowerCase() == extension)) {
                    files.add(fileObj);
                  }
                } else {
                  files.add(fileObj);
                }
              }
            }
          }

          if (files.isEmpty) {
            if (!mounted) return;
            final currentContext = context;
            if (currentContext.mounted) {
              AppSnackBar.show(
                currentContext,
                SnackBar(
                  content: Text(
                    widget.allowedExtensionsMessage ??
                        'No valid files dropped',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }

          widget.onFilesDropped!(files);
        } catch (e) {
          if (!mounted) return;
          final currentContext = context;
          if (currentContext.mounted) {
            AppSnackBar.show(
              currentContext,
              SnackBar(
                content: Text('Error processing dropped files: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      onDragEntered: (detail) {
        setState(() {
          _isDragging = true;
        });
      },
      onDragExited: (detail) {
        setState(() {
          _isDragging = false;
        });
      },
      child: Stack(
        children: [
          widget.child,
          if (_isDragging)
            Container(
              color: Colors.blue.withValues(alpha: 0.1),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_upload,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Drop files here',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.allowedExtensions != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Allowed: ${widget.allowedExtensions!.join(", ")}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Helper widget for file picker button with drag-drop support
class FileUploadWidget extends StatelessWidget {
  final Function(List<File>) onFilesSelected;
  final List<String>? allowedExtensions;
  final String buttonText;
  final IconData icon;
  final bool enableDragDrop;
  final String? dragDropMessage;

  const FileUploadWidget({
    super.key,
    required this.onFilesSelected,
    this.allowedExtensions,
    this.buttonText = 'Select Files',
    this.icon = Icons.upload_file,
    this.enableDragDrop = true,
    this.dragDropMessage,
  });

  Future<void> _pickFiles(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null
            ? FileType.custom
            : FileType.any,
        allowedExtensions: allowedExtensions,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final files = result.files
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .where((f) => f.existsSync())
            .toList();

        if (files.isNotEmpty) {
          onFilesSelected(files);
        } else {
          if (context.mounted) {
            AppSnackBar.show(
              context,
              const SnackBar(
                content: Text('No valid files selected'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error selecting files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = ElevatedButton.icon(
      onPressed: () => _pickFiles(context),
      icon: Icon(icon),
      label: Text(buttonText),
    );

    if (enableDragDrop) {
      return DragDropArea(
        onFilesDropped: onFilesSelected,
        allowedExtensions: allowedExtensions,
        allowedExtensionsMessage: dragDropMessage,
        child: content,
      );
    }

    return content;
  }
}

