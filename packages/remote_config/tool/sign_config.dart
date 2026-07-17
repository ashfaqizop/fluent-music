// Publishing CLI: signs a plaintext remote-config JSON payload, producing
// the signed envelope the app fetches at runtime (Masterdoc §6.5).
//
// Usage:
//   dart run packages/remote_config/tool/sign_config.dart \
//     --in remote-config/remote_config.json \
//     --private-key-b64 "$REMOTE_CONFIG_PRIVATE_KEY" \
//     --out remote-config/remote_config.signed.json
//
// The private key is only ever passed as an argument/env value for this one
// signing operation — this script never writes it to disk (§22).
//
// A CLI tool's whole purpose is to print to stdout, so `avoid_print` is
// blanket-disabled for this file rather than justified line by line.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:remote_config/remote_config.dart';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  if (options == null) {
    print(
      'Usage: dart run tool/sign_config.dart --in <path> '
      '--private-key-b64 <base64> --out <path>',
    );
    exitCode = 64;
    return;
  }

  final plaintext = await File(options.inputPath).readAsString();
  final payload = jsonDecode(plaintext) as Map<String, dynamic>;
  final canonicalBytes = utf8.encode(canonicalize(payload));

  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(
    base64.decode(options.privateKeyB64),
  );
  final signature = await algorithm.sign(canonicalBytes, keyPair: keyPair);

  final envelope = {
    'payload': payload,
    'signature': base64.encode(signature.bytes),
  };

  final outFile = File(options.outputPath);
  await outFile.create(recursive: true);
  await outFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(envelope),
  );

  print('Signed config written to ${options.outputPath}.');
}

final class _Options {
  const _Options({
    required this.inputPath,
    required this.privateKeyB64,
    required this.outputPath,
  });

  final String inputPath;
  final String privateKeyB64;
  final String outputPath;
}

_Options? _parseArgs(List<String> args) {
  String? inputPath;
  String? privateKeyB64;
  String? outputPath;

  for (var i = 0; i < args.length - 1; i++) {
    switch (args[i]) {
      case '--in':
        inputPath = args[i + 1];
      case '--private-key-b64':
        privateKeyB64 = args[i + 1];
      case '--out':
        outputPath = args[i + 1];
    }
  }

  if (inputPath == null || privateKeyB64 == null || outputPath == null) {
    return null;
  }
  return _Options(
    inputPath: inputPath,
    privateKeyB64: privateKeyB64,
    outputPath: outputPath,
  );
}
