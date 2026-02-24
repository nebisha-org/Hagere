import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cache/entities_cache.dart';
import '../state/override_providers.dart';
import '../state/providers.dart';
import '../state/qc_mode.dart';
import '../state/sponsored_providers.dart';
import '../state/translation_provider.dart';
import 'tr_text.dart';

const String kHabeshaUsageStarsFieldKey = 'habesha_usage_stars';

int _clampStars(int value) => value.clamp(0, 5).toInt();

int _parseStarsValue(dynamic value) {
  if (value is num) return _clampStars(value.round());
  final parsed = int.tryParse((value ?? '').toString().trim());
  if (parsed != null) return _clampStars(parsed);
  return 0;
}

int habeshaUsageStarsFromEntity(Map<String, dynamic> raw) {
  final candidates = [
    raw[kHabeshaUsageStarsFieldKey],
    raw['habeshaUsageStars'],
    raw['community_usage_stars'],
    raw['communityUsageStars'],
    raw['habesha_usage_score'],
  ];
  for (final value in candidates) {
    final stars = _parseStarsValue(value);
    if (stars > 0) return stars;
  }
  return 0;
}

class QcStarRating extends ConsumerStatefulWidget {
  const QcStarRating({
    super.key,
    required this.entityId,
    required this.raw,
    this.showLabel = true,
    this.iconSize = 16,
  });

  final String entityId;
  final Map<String, dynamic> raw;
  final bool showLabel;
  final double iconSize;

  @override
  ConsumerState<QcStarRating> createState() => _QcStarRatingState();
}

class _QcStarRatingState extends ConsumerState<QcStarRating> {
  late int _stars;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _stars = habeshaUsageStarsFromEntity(widget.raw);
  }

  @override
  void didUpdateWidget(covariant QcStarRating oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.raw != widget.raw) {
      _stars = habeshaUsageStarsFromEntity(widget.raw);
    }
  }

  Future<void> _setStars(int next) async {
    final qc = ref.read(qcEditStateProvider);
    if (!kQcMode ||
        !qc.visible ||
        !qc.editing ||
        widget.entityId.trim().isEmpty) {
      return;
    }
    final normalized = _clampStars(next);
    if (_saving || normalized == _stars) return;

    setState(() => _saving = true);
    try {
      final api = ref.read(overridesApiProvider);
      final locale = ref.read(translationControllerProvider).language.code;
      final prefs = await SharedPreferences.getInstance();
      final updatedBy = (prefs.getString('qc_editor_name') ?? '').trim();

      await api.upsertOverride(
        entityType: 'entity',
        entityId: widget.entityId,
        fieldKey: kHabeshaUsageStarsFieldKey,
        locale: locale,
        value: normalized.toString(),
        updatedBy: updatedBy,
      );

      await EntitiesCache.applyOverrideToAll(
        entityId: widget.entityId,
        fieldKey: kHabeshaUsageStarsFieldKey,
        value: normalized.toString(),
        locale: locale,
      );

      widget.raw[kHabeshaUsageStarsFieldKey] = normalized.toString();
      if (mounted) {
        setState(() {
          _stars = normalized;
          _saving = false;
        });
      }
      ref.invalidate(entitiesRawProvider);
      ref.invalidate(homeSponsoredProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TrText('Failed to save stars')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final qc = ref.watch(qcEditStateProvider);
    final canEdit = kQcMode &&
        qc.visible &&
        qc.editing &&
        widget.entityId.trim().isNotEmpty;
    if (!canEdit && _stars <= 0) return const SizedBox.shrink();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        if (widget.showLabel)
          const TrText(
            'Habesha usage',
            translate: false,
          ),
        ...List.generate(5, (index) {
          final filled = index < _stars;
          return GestureDetector(
            onTap: canEdit ? () => _setStars(index + 1) : null,
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_border_rounded,
              color: filled ? const Color(0xFFFFB300) : Colors.grey.shade500,
              size: widget.iconSize,
            ),
          );
        }),
        if (canEdit)
          InkWell(
            onTap: _saving ? null : () => _setStars(0),
            child: Text(
              'Clear',
              style: TextStyle(
                fontSize: 12,
                color: _saving
                    ? Colors.grey
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        if (_saving)
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}
