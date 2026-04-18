import 'package:flutter/material.dart';
import 'package:shareco/core/constants/app_colors.dart';

class TextLogo extends StatelessWidget {
  const TextLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(colors: [
          primaryOrange,
          primaryPink,
          primaryBlue,
          primaryPurple,
        ]).createShader(bounds);
      },
      child: const Text(
        "ShareCo",
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      )
    );
  }
}
