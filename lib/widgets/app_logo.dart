import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 48.0 : 64.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(compact ? 14 : 19),
          ),
          child: Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: compact ? 25 : 32,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'DompetKu',
          style: TextStyle(
            color: context.palette.text,
            fontSize: compact ? 21 : 26,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
