#!/usr/bin/env bash
# An existing Flutter app, committed on main, clean, without .forge/ and without any project
# document: it is not a new project, so bootstrap-project stops and points to the adoption
# workflow of the app's language plugin (plugin-flutter's adopt-existing-project) instead of
# creating anything.
set -euo pipefail
mkdir -p lib test
cat >pubspec.yaml <<'YAML'
name: notes_app
description: A notes app.
publish_to: none
version: 0.1.0+1

environment:
  sdk: ^3.5.0

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
YAML
cat >lib/main.dart <<'DART'
import 'package:flutter/material.dart';

void main() => runApp(const NotesApp());

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Notes'))),
    );
  }
}
DART
cat >test/widget_test.dart <<'DART'
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/main.dart';

void main() {
  testWidgets('shows the title', (tester) async {
    await tester.pumpWidget(const NotesApp());
    expect(find.text('Notes'), findsOneWidget);
  });
}
DART
printf '# notes_app\n\nA Flutter notes app.\n' >README.md
cat >.gitignore <<'IGNORE'
build/
.dart_tool/
pubspec.lock
# Files an editor or a sandbox seeds in the workspace (some as plain files: no trailing slash)
.bashrc
.bash_profile
.profile
.zshrc
.zprofile
.gitconfig
.gitmodules
.ripgreprc
.mcp.json
.idea
.vscode
.claude
.eval-artifacts
IGNORE
git init -q -b main
git config user.name test
git config user.email test@example.invalid
git add -A
git commit -qm "chore: scaffold notes_app"
