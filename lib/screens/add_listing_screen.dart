import '../config/env.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crypto/crypto.dart';

import '../data/habesha_cities.dart';
import '../models/category.dart';
import '../state/category_providers.dart';
import '../state/override_providers.dart';
import '../state/providers.dart';
import '../state/sponsored_providers.dart';
import '../state/payment_type_provider.dart';
import '../state/stripe_mode_provider.dart';
import '../state/translation_provider.dart';
import '../widgets/tr_text.dart';

enum AddListingOrigin {
  carousel,
  categoryList,
}

class _UploadedListingImage {
  const _UploadedListingImage({
    required this.key,
    required this.url,
    required this.contentType,
  });

  final String key;
  final String url;
  final String contentType;
}

class AddListingScreen extends ConsumerStatefulWidget {
  const AddListingScreen({
    super.key,
    this.origin = AddListingOrigin.carousel,
  });
  static const routeName = '/add-listing';

  final AddListingOrigin origin;

  @override
  ConsumerState<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends ConsumerState<AddListingScreen> {
  static const bool _skipStripeLaunch =
      bool.fromEnvironment('SKIP_STRIPE_LAUNCH', defaultValue: false);
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phone1Ctrl = TextEditingController();
  final _phone2Ctrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();

  bool _authUnlocked = false;
  bool _authWorking = false;
  String? _authLabel;
  bool _guestMode = false;
  StreamSubscription<User?>? _authSub;
  static Future<void>? _googleInitShared;
  Future<void>? _googleInit;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final _instagramCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _twitterCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  List<HabeshaCity> _selectedCities = [];
  final ImagePicker _imagePicker = ImagePicker();
  List<XFile> _pickedImages = [];

  bool _saving = false;
  bool _promoting = false;
  bool _phone1HasWhatsApp = false;
  bool _phone1HasTelegram = false;
  bool _phone2HasWhatsApp = false;
  bool _phone2HasTelegram = false;

  @override
  void initState() {
    super.initState();
    _googleInitShared ??= GoogleSignIn.instance.initialize();
    _googleInit = _googleInitShared;
    _guestMode = false;
    _authUnlocked = false;
    _authLabel = null;
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _authUnlocked = _guestMode;
          _authLabel = _guestMode ? 'Guest' : null;
        });
        _analytics.setUserId(id: null);
        return;
      }
      final label = user.displayName ?? user.email ?? 'Signed in';
      setState(() {
        _guestMode = false;
        _authUnlocked = true;
        _authLabel = label;
      });
      _analytics.setUserId(id: user.uid);
      final providerId = user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'firebase';
      _analytics.setUserProperty(name: 'auth_provider', value: providerId);
    });
    _analytics.logEvent(name: 'add_listing_open');
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _nameCtrl.dispose();
    _phone1Ctrl.dispose();
    _phone2Ctrl.dispose();
    _addressCtrl.dispose();
    _descriptionCtrl.dispose();
    _tagsCtrl.dispose();
    _websiteCtrl.dispose();
    _youtubeCtrl.dispose();
    _tiktokCtrl.dispose();
    _instagramCtrl.dispose();
    _facebookCtrl.dispose();
    _twitterCtrl.dispose();
    _emailCtrl.dispose();
    _countryCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _neighborhoodCtrl.dispose();
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
        return e.message ?? 'Sign in failed (${e.code}).';
    }
  }

  String _googleErrorMessage(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Google sign-in canceled.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google sign-in was interrupted. Try again.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Google sign-in is not configured correctly for this app.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google provider configuration is invalid.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google sign-in UI is unavailable right now.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'Google account mismatch. Please try again.';
      case GoogleSignInExceptionCode.unknownError:
        return e.description ?? 'Google sign-in failed.';
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(length, (_) => charset[rand.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
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

  void _refreshEntitiesList() {
    ref.read(entitiesRefreshProvider.notifier).state++;
    ref.invalidate(entitiesRawProvider);
  }

  String _contentTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    if (normalized.isEmpty) return 'upload.jpg';
    final parts = normalized.split('/');
    final name = parts.isNotEmpty ? parts.last.trim() : '';
    if (name.isEmpty) return 'upload.jpg';
    return name;
  }

  Future<_UploadedListingImage> _uploadSingleImage(XFile file) async {
    final contentType = _contentTypeForPath(file.path);
    final fileName = _fileNameFromPath(file.path);
    final presignUri = Uri.parse('$entitiesBaseUrl/uploads/presign');
    _log('UPLOAD PRESIGN: POST $presignUri ($fileName $contentType)');

    final presignRes = await http
        .post(
          presignUri,
          headers: const {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
          body: jsonEncode({
            "fileName": fileName,
            "contentType": contentType,
          }),
        )
        .timeout(const Duration(seconds: 25));

    _log(
        'UPLOAD PRESIGN: status=${presignRes.statusCode} body=${presignRes.body}');
    if (presignRes.statusCode < 200 || presignRes.statusCode >= 300) {
      throw Exception(
          'Image upload init failed: ${presignRes.statusCode} ${presignRes.body}');
    }

    final presignJson = jsonDecode(presignRes.body);
    final uploadUrl = (presignJson['uploadUrl'] ?? '').toString().trim();
    final fileKey = (presignJson['fileKey'] ?? '').toString().trim();
    final publicUrl = (presignJson['publicUrl'] ?? '').toString().trim();
    if (uploadUrl.isEmpty || fileKey.isEmpty || publicUrl.isEmpty) {
      throw Exception('Image upload init returned invalid payload');
    }

    final bytes = await file.readAsBytes();
    final uploadUri = Uri.parse(uploadUrl);
    final uploadRes = await http
        .put(
          uploadUri,
          headers: {
            "Content-Type": contentType,
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 45));

    _log('UPLOAD PUT: status=${uploadRes.statusCode} key=$fileKey');
    if (uploadRes.statusCode < 200 || uploadRes.statusCode >= 300) {
      throw Exception(
          'Image upload failed: ${uploadRes.statusCode} ${uploadRes.body}');
    }

    return _UploadedListingImage(
      key: fileKey,
      url: publicUrl,
      contentType: contentType,
    );
  }

  Future<List<_UploadedListingImage>> _uploadPickedImages() async {
    if (_pickedImages.isEmpty) return const [];

    _log('UPLOAD IMAGES: count=${_pickedImages.length}');
    final uploaded = <_UploadedListingImage>[];
    for (final file in _pickedImages) {
      uploaded.add(await _uploadSingleImage(file));
    }
    _log('UPLOAD IMAGES: done=${uploaded.length}');
    return uploaded;
  }

  Future<String> _createEntity({
    List<_UploadedListingImage> uploadedImages = const [],
  }) async {
    final category = ref.read(selectedCategoryProvider);
    if (category == null) {
      throw Exception('Category required');
    }

    final user = FirebaseAuth.instance.currentUser;

    final uri = Uri.parse('$entitiesBaseUrl/entities');
    final body = <String, dynamic>{
      "categoryId": category.id,
      "name": _nameCtrl.text.trim(),
      "address": _addressCtrl.text.trim(),
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

    putIfNotEmpty("contactPhone", _phone1Ctrl.text);
    putIfNotEmpty("contactPhone2", _phone2Ctrl.text);
    if (_phone1HasWhatsApp) body["contactPhoneHasWhatsApp"] = true;
    if (_phone1HasTelegram) body["contactPhoneHasTelegram"] = true;
    if (_phone2HasWhatsApp) body["contactPhone2HasWhatsApp"] = true;
    if (_phone2HasTelegram) body["contactPhone2HasTelegram"] = true;

    putIfNotEmpty("description", _descriptionCtrl.text);
    putIfNotEmpty("website", _websiteCtrl.text);
    putIfNotEmpty("youtube", _youtubeCtrl.text);
    putIfNotEmpty("tiktok", _tiktokCtrl.text);
    putIfNotEmpty("instagram", _instagramCtrl.text);
    putIfNotEmpty("facebook", _facebookCtrl.text);
    putIfNotEmpty("twitter", _twitterCtrl.text);
    putIfNotEmpty("email", _emailCtrl.text);
    // City/State/Country are filled from the city picker. Don't accept manual typing.
    if (_selectedCities.isEmpty) {
      putIfNotEmpty("city", _cityCtrl.text);
      putIfNotEmpty("state", _stateCtrl.text);
      putIfNotEmpty("country", _countryCtrl.text);
    }
    putIfNotEmpty("neighborhood", _neighborhoodCtrl.text);
    putIfNotEmpty("hours", _hoursCtrl.text);
    putIfNotEmpty("priceRange", _priceCtrl.text);

    final tags = splitList(_tagsCtrl.text);
    if (tags.isNotEmpty) body["tags"] = tags;
    if (uploadedImages.isNotEmpty) {
      final urls = uploadedImages.map((e) => e.url).toList();
      final keys = uploadedImages.map((e) => e.key).toList();
      final contentTypes = uploadedImages.map((e) => e.contentType).toList();
      body["images"] = urls;
      body["imageKeys"] = keys;
      body["imageContentTypes"] = contentTypes;
      body["photo"] = urls.first;
      body["image"] = urls.first;
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
        body["city"] = only.city;
        if (only.region.trim().isNotEmpty) body["state"] = only.region.trim();
        if (only.country.trim().isNotEmpty) {
          body["country"] = only.country.trim();
        }
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
    final paymentType = ref.read(paymentTypeProvider);
    final checkoutBaseUrl = paymentType == PaymentType.subscription
        ? subscriptionPaymentsBaseUrl
        : paymentsBaseUrl;
    final checkoutPath = paymentType == PaymentType.subscription
        ? '/payments/subscription-checkout-session'
        : '/payments/checkout-session';
    final uri = Uri.parse('$checkoutBaseUrl$checkoutPath');
    final stripeMode = ref.read(stripeModeProvider);
    final stripeModeValue = stripeMode == StripeMode.test ? 'test' : 'live';
    final promotionTier = widget.origin == AddListingOrigin.categoryList
        ? 'categoryFeatured'
        : 'homeSponsored';
    final categoryId = widget.origin == AddListingOrigin.categoryList
        ? (ref.read(selectedCategoryProvider)?.id ?? '').trim()
        : '';

    final payload = <String, dynamic>{
      "entityId": entityId,
      "promotionTier": promotionTier,
      if (categoryId.isNotEmpty) "categoryId": categoryId,
      "stripeMode": stripeModeValue,
      if (paymentType == PaymentType.subscription) "intervalDays": 7,
    };

    _log('CHECKOUT: POST $uri');
    _log('CHECKOUT MODE: ${paymentType.name}');
    _log('CHECKOUT BASE URL: $checkoutBaseUrl');
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
      ref.invalidate(carouselItemsProvider);
      _refreshEntitiesList();
      debugPrint("CHECKOUT URL => $checkoutUrl");
      return;
    }

    final ok = await launchUrl(
      uriToLaunch,
      mode: LaunchMode.externalApplication,
    );

    _log('CHECKOUT: launchUrl ok=$ok');
    ref.invalidate(homeSponsoredProvider);
    ref.invalidate(carouselItemsProvider);
    _refreshEntitiesList();
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
        final uploadedImages = await _uploadPickedImages();
        await _createEntity(uploadedImages: uploadedImages);
        await _analytics.logEvent(
          name: 'listing_save',
          // Firebase Analytics only accepts String/num values.
          parameters: {'promote': 0},
        );
        ref.invalidate(carouselItemsProvider);
        _refreshEntitiesList();
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
        final uploadedImages = await _uploadPickedImages();
        final entityId = await _createEntity(uploadedImages: uploadedImages);
        await _analytics.logEvent(
          name: 'listing_save',
          // Firebase Analytics only accepts String/num values.
          parameters: {'promote': 1},
        );
        ref.invalidate(carouselItemsProvider);
        _refreshEntitiesList();
        await _analytics.logEvent(name: 'promotion_checkout_start');
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
    if (_selectedCities.isEmpty) {
      _cityCtrl.text = '';
      _stateCtrl.text = '';
      _countryCtrl.text = '';
      return;
    }

    if (_selectedCities.length == 1) {
      final only = _selectedCities.first;
      _cityCtrl.text = only.city;
      _stateCtrl.text = only.region;
      _countryCtrl.text = only.country;
      return;
    }

    // Multiple selection: show a display-only summary, but we avoid sending these
    // fields to the backend (we rely on cityIds/cities/etc).
    _cityCtrl.text = '${_selectedCities.length} cities selected';
    _stateCtrl.text = '';
    _countryCtrl.text = '';
  }

  Future<void> _chooseCities() async {
    String query = '';
    final selectedIds = _selectedCities.map((c) => c.id).toSet();
    final translator = ref.read(translationControllerProvider);
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.88;

    final result = await showModalBottomSheet<List<HabeshaCity>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final allIds = kHabeshaCities.map((c) => c.id).toSet();

            bool? triStateFor(Set<String> ids) {
              if (ids.isEmpty) return false;
              final selectedCount = ids.where(selectedIds.contains).length;
              if (selectedCount == 0) return false;
              if (selectedCount == ids.length) return true;
              return null; // partial
            }

            void toggleGroup(Set<String> ids) {
              final allSelected =
                  ids.isNotEmpty && ids.every(selectedIds.contains);
              setSheetState(() {
                if (allSelected) {
                  selectedIds.removeAll(ids);
                } else {
                  selectedIds.addAll(ids);
                }
              });
            }

            void toggleCity(String id) {
              setSheetState(() {
                if (selectedIds.contains(id)) {
                  selectedIds.remove(id);
                } else {
                  selectedIds.add(id);
                }
              });
            }

            final q = query.trim().toLowerCase();
            bool matches(HabeshaCity c) {
              if (q.isEmpty) return true;
              final hay = [
                c.city,
                c.region,
                c.country,
                c.countryCode,
                c.continent,
              ].join(' ').toLowerCase();
              return hay.contains(q);
            }

            // Visible grouping: continent -> countryCode -> cities
            final Map<String, Map<String, List<HabeshaCity>>> grouped = {};
            for (final city in kHabeshaCities) {
              if (!matches(city)) continue;
              final cont = city.continent;
              final countryCode = city.countryCode.toUpperCase();
              final byCountry = grouped.putIfAbsent(cont, () => {});
              byCountry.putIfAbsent(countryCode, () => []).add(city);
            }

            const continentOrder = [
              'North America',
              'Europe',
              'Asia',
              'Africa',
              'Other',
            ];
            final continents = grouped.keys.toList()
              ..sort((a, b) {
                final ai = continentOrder.indexOf(a);
                final bi = continentOrder.indexOf(b);
                if (ai == -1 && bi == -1) return a.compareTo(b);
                if (ai == -1) return 1;
                if (bi == -1) return -1;
                return ai.compareTo(bi);
              });

            // Keep the visible lists stable/predictable.
            for (final byCountry in grouped.values) {
              for (final cities in byCountry.values) {
                cities.sort(
                  (a, b) => a.city.toLowerCase().compareTo(
                        b.city.toLowerCase(),
                      ),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
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
                  CheckboxListTile(
                    value: triStateFor(allIds),
                    tristate: true,
                    onChanged: (_) => toggleGroup(allIds),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    title: const TrText('All'),
                    subtitle: TrText(
                      '${allIds.length} cities',
                      translate: false,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        for (final cont in continents)
                          ExpansionTile(
                            leading: Checkbox(
                              tristate: true,
                              value: triStateFor(
                                kHabeshaCities
                                    .where((c) => c.continent == cont)
                                    .map((c) => c.id)
                                    .toSet(),
                              ),
                              onChanged: (_) {
                                final ids = kHabeshaCities
                                    .where((c) => c.continent == cont)
                                    .map((c) => c.id)
                                    .toSet();
                                toggleGroup(ids);
                              },
                            ),
                            title: Text(cont),
                            children: [
                              for (final countryEntry
                                  in (grouped[cont] ?? {}).entries.toList()
                                    ..sort((a, b) {
                                      final an = a.value.isEmpty
                                          ? a.key
                                          : a.value.first.country;
                                      final bn = b.value.isEmpty
                                          ? b.key
                                          : b.value.first.country;
                                      return an.compareTo(bn);
                                    }))
                                ExpansionTile(
                                  leading: Checkbox(
                                    tristate: true,
                                    value: triStateFor(
                                      kHabeshaCities
                                          .where((c) =>
                                              c.countryCode.toUpperCase() ==
                                              countryEntry.key)
                                          .map((c) => c.id)
                                          .toSet(),
                                    ),
                                    onChanged: (_) {
                                      final ids = kHabeshaCities
                                          .where((c) =>
                                              c.countryCode.toUpperCase() ==
                                              countryEntry.key)
                                          .map((c) => c.id)
                                          .toSet();
                                      toggleGroup(ids);
                                    },
                                  ),
                                  title: Text(
                                    countryEntry.value.isEmpty
                                        ? countryEntry.key
                                        : '${countryEntry.value.first.country} (${countryEntry.key})',
                                  ),
                                  children: [
                                    for (final c in countryEntry.value)
                                      CheckboxListTile(
                                        value: selectedIds.contains(c.id),
                                        onChanged: (_) => toggleCity(c.id),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        dense: true,
                                        title: Text(c.city),
                                        subtitle: c.region.trim().isEmpty
                                            ? null
                                            : Text(c.region),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        _snack('Google sign-in is not supported on this device.');
        return;
      }
      await _analytics.logEvent(
        name: 'login_start',
        parameters: {'provider': 'google'},
      );
      await _googleInit;
      final googleUser = await GoogleSignIn.instance.authenticate();
      final auth = googleUser.authentication;
      if (auth.idToken == null || auth.idToken!.trim().isEmpty) {
        throw Exception(
          'Google sign-in did not return an ID token. Check iOS Google Sign-In configuration.',
        );
      }
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      await _analytics.logEvent(
        name: 'login_success',
        parameters: {'provider': 'google'},
      );
    } on GoogleSignInException catch (e) {
      await _analytics.logEvent(
        name: 'login_failure',
        parameters: {'provider': 'google', 'code': e.code.name},
      );
      _snack(_googleErrorMessage(e));
    } on FirebaseAuthException catch (e) {
      await _analytics.logEvent(
        name: 'login_failure',
        parameters: {'provider': 'google', 'code': e.code},
      );
      _snack(_authErrorMessage(e));
    } catch (e) {
      await _analytics.logEvent(
        name: 'login_failure',
        parameters: {'provider': 'google', 'code': 'unknown'},
      );
      _snack('Google sign-in failed. $e');
    } finally {
      if (mounted) setState(() => _authWorking = false);
    }
  }

  Future<void> _signInWithApple() async {
    if (!mounted) return;
    setState(() => _authWorking = true);
    try {
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        _snack('Apple sign-in is unavailable on this device.');
        return;
      }
      await _analytics.logEvent(
        name: 'login_start',
        parameters: {'provider': 'apple'},
      );
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      final identityToken = appleCredential.identityToken;
      if (identityToken == null || identityToken.trim().isEmpty) {
        throw Exception(
          'Apple sign-in did not return identity token. Sign into iCloud on the simulator/device and try again.',
        );
      }
      final oauth = OAuthProvider("apple.com").credential(
        idToken: identityToken,
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
      );
      await FirebaseAuth.instance.signInWithCredential(oauth);
      await _analytics.logEvent(
        name: 'login_success',
        parameters: {'provider': 'apple'},
      );
    } on FirebaseAuthException catch (e) {
      await _analytics.logEvent(
        name: 'login_failure',
        parameters: {'provider': 'apple', 'code': e.code},
      );
      _snack(_authErrorMessage(e));
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      await _analytics.logEvent(
        name: 'login_failure',
        parameters: {'provider': 'apple', 'code': e.code.name},
      );
      _snack('Apple sign-in failed: ${e.code.name}.');
    } catch (e) {
      await _analytics.logEvent(
        name: 'login_failure',
        parameters: {'provider': 'apple', 'code': 'unknown'},
      );
      _snack('Apple sign-in failed. $e');
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

  void _continueAsGuest() {
    if (!mounted) return;
    setState(() {
      _guestMode = true;
      _authUnlocked = true;
      _authLabel = 'Guest';
    });
    _analytics.logEvent(name: 'login_guest');
  }

  Widget _buildAuthGate() {
    final user = FirebaseAuth.instance.currentUser;
    final providerId = user?.providerData.isNotEmpty == true
        ? user!.providerData.first.providerId
        : null;
    final googleSelected =
        _authUnlocked && !_guestMode && providerId == 'google.com';
    final appleSelected =
        _authUnlocked && !_guestMode && providerId == 'apple.com';
    final guestSelected = _authUnlocked && _guestMode;

    Widget googleBadge() => Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE3E6EB)),
          ),
          alignment: Alignment.center,
          child: const Text(
            'G',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4285F4),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TrText(
          'Continue to promote',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        TrText(
          _authUnlocked
              ? 'You can now edit and submit your listing.'
              : 'Choose a login option to unlock the form.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (_authWorking)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        Row(
          children: [
            Expanded(
              child: _AuthChoiceButton(
                label: 'Google',
                leading: googleBadge(),
                onTap: _authWorking ? null : _signInWithGoogle,
                selected: googleSelected,
                accent: const Color(0xFF4285F4),
              ),
            ),
            if (Platform.isIOS) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _AuthChoiceButton(
                  label: 'Apple',
                  leading: const Icon(
                    Icons.apple,
                    size: 20,
                    color: Color(0xFF1F1F1F),
                  ),
                  onTap: _authWorking ? null : _signInWithApple,
                  selected: appleSelected,
                  accent: const Color(0xFF1F1F1F),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: _AuthChoiceButton(
                label: 'Guest',
                leading: const Icon(
                  Icons.person_outline_rounded,
                  size: 19,
                  color: Color(0xFF00695C),
                ),
                onTap: _authWorking ? null : _continueAsGuest,
                selected: guestSelected,
                accent: const Color(0xFF009688),
              ),
            ),
          ],
        ),
        if (_authUnlocked && _authLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB7E2BC)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_rounded,
                    size: 16,
                    color: Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _guestMode
                          ? 'Guest mode active'
                          : 'Signed in as $_authLabel',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1B5E20),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (!_guestMode)
                    TextButton(
                      onPressed: _authWorking ? null : _signOut,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 0),
                        minimumSize: const Size(0, 28),
                      ),
                      child: const TrText('Sign out'),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _log('BUILD: saving=$_saving promoting=$_promoting');

    final List<AppCategory> categories = ref.watch(resolvedCategoriesProvider);
    final AppCategory? selected = ref.watch(selectedCategoryProvider);
    final paymentType = ref.watch(paymentTypeProvider);
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
      sectionTitle('Contact'),
      TextFormField(
        controller: _phone1Ctrl,
        decoration: const InputDecoration(
          label: TrText('Phone 1 (optional)'),
          helper: TrText('Include country code (e.g., +1 202 555 0123)'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 12,
        runSpacing: 0,
        children: [
          _CompactCheck(
            value: _phone1HasWhatsApp,
            onChanged: (v) => setState(() => _phone1HasWhatsApp = v),
            label: 'WhatsApp',
          ),
          _CompactCheck(
            value: _phone1HasTelegram,
            onChanged: (v) => setState(() => _phone1HasTelegram = v),
            label: 'Telegram',
          ),
        ],
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _phone2Ctrl,
        decoration: const InputDecoration(
          label: TrText('Phone 2 (optional)'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 12,
        runSpacing: 0,
        children: [
          _CompactCheck(
            value: _phone2HasWhatsApp,
            onChanged: (v) => setState(() => _phone2HasWhatsApp = v),
            label: 'WhatsApp',
          ),
          _CompactCheck(
            value: _phone2HasTelegram,
            onChanged: (v) => setState(() => _phone2HasTelegram = v),
            label: 'Telegram',
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: _emailCtrl,
        decoration: const InputDecoration(
          label: TrText('Email (optional)'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.emailAddress,
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
          label: TrText('Neighborhood / Area (optional)'),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _chooseCities,
        icon: const Icon(Icons.location_city),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedCities.isEmpty
                  ? translator.tr('Pick from 50 cities')
                  : (() {
                      final names = _selectedCities.map((c) => c.city).toList();
                      if (names.length <= 2) return names.join(', ');
                      return '${names.take(2).join(', ')} +${names.length - 2}';
                    })(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              _selectedCities.isEmpty
                  ? translator.tr('Select one or more (multi-select)')
                  : translator.tr('Add more'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      sectionTitle('Online Links'),
      TextFormField(
        controller: _websiteCtrl,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.public),
          label: TrText('Website (optional)'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _instagramCtrl,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.camera_alt_outlined),
          label: TrText('Instagram (optional)'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _facebookCtrl,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.facebook),
          label: TrText('Facebook (optional)'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _youtubeCtrl,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.ondemand_video_outlined),
          label: TrText('YouTube link (optional)'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _tiktokCtrl,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.music_note_outlined),
          label: TrText('TikTok link (optional)'),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _twitterCtrl,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.alternate_email),
          label: TrText('Twitter (optional)'),
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
      if (widget.origin == AddListingOrigin.categoryList &&
          paymentType == PaymentType.subscription)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFB7E2BC)),
          ),
          child: const TrText(
            r'Category promotion subscription: $1.99 per 7 days.',
            translate: false,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B5E20),
            ),
          ),
        ),
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

class _CompactCheck extends StatelessWidget {
  const _CompactCheck({
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          TrText(label),
        ],
      ),
    );
  }
}

class _AuthChoiceButton extends StatelessWidget {
  const _AuthChoiceButton({
    required this.label,
    required this.leading,
    required this.onTap,
    required this.selected,
    required this.accent,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onTap;
  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: selected ? accent.withValues(alpha: 0.14) : Colors.white,
            border: Border.all(
              color: selected ? accent : const Color(0xFFD9DEE6),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? accent : const Color(0xFF263238),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
