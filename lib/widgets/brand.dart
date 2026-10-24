import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme.dart';

/// Das App-Icon-Logo als Vektor.
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/logo/karaoke_party_icon.svg',
        width: size,
        height: size,
      );
}

/// Text mit Marken-Verlauf (Violett→Pink).
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  const GradientText(this.text, {super.key, this.style, this.textAlign});

  @override
  Widget build(BuildContext context) => ShaderMask(
        shaderCallback: (bounds) => AppColors.brandGradient.createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: Text(text, style: style, textAlign: textAlign),
      );
}
