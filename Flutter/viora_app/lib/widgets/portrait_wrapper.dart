import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PortraitWrapper extends StatefulWidget {
  final Widget child;

  const PortraitWrapper({
    super.key,
    required this.child,
  });

  @override
  State<PortraitWrapper> createState() => _PortraitWrapperState();
}

class _PortraitWrapperState extends State<PortraitWrapper> {
  @override
  void initState() {
    super.initState();
    _lockPortrait();
  }

  void _lockPortrait() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    _lockPortrait();
    return widget.child;
  }
}
