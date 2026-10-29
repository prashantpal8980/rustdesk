// Custom: send an image pasted from the soft keyboard clipboard to the remote
// PC's upload receiver (see ~/remote-control/bin/inbox-receiver.py there) and
// return the path it was saved to.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../common.dart';

const _kUploadPort = 8765;
const _kTokenOption = 'custom-upload-token';

// Peer ids for direct IP connections look like `100.108.134.11` or
// `100.108.134.11:21118`.
String? _hostFromPeerId(String id) {
  final host = id.split(':').first;
  return RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host) ? host : null;
}

Future<String?> _askToken() {
  final controller = TextEditingController();
  return Get.dialog<String>(AlertDialog(
    title: const Text('Upload token'),
    content: TextField(
      controller: controller,
      autofocus: true,
      obscureText: true,
      decoration: const InputDecoration(
          hintText: 'Token from ~/remote-control/token on the PC'),
    ),
    actions: [
      TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
      TextButton(
          onPressed: () => Get.back(result: controller.text.trim()),
          child: const Text('Save')),
    ],
  ));
}

/// Returns the path of the saved file on the remote PC, or null on failure.
Future<String?> uploadImageToPeer(
    String peerId, Uint8List data, String mimeType) async {
  final host = _hostFromPeerId(peerId);
  if (host == null) {
    showToast('Image upload needs a direct IP connection');
    return null;
  }
  var token = bind.mainGetLocalOption(key: _kTokenOption);
  if (token.isEmpty) {
    token = (await _askToken()) ?? '';
    if (token.isEmpty) return null;
    await bind.mainSetLocalOption(key: _kTokenOption, value: token);
  }
  try {
    final res = await http
        .post(Uri.parse('http://$host:$_kUploadPort/upload'),
            headers: {'X-Token': token, 'Content-Type': mimeType}, body: data)
        .timeout(const Duration(seconds: 30));
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as Map)['path'] as String?;
    }
    if (res.statusCode == 401) {
      // Wrong token: forget it so the next paste asks again.
      await bind.mainSetLocalOption(key: _kTokenOption, value: '');
    }
    showToast('Image upload failed (${res.statusCode})');
  } catch (e) {
    showToast('Image upload failed: $e');
  }
  return null;
}
