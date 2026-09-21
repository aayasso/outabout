import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

/// Custom driver that captures the simulator screen via
/// xcrun simctl io after the integration test finishes.
///
/// The test renders a single shot and stays on screen.
/// The driver waits for the test to pass, then captures
/// the compositor output (including the native status bar).
Future<void> main() async {
  final driver = await FlutterDriver.connect();

  final jsonResult = await driver.requestData(
    null,
    timeout: const Duration(minutes: 5),
  );

  // Parse the result.
  final response = json.decode(jsonResult) as Map<String, dynamic>;
  final passed = response['result'] == 'true';

  if (!passed) {
    stderr.writeln(
      'Test failed:\n${response['failureDetails'] ?? jsonResult}',
    );
    await driver.close();
    exit(1);
  }

  // Capture screenshot via xcrun simctl io.
  final udid = Platform.environment['SCREENSHOT_UDID'];
  final dir = Platform.environment['SCREENSHOT_DIR'];
  final shot = Platform.environment['SHOT'];
  if (udid == null || dir == null || shot == null) {
    stderr.writeln(
      'Set SCREENSHOT_UDID, SCREENSHOT_DIR, and SHOT.',
    );
    await driver.close();
    exit(1);
  }

  // Small delay for the final frame to fully composite.
  await Future<void>.delayed(const Duration(seconds: 1));

  final path = '$dir/$shot.png';
  final result = await Process.run(
    'xcrun',
    ['simctl', 'io', udid, 'screenshot', path],
  );
  if (result.exitCode == 0) {
    stdout.writeln('Captured $path');
  } else {
    stderr.writeln(
      'xcrun simctl io screenshot failed: ${result.stderr}',
    );
    await driver.close();
    exit(1);
  }

  await driver.close();
  stdout.writeln('All tests passed.');
  exit(0);
}
