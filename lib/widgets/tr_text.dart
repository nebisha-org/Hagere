import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/translation_provider.dart';

class TrText extends ConsumerWidget {
  const TrText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.textDirection,
    this.textHeightBehavior,
    this.textWidthBasis,
    this.selectionColor,
    this.translate = true,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextDirection? textDirection;
  final TextHeightBehavior? textHeightBehavior;
  final TextWidthBasis? textWidthBasis;
  final Color? selectionColor;
  final bool translate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(translationControllerProvider);
    final text = translate ? controller.tr(data) : data;
    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      textDirection: textDirection,
      textHeightBehavior: textHeightBehavior,
      textWidthBasis: textWidthBasis,
      selectionColor: selectionColor,
    );
  }
}
