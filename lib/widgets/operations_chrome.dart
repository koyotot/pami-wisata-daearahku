import 'package:flutter/material.dart';
import '../screens/auth_presentation.dart';
import '../theme/app_colors.dart';

/// Role-one routes share the visitor identity without changing the app theme.
class OperationsTheme extends StatelessWidget {
  const OperationsTheme({super.key, required this.child, required this.role});
  final Widget child;
  final int? role;

  @override
  Widget build(BuildContext context) =>
      role == 1 ? Theme(data: AppColors.operationsTheme, child: child) : child;
}

class OperationsScenicHeader extends StatelessWidget {
  const OperationsScenicHeader(
      {super.key,
      required this.title,
      required this.subtitle,
      this.onBack,
      this.actions = const []});
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => TimeBasedScenicBackground(
        child: SafeArea(
            bottom: false,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        if (onBack != null)
                          BackButton(color: Colors.white, onPressed: onBack)
                        else
                          const SizedBox(
                              height: 48,
                              child: Icon(Icons.landscape_outlined,
                                  color: Colors.white)),
                        const SizedBox(width: 8),
                        const Expanded(
                            child: Text('Wisata Daerahku · Admin',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white))),
                        ...actions.map((action) => IconButtonTheme(
                            data: IconButtonThemeData(
                                style: IconButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(48, 48))),
                            child: action)),
                      ]),
                      const SizedBox(height: 12),
                      Text(title,
                          style: const TextStyle(
                              fontSize: 24,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 13, height: 1.5, color: Colors.white)),
                    ]))),
      );
}
