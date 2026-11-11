import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/theme_helper.dart';

class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;

  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoSwitch(
      value: value,
      activeTrackColor: activeColor ?? AppColors.blue,
      inactiveTrackColor: context.isDark ? const Color(0xFF39393D) : const Color(0xFFE5E5EA),
      thumbColor: Colors.white,
      onChanged: onChanged,
    );
  }
}
