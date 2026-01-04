import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/category.dart';
import '../state/category_providers.dart';
import '../state/providers.dart';
import '../state/sponsored_providers.dart';

class AddListingScreen extends ConsumerStatefulWidget {
  const AddListingScreen({super.key});
  static const routeName = '/add-listing';

  @override
  ConsumerState<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends ConsumerState<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _saving = false;
  bool _promoting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _log(String msg) => debugPrint('[AddListing] $msg');

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showError(Object e, StackTrace st) {
    _log('ERROR: $e');
    _log('$st');
    _snack('$e');
  }

  bool _validateOrExplain({required String actionLabel}) {
    final valid = _formKey.currentState?.validate() ?? false;
    _log('$actionLabel: validate => $valid');
    if (!valid) {
      _snack('Fix required fields first');
      return false;
    }
    return true;
  }

  Future<T> _run<T>({
    required String label,
    required void Function(bool on) setLoading,
    required Future<T> Function() fn,
  }) async {
    _log(
        '$label: start (mounted=$mounted saving=$_saving promoting=$_promoting)');
    setLoading(true);

    try {
      final out = await fn();
      _log('$label: success');
      return out;
    } catch (e, st) {
      _log('$label: failed => $e');
      _showError(e, st);
      rethrow;
    } finally {
      if (mounted) {
        setLoading(false);
        _log('$label: end (saving=$_saving promoting=$_promoting)');
      } else {
        _log('$label: end (NOT mounted)');
      }
    }
  }

  Future<String> _createEntity() async {
    final category = ref.read(selectedCategoryProvider);
    if (category == null) {
      throw Exception('Category required');
    }

    final uri = Uri.parse('$apiBaseUrl/entities');

    final body = <String, dynamic>{
      "categoryId": category.id,
      "name": _nameCtrl.text.trim(),
      "address": _addressCtrl.text.trim(),
      "contactPhone": _phoneCtrl.text.trim(),
      "remote": false,
    };

    _log('CREATE ENTITY: POST $uri');
    _log('CREATE ENTITY BODY: ${jsonEncode(body)}');

    final res = await http
        .post(
          uri,
          headers: const {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));

    _log('CREATE ENTITY: status=${res.statusCode} body=${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Create entity failed: ${res.statusCode} ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final id = decoded['id'];

    if (id == null || (id is String && id.trim().isEmpty)) {
      throw Exception('Create entity returned no id: ${res.body}');
    }

    final entityId = id.toString();
    _log('CREATE ENTITY: id=$entityId');
    return entityId;
  }

  Future<void> _startCheckout({required String entityId}) async {
    final uri = Uri.parse('$apiBaseUrl/payments/checkout-session');

    final payload = <String, dynamic>{
      "entityId": entityId,
      "promotionTier": "homeSponsored",
    };

    _log('CHECKOUT: POST $uri');
    _log('CHECKOUT BODY: ${jsonEncode(payload)}');

    final res = await http
        .post(
          uri,
          headers: const {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 25));

    _log('CHECKOUT: status=${res.statusCode} body=${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Checkout session failed: ${res.statusCode} ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final checkoutUrl = decoded['checkoutUrl'];

    if (checkoutUrl == null || checkoutUrl.toString().trim().isEmpty) {
      throw Exception('checkoutUrl missing in response: ${res.body}');
    }

    final uriToLaunch = Uri.tryParse(checkoutUrl.toString());
    if (uriToLaunch == null) {
      throw Exception('Invalid checkoutUrl: $checkoutUrl');
    }

    _log('CHECKOUT: launching => $uriToLaunch');

    final ok = await launchUrl(
      uriToLaunch,
      mode: LaunchMode.externalApplication,
    );

    _log('CHECKOUT: launchUrl ok=$ok');
    ref.invalidate(homeSponsoredProvider);

    if (!ok) {
      throw Exception('Could not open Stripe: $checkoutUrl');
    }
  }

  Future<void> _onSave() async {
    _log(
        'SAVE: tapped (saving=$_saving promoting=$_promoting mounted=$mounted)');
    _snack('Save tapped');

    if (_saving || _promoting) return;
    if (!_validateOrExplain(actionLabel: 'SAVE')) return;

    await _run<void>(
      label: 'SAVE FLOW',
      setLoading: (on) => setState(() => _saving = on),
      fn: () async {
        await _createEntity();
        if (!mounted) return;
        Navigator.of(context).pop(true);
      },
    );
  }

  Future<void> _onSaveAndPromote() async {
    _log(
        'SAVE&PROMOTE: tapped (saving=$_saving promoting=$_promoting mounted=$mounted)');
    _snack('Save & Promote tapped');

    if (_saving || _promoting) return;
    if (!_validateOrExplain(actionLabel: 'SAVE&PROMOTE')) return;

    await _run<void>(
      label: 'SAVE&PROMOTE FLOW',
      setLoading: (on) => setState(() => _promoting = on),
      fn: () async {
        final entityId = await _createEntity();
        await _startCheckout(entityId: entityId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _log('BUILD: saving=$_saving promoting=$_promoting');

    final categories = ref.watch(categoriesProvider); // <-- List<AppCategory>
    final selected = ref.watch(selectedCategoryProvider);

    Widget buttonSpinner() => const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        );

    // This prevents a blank dropdown if categories failed to load upstream
    final hasCategories = categories.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Add your listing')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<AppCategory>(
                value: hasCategories ? selected : null,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                ),
                items: categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.emoji} ${c.title}'),
                      ),
                    )
                    .toList(),
                onChanged: hasCategories
                    ? (v) {
                        _log('Category changed => ${v?.id}');
                        ref.read(selectedCategoryProvider.notifier).state = v;
                      }
                    : null,
                validator: (v) => v == null ? 'Required' : null,
              ),
              if (!hasCategories)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'No categories available. Check categoriesProvider.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Business name *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: (_saving || _promoting) ? null : _onSave,
                child: _saving ? buttonSpinner() : const Text('Save'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: (_saving || _promoting) ? null : _onSaveAndPromote,
                child:
                    _promoting ? buttonSpinner() : const Text('Save & Promote'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
