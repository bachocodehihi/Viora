import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/theme_helper.dart';
import 'package:flutter/services.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../l10n/language.dart';
import '../../services/device_service.dart';
import '../../services/notification_service.dart';
import '../../services/session_service.dart';
import '../../widgets/toast/app_toast.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final bool isForgotPassword;
  final bool isDeleteAccount;
  final bool isTwoFactorLogin;
  final String? twoFactorToken;
  final String? deviceName;
  final String? deviceId;
  final bool returnResultOnVerify;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.isForgotPassword = false,
    this.isDeleteAccount = false,
    this.isTwoFactorLogin = false,
    this.twoFactorToken,
    this.deviceName,
    this.deviceId,
    this.returnResultOnVerify = false,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> with TickerProviderStateMixin {
  late List<FocusNode> _focusNodes;
  late List<TextEditingController> _controllers;
  Timer? _timer;
  int _secondsRemaining = 60;
  bool? _isCodeValid;
  bool _isLoading = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (index) => TextEditingController());
    _focusNodes = List.generate(6, (index) {
      final node = FocusNode(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {

            if (_controllers[index].text.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
              _controllers[index - 1].clear();
              setState(() {});
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
      );
      node.addListener(() {
        if (mounted) setState(() {});
      });
      return node;
    });
    _startTimer();
  }

  void _fillOtp(String rawDigits, {int startIndex = 0}) {
    final match = RegExp(r'\b\d{6}\b').firstMatch(rawDigits);
    final digits = match != null ? match.group(0)! : rawDigits.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    int start = (digits.length >= 6) ? 0 : startIndex;
    if (start + digits.length > 6) {
      start = (6 - digits.length).clamp(0, 5);
    }

    for (int i = 0; i < digits.length && (start + i) < 6; i++) {
      _controllers[start + i].text = digits[i];
    }

    setState(() {});

    final code = _controllers.map((c) => c.text.trim()).join();
    if (code.length == 6) {
      FocusScope.of(context).unfocus();
    } else {
      int nextEmpty = _controllers.indexWhere((c) => c.text.isEmpty);
      if (nextEmpty != -1 && nextEmpty < 6) {
        _focusNodes[nextEmpty].requestFocus();
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      final match = RegExp(r'\b\d{6}\b').firstMatch(text);
      final digits = match != null ? match.group(0)! : text.replaceAll(RegExp(r'\D'), '');

      if (digits.isNotEmpty) {
        _fillOtp(digits, startIndex: 0);
        if (mounted) {
          AppToast.show(context, l10n.verificationCodePasted, isError: false);
        }
      } else {
        if (mounted) {
          AppToast.show(context, l10n.noCodeInClipboard, isError: true);
        }
      }
    } catch (_) {}
  }

  void _onCodeChanged(int index, String value) {
    if (_isCodeValid != null) {
      setState(() {
        _isCodeValid = null;
      });
    }

    final match = RegExp(r'\b\d{6}\b').firstMatch(value);
    final digits = match != null ? match.group(0)! : value.replaceAll(RegExp(r'\D'), '');

    if (digits.length >= 3) {
      _fillOtp(digits, startIndex: index);
      return;
    }

    if (digits.isEmpty) {

      _controllers[index].text = '';

      setState(() {});
      return;
    }

    String singleDigit = digits.substring(digits.length - 1);
    _controllers[index].text = singleDigit;
    setState(() {});

    if (index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          timer.cancel();
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _purpose {
    if (widget.isTwoFactorLogin) return 'login_2fa';
    if (widget.isDeleteAccount) return 'delete_account';
    if (widget.isForgotPassword) return 'reset';
    return 'signup';
  }

  void _verify() async {
    final l10n = context.l10n;
    final currentLang = Localizations.localeOf(context).languageCode;
    final code = _controllers.map((c) => c.text.replaceAll('\u200B', '')).join();
    
    if (code.length < 6) {
      setState(() {
        _isCodeValid = false;
      });
      AppToast.show(context, l10n.errorEnterOtp, isError: true);
      return;
    }
    
    setState(() {
      _isLoading = true;
      _isCodeValid = null;
      AppToast.clear();
    });

    final purpose = _purpose;

    try {
      final requestBody = <String, dynamic>{
        'email': widget.email,
        'otp': code,
        'purpose': purpose,
      };
      if (widget.isTwoFactorLogin) {
        final resolvedDeviceName = (widget.deviceName != null && widget.deviceName!.isNotEmpty)
            ? widget.deviceName!
            : await DeviceService.getDeviceName();
        final resolvedDeviceId = (widget.deviceId != null && widget.deviceId!.isNotEmpty)
            ? widget.deviceId!
            : await DeviceService.getDeviceId();
        requestBody['twoFactorToken'] = widget.twoFactorToken ?? '';
        requestBody['deviceName'] = resolvedDeviceName;
        requestBody['deviceId'] = resolvedDeviceId;
        requestBody['language'] = currentLang;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.verifyOtp),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));
      
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      
      if (response.statusCode == 200) {
        if (widget.isTwoFactorLogin) {
          final data = jsonDecode(response.body);
          final token = data['token'] as String?;
          final account = data['account'] as Map<String, dynamic>?;
          if (token == null || token.isEmpty || account == null) {
            setState(() {
              _isCodeValid = false;
            });
            AppToast.show(context, l10n.serverError, isError: true);
            return;
          }

          setState(() {
            _isCodeValid = true;
          });

          final resolvedEmail = account['email']?.toString() ?? widget.email;
          await SessionService.saveSession(
            resolvedEmail,
            token: token,
            userId: account['_id']?.toString() ?? account['id']?.toString(),
            username: account['username']?.toString(),
            avatar: account['avatar']?.toString(),
            qrCode: account['qrCode']?.toString(),
          );
          unawaited(NotificationService.syncTokenWithBackend());

          if (!mounted) return;
          if (widget.returnResultOnVerify) {
            Navigator.pop(context, true);
            return;
          }

          AppToast.success(context, l10n.signInSuccess);
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.main,
            (route) => false,
            arguments: resolvedEmail,
          );
          return;
        }

        setState(() {
          _isCodeValid = true;
        });
        AppToast.show(context, l10n.emailVerified, isError: false);
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        if (widget.isDeleteAccount) {
          Navigator.pushReplacementNamed(context, AppRoutes.deleteAccount);
        } else if (widget.isForgotPassword) {
          Navigator.pushReplacementNamed(context, AppRoutes.changePassword, arguments: widget.email);
        } else {
          Navigator.pushNamed(context, AppRoutes.setupName, arguments: widget.email);
        }
      } else {
        final data = jsonDecode(response.body);
        String errorCode = data['code'] ?? '';
        
        setState(() {
          _isCodeValid = false;
        });
        
        final errorMsg = l10n.errorFromCode(errorCode, fallbackMessage: data['message']);
        AppToast.show(context, errorMsg, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (e is SocketException || e is TimeoutException) {
        AppToast.show(context, l10n.noInternet, isError: true);
      } else {
        AppToast.show(context, l10n.serverError, isError: true);
      }
    }
  }

  void _resendCode() async {
    final l10n = context.l10n;
    setState(() {
      _isResending = true;
      AppToast.clear();
    });
    
    try {
      String currentLang = Localizations.localeOf(context).languageCode;
      final purpose = _purpose;
      final requestBody = <String, dynamic>{
        'email': widget.email,
        'purpose': purpose,
        'language': currentLang,
      };
      if (widget.isTwoFactorLogin &&
          widget.twoFactorToken != null &&
          widget.twoFactorToken!.isNotEmpty) {
        requestBody['twoFactorToken'] = widget.twoFactorToken;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.sendOtp),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));
      
      if (!mounted) return;
      setState(() {
        _isResending = false;
      });
      
      if (response.statusCode == 200) {
        _startTimer();
        AppToast.show(context, l10n.newVerificationCodeSent, isError: false);
      } else {
        final data = jsonDecode(response.body);
        String errorCode = data['code'] ?? '';
        final errorMsg = l10n.errorFromCode(errorCode, fallbackMessage: data['message']);
        AppToast.show(context, errorMsg, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
      });
      if (e is SocketException || e is TimeoutException) {
        AppToast.show(context, l10n.noInternet, isError: true);
      } else {
        AppToast.show(context, l10n.serverError, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 20.r),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 24.w,
                        right: 24.w,
                        top: 12.h,
                        bottom: 24.h,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: 16.h),
                          Center(
                            child: Container(
                              padding: EdgeInsets.all(24.r),
                              decoration: BoxDecoration(
                                color: AppColors.blue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.mark_email_read_outlined,
                                size: 72.r,
                                color: AppColors.blue,
                              ),
                            ),
                          ),
                          SizedBox(height: 28.h),
                          Text(
                            l10n.verifyEmail,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            l10n.verificationCodeSent,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: context.textMuted,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            widget.email.isNotEmpty ? widget.email : 'user@example.com',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.blue,
                            ),
                          ),
                          SizedBox(height: 32.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (index) => _buildCodeBox(index)),
                          ),

                          SizedBox(height: 16.h),

                          Center(
                            child: TextButton.icon(
                              onPressed: _pasteFromClipboard,
                              icon: Icon(
                                Icons.content_paste_rounded,
                                size: 16.r,
                                color: AppColors.blue,
                              ),
                              label: Text(
                                l10n.pasteVerificationCode,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.blue,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                backgroundColor: AppColors.blue.withValues(alpha: 0.08),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 24.h),
                          
                          ElevatedButton(
                            onPressed: _isLoading ? null : _verify,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.blue,
                              disabledBackgroundColor: AppColors.blue.withValues(alpha: 0.7),
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              minimumSize: Size.fromHeight(56.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                            ),
                            child: _isLoading
                              ? SizedBox(
                                  width: 24.r,
                                  height: 24.r,
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  l10n.verifyCode,
                                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                          ),

                          const Spacer(),

                          SizedBox(height: 20.h),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                l10n.didNotReceiveCode,
                                style: TextStyle(
                                  fontSize: 14.sp, 
                                  color: AppColors.gray,
                                ),
                              ),
                              GestureDetector(
                                onTap: (_secondsRemaining > 0 || _isResending)
                                    ? null
                                    : _resendCode,
                                child: _isResending
                                    ? SizedBox(
                                        width: 14.r,
                                        height: 14.r,
                                        child: const CircularProgressIndicator(
                                          color: AppColors.blue,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _secondsRemaining > 0
                                            ? '$_secondsRemaining${l10n.secondsShort}'
                                            : l10n.resendCode,
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          color: _secondsRemaining > 0 ? Colors.grey : AppColors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBox(int index) {
    final text = _controllers[index].text;
    final hasText = text.isNotEmpty;
    final isFocused = _focusNodes[index].hasFocus;

    Color borderColor;
    double borderWidth = 1.2;

    if (_isCodeValid == true) {
      borderColor = AppColors.green;
      borderWidth = 1.8;
    } else if (_isCodeValid == false) {
      borderColor = AppColors.red;
      borderWidth = 1.8;
    } else if (isFocused) {
      borderColor = AppColors.blue;
      borderWidth = 2.0;
    } else if (hasText) {
      borderColor = AppColors.blue.withValues(alpha: 0.6);
      borderWidth = 1.5;
    } else {
      borderColor = context.isDark ? Colors.white24 : Colors.black12;
      borderWidth = 1.2;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 48.w,
      height: 56.h,
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: AppColors.blue.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [

          if (hasText)
            Center(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                  height: 1.0,
                ),
              ),
            )
          else if (isFocused)
            Center(
              child: Container(
                width: 2.w,
                height: 22.h,
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(1.r),
                ),
              ),
            ),

          Positioned.fill(
            child: Opacity(
              opacity: 0.0,
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                showCursor: false,
                enableInteractiveSelection: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  filled: false,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  counterText: '',
                ),
                onTap: () {
                  _controllers[index].selection = TextSelection.fromPosition(
                    TextPosition(offset: _controllers[index].text.length),
                  );
                },
                onChanged: (value) => _onCodeChanged(index, value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
