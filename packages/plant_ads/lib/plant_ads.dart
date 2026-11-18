/// Optional ads for HomiLabs Plant Tools: UMP consent, then the Mobile Ads
/// SDK, one anchored banner on the home screen and an "Ad choices" entry in
/// Settings. Apps without ads must not depend on this package, so they keep
/// no internet or advertising-ID permission.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class PlantAds {
  PlantAds._();

  /// True once consent is resolved and the SDK may request ads.
  static final ready = ValueNotifier<bool>(false);

  /// Whether Settings must offer the privacy options (ad choices) form.
  static final privacyOptionsRequired = ValueNotifier<bool>(false);

  /// Call once from main(); does not block the first frame.
  static Future<void> init() async {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        done.complete();
      },
      (_) => done.complete(), // offline or error: use what is stored
    );
    await done.future;

    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    privacyOptionsRequired.value =
        status == PrivacyOptionsRequirementStatus.required;

    if (await ConsentInformation.instance.canRequestAds()) {
      await MobileAds.instance.initialize();
      ready.value = true;
    }
  }

  /// Settings rows: "Ad choices" when the consent rules require it.
  static List<Widget> settingsRows(BuildContext context) => [
    ValueListenableBuilder<bool>(
      valueListenable: privacyOptionsRequired,
      builder: (context, required, _) => !required
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Ad choices'),
                subtitle: const Text('Change your consent for ads'),
                onTap: () => ConsentForm.showPrivacyOptionsForm((_) {}),
              ),
            ),
    ),
  ];
}

/// Anchored adaptive banner. Home screen only, never on a tool screen.
class PlantBanner extends StatefulWidget {
  const PlantBanner({super.key, required this.adUnitId});

  final String adUnitId;

  @override
  State<PlantBanner> createState() => _PlantBannerState();
}

class _PlantBannerState extends State<PlantBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _requestedWidth;

  Future<void> _load(int width) async {
    _requestedWidth = width;
    final size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
          MediaQuery.orientationOf(context),
          width,
        );
    if (!mounted || size == null) return;
    final ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    setState(() => _ad = ad);
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PlantAds.ready,
      builder: (context, ready, _) {
        if (!ready) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.truncate();
            if (_requestedWidth == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _requestedWidth == null) _load(width);
              });
            }
            final ad = _ad;
            if (ad == null || !_loaded) return const SizedBox.shrink();
            return SafeArea(
              top: false,
              child: SizedBox(
                width: ad.size.width.toDouble(),
                height: ad.size.height.toDouble(),
                child: AdWidget(ad: ad),
              ),
            );
          },
        );
      },
    );
  }
}
