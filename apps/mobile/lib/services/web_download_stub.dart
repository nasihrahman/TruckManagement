import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// On Android/iOS there's no browser download bar, so the exported file is
/// written to a temp dir and handed to the OS share sheet — the user picks
/// "Save to Files", opens it directly in Excel, shares via WhatsApp, etc.
Future<void> downloadBytes(Uint8List bytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)], text: filename);
}
