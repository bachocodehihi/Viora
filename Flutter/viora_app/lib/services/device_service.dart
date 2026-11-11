import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const String _keyDeviceUuid = 'viora_device_uuid';

  static Future<String> getDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString(_keyDeviceUuid);
      if (deviceId != null && deviceId.isNotEmpty) {
        return deviceId;
      }

      if (kIsWeb) {
        deviceId = 'web_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
      } else if (Platform.isAndroid) {
        final android = await _deviceInfo.androidInfo;
        deviceId = android.id;
      } else if (Platform.isIOS) {
        final ios = await _deviceInfo.iosInfo;
        deviceId = ios.identifierForVendor;
      } else if (Platform.isWindows) {
        final win = await _deviceInfo.windowsInfo;
        deviceId = win.deviceId;
      }

      if (deviceId == null || deviceId.isEmpty) {
        deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
      }

      await prefs.setString(_keyDeviceUuid, deviceId);
      return deviceId;
    } catch (e) {
      debugPrint('[DeviceService] Error getting deviceId: $e');
      return 'dev_unknown';
    }
  }

  static Future<String> getDeviceName() async {
    try {
      if (kIsWeb) {
        return 'Web Browser';
      } else if (Platform.isAndroid) {
        final android = await _deviceInfo.androidInfo;
        final manufacturer = android.manufacturer;
        final model = android.model;

        if (model.toLowerCase().contains(manufacturer.toLowerCase())) {
          return model;
        }
        return '$manufacturer $model';
      } else if (Platform.isIOS) {
        final ios = await _deviceInfo.iosInfo;
        return ios.name;
      } else if (Platform.isWindows) {
        final win = await _deviceInfo.windowsInfo;
        return win.computerName;
      } else if (Platform.isMacOS) {
        final mac = await _deviceInfo.macOsInfo;
        return mac.computerName;
      } else if (Platform.isLinux) {
        final linux = await _deviceInfo.linuxInfo;
        return linux.name;
      }
    } catch (e) {
      debugPrint('[DeviceService] Error getting deviceName: $e');
    }
    return 'Mobile device';
  }
}
