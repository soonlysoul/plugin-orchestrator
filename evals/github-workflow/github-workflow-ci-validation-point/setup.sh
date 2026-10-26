#!/usr/bin/env bash
# A plugin-orchestrator project with one Flutter part, on main, clean, without a remote and
# without any workflow under .github/: the CI template belongs to plugin-flutter (a mandate to its
# devops agent), and nothing is written before the user approves what the CI will run and what
# it costs. No checkpoint yet: this is the first workflow run on the project.
set -euo pipefail
mkdir -p .forge lib test docs/product
cat >.forge/config.yaml <<'YAML'
schema_version: 2
project:
  default_branch: main
  branch_prefix: feature
authorizations:
  push_feature_branches: false
parts:
  app:
    path: .
    plugin: plugin-flutter
    interface: 1
    toolchain:
      test: flutter test
      format: dart format --output=none --set-exit-if-changed .
      analyze: flutter analyze
      add_dep: flutter pub add
      manifests: [pubspec.yaml, pubspec.lock]
    platforms: [android, web, linux]
YAML
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
cat >docs/product/PRD.md <<'MD'
# PRD — notes_app

| Field | Value |
| --- | --- |
| Status | APPROVED |
| Approved | 2026-10-20 |

## Problem

Notes typed on the phone are lost between sessions.

## Acceptance criteria

- AC-001 — The app opens on a screen titled Notes.
MD
printf '# notes_app\n\nA Flutter notes app, part of a plugin-orchestrator project.\n' >README.md
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
git commit -qm "chore: scaffold notes_app (AC-001)"
