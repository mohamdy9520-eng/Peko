import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F3),
        body: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Center(
                        child: Lottie.asset(
                          'assets/lottie/Revenue.json',
                          width: 320.w,
                          height: 320.h,
                          fit: BoxFit.contain,
                          repeat: true,
                        ),
                      ),
                    ),

                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 30.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(30.r),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Spend Smarter\nSave More",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 38.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF3E8E86),
                            ),
                          ),

                          SizedBox(height: 25.h),

                        SizedBox(
                          width: double.infinity,
                          height: 60.h,
                          child: ElevatedButton(
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();

                              await prefs.setBool(
                                'has_seen_onboarding',
                                true,
                              );

                              context.go('/signup');
                            },

                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5FA89E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.r),
                              ),
                              elevation: 6,
                              padding: EdgeInsets.zero,
                            ),

                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "Get Started",
                                style: TextStyle(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),

                          SizedBox(height: 15.h),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Already Have Account? "),
                              GestureDetector(
                                onTap: () async {
                                  final prefs =
                                  await SharedPreferences.getInstance();

                                  await prefs.setBool(
                                    'has_seen_onboarding',
                                    true,
                                  );

                                  context.go("/login");
                                },
                                child: const Text(
                                  "Log In",
                                  style: TextStyle(
                                    color: Color(0xFF3E8E86),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }
}