import 'package:flutter/material.dart';

import '../services/update_service.dart';

/// Prüft auf ein Update und zeigt bei Bedarf den Dialog. Fehler werden still
/// verschluckt (kein Internet o.Ä.).
Future<void> maybePromptUpdate(BuildContext context) async {
  final update = await UpdateService().check();
  if (update == null || !context.mounted) return;
  await showDialog(
    context: context,
    builder: (_) => UpdateDialog(update: update),
  );
}

class UpdateDialog extends StatefulWidget {
  final UpdateInfo update;
  const UpdateDialog({super.key, required this.update});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await UpdateService().downloadAndInstall(widget.update);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Download fehlgeschlagen. Später erneut versuchen.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update verfügbar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Version ${widget.update.version} ist verfügbar.'),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Lade herunter…'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Später'),
        ),
        FilledButton(
          onPressed: _busy ? null : _install,
          child: const Text('Jetzt aktualisieren'),
        ),
      ],
    );
  }
}
