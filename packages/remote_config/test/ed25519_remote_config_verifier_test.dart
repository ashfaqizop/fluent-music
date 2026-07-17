import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:remote_config/remote_config.dart';
import 'package:test/test.dart';

void main() {
  group('Ed25519RemoteConfigVerifier', () {
    late Ed25519 algorithm;
    late SimpleKeyPair keyPair;
    late List<int> publicKeyBytes;
    late List<int> payload;
    late List<int> signature;

    setUp(() async {
      algorithm = Ed25519();
      keyPair = await algorithm.newKeyPair();
      publicKeyBytes = (await keyPair.extractPublicKey()).bytes;
      payload = utf8.encode('{"schemaVersion":2}');
      signature = (await algorithm.sign(payload, keyPair: keyPair)).bytes;
    });

    test('accepts a validly-signed payload', () async {
      final verifier = Ed25519RemoteConfigVerifier(
        publicKeyBytes: publicKeyBytes,
      );
      final result = await verifier.verify(
        payload: payload,
        signature: signature,
      );
      expect(result, isTrue);
    });

    test('rejects a tampered payload', () async {
      final verifier = Ed25519RemoteConfigVerifier(
        publicKeyBytes: publicKeyBytes,
      );
      final tamperedPayload = utf8.encode('{"schemaVersion":999}');
      final result = await verifier.verify(
        payload: tamperedPayload,
        signature: signature,
      );
      expect(result, isFalse);
    });

    test('rejects a tampered signature', () async {
      final verifier = Ed25519RemoteConfigVerifier(
        publicKeyBytes: publicKeyBytes,
      );
      final tamperedSignature = [...signature]..[0] = signature[0] ^ 0xFF;
      final result = await verifier.verify(
        payload: payload,
        signature: tamperedSignature,
      );
      expect(result, isFalse);
    });

    test('rejects a signature made with a different key pair', () async {
      final otherKeyPair = await algorithm.newKeyPair();
      final otherPublicKeyBytes = (await otherKeyPair.extractPublicKey()).bytes;

      final verifier = Ed25519RemoteConfigVerifier(
        publicKeyBytes: otherPublicKeyBytes,
      );
      final result = await verifier.verify(
        payload: payload,
        signature: signature,
      );
      expect(result, isFalse);
    });
  });
}
