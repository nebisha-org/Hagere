import '../config/env.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import '../data/habesha_cities.dart';
import '../models/category.dart';
import '../state/category_providers.dart';
import '../state/override_providers.dart';
import '../state/providers.dart';
import '../state/sponsored_providers.dart';
import '../state/stripe_mode_provider.dart';
import '../state/translation_provider.dart';
import '../widgets/tr_text.dart';

class AddListingScreen extends ConsumerStatefulWidget {
  const AddListingScreen({super.key});
  static const routeName = '/add-listing';

  @override  
  ConsumerState<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends ConsumerState<AddListingScreen> {
  static const bool _skipStripeLaunch =
      bool.fromEnvironment('SKIP_STRIPE_LAUNCH', defaultValue: false);
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _photoUrlsCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();

  bool _authUnlocked = false;
  bool _authWorking = false;
  String? _authLabel;
  StreamSubscription<User?>? _authSub;
  Future<void>? _googleInit;
  final _instagramCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _mapLinkCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  List<HabeshaCity> _selectedCities = [];
  final ImagePicker _imagePicker = ImagePicker();
  List<XFile> _pickedImages = [];

  bool _saving = false;
  bool _promoting = false;

  @override
  void initState() {
    super.initState();
    _googleInit = GoogleSignIn.instance.initialize();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _authUnlocked = false;
          _authLabel = null;
        });
        return;
      }
      final label = user.displayName ?? user.email ?? 'Signed in';
      setState(() {
        _authUnlocked = true;
        _authLabel = label;
      });
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _descriptionCtrl.dispose();
    _photoUrlsCtrl.dispose();
    _tagsCtrl.dispose();
    _websiteCtrl.dispose();
    _youtubeCtrl.dispose();
    _tiktokCtrl.dispose();
    _instagramCtrl.dispose();
    _facebookCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _countryCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _mapLinkCtrl.dispose();
    _hoursCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _log(String msg) => debugPrint('[AddListing] $msg');

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: TrText(msg)));
  }

  void _showError(Object e, StackTrace st) {
    _log('ERROR: $e');
    _log('$st');
    _snack('$e');
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'Email is already in use.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'user-disabled':
        return 'This account is disabled.';
      case 'operation-not-allowed':
        return 'Email/password auth is disabled for this project.';
      case 'invalid-credential':
        return 'Invalid credentials.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'Sign in failed. Please try again.';
    }
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

    final user = FirebaseAuth.instance.currentUser;

    final uri = Uri.parse('$apiBaseUrl/entities');
    final body = <String, dynamic>{
      "categoryId": category.id,
      "name": _nameCtrl.text.trim(),
      "address": _addressCtrl.text.trim(),
      "contactPhone": _phoneCtrl.text.trim(),
      "remote": false,
    };

    void putIfNotEmpty(String key, String value) {
      final v = value.trim();
      if (v.isNotEmpty) body[key] = v;
    }

    List<String> splitList(String raw) => raw
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    putIfNotEmpty("description", _descriptionCtrl.text);
    putIfNotEmpty("website", _websiteCtrl.text);
    putIfNotEmpty("youtube", _youtubeCtrl.text);
    putIfNotEmpty("tiktok", _tiktokCtrl.text);
    putIfNotEmpty("instagram", _instagramCtrl.text);
    putIfNotEmpty("facebook", _facebookCtrl.text);
    putIfNotEmpty("whatsapp", _whatsappCtrl.text);
    putIfNotEmpty("email", _emailCtrl.text);
    putIfNotEmpty("city", _cityCtrl.text);
    putIfNotEmpty("state", _stateCtrl.text);
    putIfNotEmpty("country", _countryCtrl.text);
    putIfNotEmpty("neighborhood", _neighborhoodCtrl.text);
    putIfNotEmpty("mapLink", _mapLinkCtrl.text);
    putIfNotEmpty("hours", _hoursCtrl.text);
    putIfNotEmpty("priceRange", _priceCtrl.text);

    final tags = splitList(_tagsCtrl.text);
    if (tags.isNotEmpty) body["tags"] = tags;

    final photos = splitList(_photoUrlsCtrl.text);
    if (photos.isNotEmpty) {
      body["images"] = photos;
      body["photo"] = photos.first;
    }
    if (_selectedCities.isNotEmpty) {
      body["cityIds"] = _selectedCities.map((c) => c.id).toList();
      body["cities"] = _selectedCities.map((c) => c.city).toList();

      final regions = _selectedCities
          .map((c) => c.region.trim())
          .where((r) => r.isNotEmpty)
          .toSet()
          .toList();
      if (regions.isNotEmpty) body["regions"] = regions;

      final countries = _selectedCities
          .map((c) => c.country.trim())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();
      if (countries.isNotEmpty) body["countries"] = countries;

      final countryCodes = _selectedCities
          .map((c) => c.countryCode.trim())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();
      if (countryCodes.isNotEmpty) body["countryCodes"] = countryCodes;

      if (_selectedCities.length == 1) {
        final only = _selectedCities.first;
        body["cityId"] = only.id;
        if (only.countryCode.trim().isNotEmpty) {
          body["countryCode"] = only.countryCode;
        }
      }
    }

    if (user != null) {
      body["ownerId"] = user.uid;
      final providerId = user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : "firebase";
      body["ownerProvider"] = providerId;
      if (user.email != null && user.email!.trim().isNotEmpty) {
        body["ownerEmail"] = user.email!.trim();
      }
    }

    _log('CREATE ENTITY: POST $uri');
    _log('CREATE ENTITY BODY: ${jsonEncode(body)}');

    final headers = <String, String>{
      "Content-Type": "application/json",
      "Accept": "application/json",
    };
    if (user != null) {
      try {
        final token = await user.getIdToken();
        headers["Authorization"] = "Bearer $token";
      } catch (e) {
        _log('AUTH TOKEN ERROR: $e');
      }
    }

    final res = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));

    _log('CREATE ENTITY: status=${res.statusCode} body=${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Create entity failed: ${res.statusCode} ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final id = decoded['id'] ?? decoded['entityId'] ?? decoded['SK'];

    if (id == null || (id is String && id.trim().isEmpty)) {
      throw Exception('Create entity returned no id: ${res.body}');
    }

    final entityId = id.toString();
    _log('CREATE ENTITY: id=$entityId');
    return entityId;
  }

  Future<void> _startCheckout({required String entityId}) async {
    final uri = Uri.parse('$paymentsBaseUrl/payments/checkout-session');
    final stripeMode = ref.read(stripeModeProvider);
    final stripeModeValue =
        stripeMode == StripeMode.test ? 'test' : 'live';

    final payload = <String, dynamic>{
      "entityId": entityId,
      "promotionTier": "homeSponsored",
      "stripeMode": stripeModeValue,
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

    if (_skipStripeLaunch) {
      _log('CHECKOUT: skip launch (SKIP_STRIPE_LAUNCH)');
      ref.invalidate(homeSponsoredProvider);
      debugPrint("CHECKOUT URL => $checkoutUrl");
      return;
    }

    final ok = await launchUrl(
      uriToLaunch,
      mode: LaunchMode.externalApplication,
    );

    _log('CHECKOUT: launchUrl ok=$ok');
    ref.invalidate(homeSponsoredProvider);
    debugPrint("CHECKOUT URL => $checkoutUrl");

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
        ref.invalidate(carouselItemsProvider);
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
        ref.invalidate(carouselItemsProvider);
        await _startCheckout(entityId: entityId);
      },
    );
  }

  Future<void> _addFromCamera() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (file == null) return;
      setState(() {
        _pickedImages = [..._pickedImages, file];
      });
    } catch (e) {
      _snack('Camera error: $e');
    }
  }

  Future<void> _addFromGallery() async {
    try {
      final files = await _imagePicker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (files.isEmpty) return;
      setState(() {
        final existing = _pickedImages.map((e) => e.path).toSet();
        for (final f in files) {
          if (!existing.contains(f.path)) _pickedImages.add(f);
        }
      });
    } catch (e) {
      _snack('Gallery error: $e');
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      _pickedImages.removeAt(index);
    });
  }

  Widget _buildPhotoPreview() {
    if (_pickedImages.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < _pickedImages.length; i++)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(_pickedImages[i].path),
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: InkWell(
                  onTap: () => _removeImageAt(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _syncCityFieldsFromSelection() {
    if (_selectedCities.length == 1) {
      final only = _selectedCities.first;
      _cityCtrl.text = only.city;
      _stateCtrl.text = only.region;
      _countryCtrl.text = only.country;
    }
  }

  Future<void> _chooseCities() async {
    String query = '';
    final selectedIds = _selectedCities.map((c) => c.id).toSet();
    final translator = ref.read(translationControllerProvider);

    final result = await showModalBottomSheet<List<HabeshaCity>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final q = query.trim().toLowerCase();
              final filtered = q.isEmpty
                  ? kHabeshaCities
                  : kHabeshaCities
                      .where(
                        (c) => c.label.toLowerCase().contains(q),
                      )
                      .toList();

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: TrText(
                              'Pick cities',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '${selectedIds.length} ${translator.tr('selected')}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () =>
                                setSheetState(() => selectedIds.clear()),
                            child: const TrText('Clear'),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            onPressed: () {
                              final chosen = kHabeshaCities
                                  .where((c) => selectedIds.contains(c.id))
                                  .toList();
                              Navigator.of(ctx).pop(chosen);
                            },
                            child: const TrText('Done'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        decoration: const InputDecoration(
                          label: TrText('Search'),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setSheetState(() => query = v),
                      ),
                    ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final c = filtered[i];
                          final checked = selectedIds.contains(c.id);
                          return ListTile(
                            title: TrText(c.city),
                            subtitle: TrText(
                              c.region.trim().isEmpty
                                  ? c.country
                                  : '${c.region}, ${c.country}',
                            ),
                            onTap: () {
                              setSheetState(() {
                                if (checked) {
                                  selectedIds.remove(c.id);
                                } else {
                                  selectedIds.add(c.id);
                                }
                              });
                            },
                            trailing: checked
                                ? const Icon(Icons.check_circle)
                                : const Icon(Icons.circle_outlined),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (result == null) return;

    setState(() {
      _selectedCities = result;
      _syncCityFieldsFromSelection();
    });
  }

  Future<void> _signInWithGoogle() async {
    if (!mounted) return;
    setState(() => _authWorking = true);
    try {
      await _googleInit;
      final googleUser = await GoogleSignIn.instance.authenticate();
      final auth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      _snack(_authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _authWorking = false);
    }
  }

  Future<void> _signInWithApple() async {
    if (!mounted) return;
    setState(() => _authWorking = true);
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauth = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      await FirebaseAuth.instance.signInWithCredential(oauth);
    } on FirebaseAuthException catch (e) {
      _snack(_authErrorMessage(e));
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      _snack('Apple sign-in failed.');
    } finally {
      if (mounted) setState(() => _authWorking = false);
    }
  }

  Future<void> _signOut() async {
    if (!mounted) return;
    setState(() => _authWorking = true);
    try {
      await FirebaseAuth.instance.signOut();
    } finally {
      if (mounted) setState(() => _authWorking = false);
    }
  }

  Widget _buildAuthGate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TrText(
          'Continue to promote',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        if (_authUnlocked && _authLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      TrText(
                        'Signed in as',
                        style:
                            TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _authLabel!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _authWorking ? null : _signOut,
                  child: const TrText('Sign out'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: _authWorking ? null : _signInWithGoogle,
              icon: const Icon(Icons.login),
              label: const TrText('Continue with Google'),
            ),
            if (Platform.isIOS)
              ElevatedButton.icon(
                onPressed: _authWorking ? null : _signInWithApple,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.apple),
                label: const TrText('Continue with Apple'),
              ),
          ],
        ),
        if (!_authUnlocked)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TrText(
              'Sign in to continue.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _log('BUILD: saving=$_saving promoting=$_promoting');

    final List<AppCategory> categories =
        ref.watch(resolvedCategoriesProvider);
    final AppCategory? selected = ref.watch(selectedCategoryProvider);
    final selectedResolved = selected == null
        ? null
        : categories.firstWhere(
            (c) => c.id == selected.id,
            orElse: () => selected,
          );
    final translator = ref.watch(translationControllerProvider);

    Widget buttonSpinner() => const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        );

    // This prevents a blank dropdown if categories failed to load upstream
    final hasCategories = categories.isNotEmpty;

    Widget sectionTitle(String text) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: TrText(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        );

    final formFields = <Widget>[
      DropdownButtonFormField<AppCategory>(
        key: const Key('add_listing_category'),
        value: hasCategories ? selectedResolved : null,
        decoration: const InputDecoration(
          label: TrText('Category *'),
          border: OutlineInputBorder(),
        ),
        items: categories
            .map(
              (c) => DropdownMenuItem(
                value: c,
                child: TrText('${c.emoji} ${c.title}'),
              ),
            )
            .toList(),
        onChanged: hasCategories
            ? (v) {
                _log('Category changed => ${v?.id}');
                ref.read(selectedCategoryProvider.notifier).state = v;
              }
            : null,
        validator: (v) => v == null ? translator.tr('Required') : null,
      ),
      if (!hasCategories)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: TrText(
            'No categories available. Check categoriesProvider.',
            style: TextStyle(color: Colors.red),
          ),
        ),
      const SizedBox(height: 12),
      sectionTitle('Business Details'),
      TextFormField(
        key: const Key('add_listing_name'),
        controller: _nameCtrl,
        decoration: const InputDecoration(
          label: TrText('Business name *'),
          border: OutlineInputBorder(),
        ),
        validator: (v) =>
            v == null || v.trim().isEmpty ? translator.tr('Required') : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _descriptionCtrl,
        decoration: const InputDecoration(
          label: TrText('Description'),
          border: OutlineInputBorder(),
        ),
        minLines: 3,
        maxLines: 5,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _tagsCtrl,
        decoration: const InputDecoration(
          label: TrText('Tags / keywords'),
          helper: TrText('Comma-separated (e.g., injera, coffee, catering)'),
          border: OutlineInputBorder(),
        ),
        maxLines: 2,
      ),
      const SizedBox(height: 12),
      sectionTitle('Photos'),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _addFromCamera,
            icon: const Icon(Icons.photo_camera),
            label: const TrText('Take photo'),
          ),
          OutlinedButton.icon(
            onPressed: _addFromGallery,
            icon: const Icon(Icons.photo_library),
            label: const TrText('Pick from gallery'),
          ),
          if (_pickedImages.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => setState(() => _pickedImages.clear()),
              icon: const Icon(Icons.delete_outline),
              label: const TrText('Clear photos'),
            ),
        ],
      ),
      const SizedBox(height: 8),
      _buildPhotoPreview(),
      const SizedBox(height: 12),
      TextFormField(
        controller: _photoUrlsCtrl,
        decoration: const InputDecoration(
          label: TrText('Photo URLs'),
          helper: TrText('Paste one or more image links, separated by commas'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.url,
        maxLines: 2,
      ),
      const SizedBox(height: 12),
      sectionTitle('Contact'),
      TextFormField(
        controller: _phoneCtrl,
        decoration: const InputDecoration(
          label: TrText('Phone (optional)'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _emailCtrl,
        decoration: const InputDecoration(
          label: TrText('Email (optional)'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _whatsappCtrl,
        decoration: const InputDecoration(
          label: TrText('WhatsApp (optional)'),
          helper: TrText('Include country code (e.g., +1 202 555 0123)'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 12),
      sectionTitle('Location'),
      TextFormField(
        controller: _addressCtrl,
        decoration: const InputDecoration(
          label: TrText('Address (optional)'),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 20),
      TextFormField(
        controller: _neighborhoodCtrl,
        decoration: const InputDecoration(
          label: TrText('Neighborhood / Area'),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _chooseCities,
        icon: const Icon(Icons.location_city),
        label: const TrText('Pick from 50 cities'),
      ),
      if (_selectedCities.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _selectedCities
                .map(
                  (c) => Chip(
                    label: TrText(c.label),
                    onDeleted: () {
                      setState(() {
                        _selectedCities =
                            _selectedCities.where((e) => e.id != c.id).toList();
                        _syncCityFieldsFromSelection();
                      });
                    },
                  ),
                )
                .toList(),
          ),
        ),
      if (_selectedCities.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: TrText(
            'Multiple cities selected. City/State/Country fields are optional.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _cityCtrl,
        decoration: const InputDecoration(
          label: TrText('City (where it should appear)'),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _stateCtrl,
        decoration: const InputDecoration(
          label: TrText('State / Region'),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _countryCtrl,
        decoration: const InputDecoration(
          label: TrText('Country'),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _mapLinkCtrl,
        decoration: const InputDecoration(
          label: TrText('Google Maps link (optional)'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 12),
      sectionTitle('Online Links'),
      TextFormField(
        controller: _websiteCtrl,
        decoration: const InputDecoration(
          label: TrText('Website (optional)'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _instagramCtrl,
        decoration: const InputDecoration(
          label: TrText('Instagram (optional)'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _facebookCtrl,
        decoration: const InputDecoration(
          label: TrText('Facebook (optional)'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _youtubeCtrl,
        decoration: const InputDecoration(
          label: TrText('YouTube link (optional)'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _tiktokCtrl,
        decoration: const InputDecoration(
          label: TrText('TikTok link (optional)'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 12),
      sectionTitle('Extras'),
      TextFormField(
        controller: _hoursCtrl,
        decoration: const InputDecoration(
          label: TrText('Hours (optional)'),
          helper: TrText('e.g., Mon–Sat 9am–8pm'),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _priceCtrl,
        decoration: const InputDecoration(
          label: TrText('Price range (optional)'),
          helper: TrText(r'e.g., $, $$, $$$'),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: (_saving || _promoting) ? null : _onSave,
        child: _saving ? buttonSpinner() : const TrText('Save'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        key: const Key('add_listing_save_promote'),
        onPressed: (_saving || _promoting) ? null : _onSaveAndPromote,
        child: _promoting ? buttonSpinner() : const TrText('Save & Promote'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const TrText('Add your listing')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildAuthGate(),
              const SizedBox(height: 12),
              AbsorbPointer(
                absorbing: !_authUnlocked,
                child: Opacity(
                  opacity: _authUnlocked ? 1 : 0.4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: formFields,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
