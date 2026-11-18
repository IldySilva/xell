import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xell/features/hosts/models/ssh_host.dart';
import 'package:xell/features/hosts/services/host_key_verifier.dart';
import 'package:xell/features/terminal/views/host_key_prompt_dialog.dart';

const _host = SshHost(
  id: 'h',
  name: 'web',
  hostname: 'web.example',
  port: 22,
  username: 'deploy',
  authType: AuthType.password,
);

Future<bool?> _open(WidgetTester tester, HostKeyCheck check, String tap) async {
  bool? result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async =>
            result = await showHostKeyPromptDialog(context, _host, check),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(tap));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  const unknown = HostKeyCheck(
    status: HostKeyStatus.unknown,
    hostPort: 'web.example',
    fingerprint: 'SHA256:new',
  );
  const changed = HostKeyCheck(
    status: HostKeyStatus.changed,
    hostPort: 'web.example',
    fingerprint: 'SHA256:new',
    previous: 'SHA256:old',
  );

  testWidgets('unknown: shows fingerprint, trust returns true', (tester) async {
    expect(await _open(tester, unknown, 'Trust and connect'), isTrue);
  });

  testWidgets('unknown: cancel returns false', (tester) async {
    expect(await _open(tester, unknown, 'Cancel'), isFalse);
  });

  testWidgets('changed: shows both fingerprints and the warning', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: HostKeyPromptDialog(host: _host, check: changed)),
    ));
    expect(find.text('Host key changed'), findsOneWidget);
    expect(find.text('SHA256:old'), findsOneWidget);
    expect(find.text('SHA256:new'), findsOneWidget);
    expect(find.text('Replace key and connect'), findsOneWidget);
  });

  testWidgets('changed: cancel returns false', (tester) async {
    expect(await _open(tester, changed, 'Cancel'), isFalse);
  });
}
