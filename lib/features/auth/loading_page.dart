import 'package:flutter/material.dart';

import '../../models/company.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/company_logo.dart';

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key, this.logoUrl, this.companyName});

  final String? logoUrl;
  final String? companyName;

  @override
  Widget build(BuildContext context) {
    final logo = blankToNull(logoUrl);
    final name = blankToNull(companyName);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logo != null)
              CompanyLogo(
                key: const ValueKey('boot-company-logo'),
                url: logo,
                size: 88,
              )
            else if (name == null)
              const BrandLogo(),
            if (name != null) ...[
              if (logo != null) const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.terracotta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
