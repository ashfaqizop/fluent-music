// One-off dev tool: generates the Ed25519 keypair used to sign the remote
// config (Masterdoc §6.5, §22). Run once; the private key must never be
// committed — hand it to `gh secret set REMOTE_CONFIG_PRIVATE_KEY` (or your
// CI secret store of choice) and discard the local copy immediately.
//
// A CLI tool's whole purpose is to print to stdout, so `avoid_print` is
// blanket-disabled for this file rather than justified line by line.
// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

Future<void> main() async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  final publicKey = await keyPair.extractPublicKey();
  final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

  print('Public key bytes (paste into signing_public_key.dart):');
  print(publicKey.bytes.join(', '));
  print('');
  print('Private key (base64 — store as a secret, never commit):');
  print(base64.encode(privateKeyBytes));
}
