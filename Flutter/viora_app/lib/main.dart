import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'config/app_routes.dart';
import 'config/app_theme.dart';
import 'l10n/language.dart';
import 'providers/theme_provider.dart';
import 'providers/signup_provider.dart';
import 'services/notification_service.dart';
import 'services/call_service.dart';
import 'services/activity_tracker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MapLibreMap.useHybridComposition = true;
  unawaited(MapLibreMap.preWarm());
  unawaited(NotificationService.initialize());
  unawaited(CallService.initialize());
  unawaited(ActivityTrackerService.instance.initialize());

  await LanguageManager.init();

  ThemeMode initialThemeMode = ThemeMode.dark;
  try {
    final prefs = await SharedPreferences.getInstance();
    final isDarkVal = prefs.getInt('theme_mode');
    if (isDarkVal != null) {
      initialThemeMode = isDarkVal == 1 ? ThemeMode.dark : ThemeMode.light;
    }
  } catch (e) {
    debugPrint('Error loading initial theme: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(initialMode: initialThemeMode)),
        ChangeNotifierProvider(create: (_) => SignUpProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return ValueListenableBuilder<Locale>(
          valueListenable: LanguageManager.localeNotifier,
          builder: (context, locale, _) {
            final themeProvider = Provider.of<ThemeProvider>(context);
            return MaterialApp(
              navigatorKey: NotificationService.navigatorKey,
              title: 'Viora',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              locale: locale,
              supportedLocales: const [
                Locale('en'),
                Locale('vi'),
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) {
                return DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontFamilyFallback: ['Inter', 'Roboto', 'sans-serif'],
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },
              initialRoute: AppRoutes.splash,
              onGenerateRoute: AppRoutes.generateRoute,
            );
          },
        );
      },
    );
  }
}
