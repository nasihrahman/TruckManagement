import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Opens Android/iOS's native "Save As" dialog and writes the bytes directly
/// to wherever the user picks (Downloads, etc.) — a real download, not a
/// share-sheet detour. Returns false if the user cancelled the dialog.
Future<bool> downloadBytes(Uint8List bytes, String filename) async {
  final path = await FilePicker.platform.saveFile(
    fileName: filename,
    bytes: bytes,
  );
  return path != null;
}
