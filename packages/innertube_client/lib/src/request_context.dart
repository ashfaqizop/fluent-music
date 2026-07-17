import 'package:innertube_client/src/client_identity.dart';
import 'package:remote_config/remote_config.dart';

/// Builds the InnerTube request `context` block for [identity], merging in
/// any [RemoteConfig.identityOverrides] entry for that identity so a stale
/// `clientVersion` can be patched remotely without an app update (§6.5).
Map<String, dynamic> buildContext(
  ClientIdentity identity, {
  String? visitorData,
  RemoteConfig? remoteConfig,
}) {
  final override = remoteConfig?.identityOverrides[identity.name];
  final clientVersion = override?.clientVersion ?? identity.clientVersion;

  return {
    'context': {
      'client': {
        'clientName': identity.clientName,
        'clientVersion': clientVersion,
        'hl': identity.hl,
        'gl': identity.gl,
        if (visitorData != null) 'visitorData': visitorData,
        ...identity.extraContext,
      },
    },
  };
}
