import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/tr_text.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  static const routeName = '/feedback';

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  static const String _email = 'view.set.right@gmail.com';
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: TrText(msg)));
  }

  Future<void> _send() async {
    if (_sending) return;
    final msg = _messageCtrl.text.trim();
    if (msg.isEmpty) {
      _snack('Please write a message');
      return;
    }

    setState(() => _sending = true);
    try {
      const subjectRaw = 'All Habesha Feedback';
      final subject = Uri.encodeComponent(subjectRaw);
      final body = Uri.encodeComponent(msg);
      final mailUri = Uri.parse('mailto:$_email?subject=$subject&body=$body');

      // iOS Simulator often can't open the Mail app; use safe fallbacks.
      final okMail = await launchUrl(mailUri, mode: LaunchMode.platformDefault);
      if (!okMail) {
        final webCompose = Uri.parse(
          'https://mail.google.com/mail/?view=cm&fs=1&to=${Uri.encodeComponent(_email)}&su=$subject&body=$body',
        );
        final okWeb =
            await launchUrl(webCompose, mode: LaunchMode.externalApplication);
        if (!okWeb) {
          await Clipboard.setData(
            ClipboardData(
              text: 'To: $_email\nSubject: $subjectRaw\n\n$msg',
            ),
          );
          _snack('Mail app unavailable. Copied to clipboard.');
        }
      }
    } catch (e) {
      _snack('Send failed: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TrText('Feedback / Contact us'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TrText(
              'Tell us what to improve, report a bug, or request a feature.',
              translate: false,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _messageCtrl,
              decoration: const InputDecoration(
                label: TrText('Message'),
                border: OutlineInputBorder(),
              ),
              minLines: 5,
              maxLines: 10,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: TrText(_sending ? 'Sending...' : 'Send'),
            ),
          ],
        ),
      ),
    );
  }
}
