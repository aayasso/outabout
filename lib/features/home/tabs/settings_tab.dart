import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../core/weather_theme_provider.dart';
import '../../../data/models/schedule_day.dart';
import '../../../services/auth_service.dart';
import '../../../services/behavioral_event_service.dart';
import '../../../services/notification_service.dart';
import '../home_providers.dart';

// ---------------------------------------------------------------------------
// SettingsTab — main entry point
// ---------------------------------------------------------------------------

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final profileAsync = ref.watch(profileProvider);
    final locationAsync = ref.watch(userLocationProvider);
    final packageAsync = ref.watch(packageInfoProvider);

    final displayName =
        profileAsync.valueOrNull?.displayName ?? 'OutAbout User';
    final location = locationAsync.valueOrNull;
    // City can be empty when reverse geocoding was throttled — the
    // location itself is still valid.
    final city = location?.city ?? '';
    final cityName = city.isEmpty ? 'Location set' : city;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: OutAboutSpacing.md,
            vertical: OutAboutSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: OutAboutTypography.headingLarge(colors)),
              const SizedBox(height: OutAboutSpacing.lg),
              _SettingsSection(
                colors: colors,
                children: [
                  _ProfileRow(displayName: displayName, colors: colors),
                ],
              ),
              const SizedBox(height: OutAboutSpacing.md),
              _SettingsSection(
                header: 'Location',
                colors: colors,
                children: [
                  if (location == null)
                    _SettingsRow(
                      icon: Icons.location_off_outlined,
                      label: 'Location not set',
                      colors: colors,
                      trailing: TextButton(
                        onPressed: openAppSettings,
                        child: Text(
                          'Enable location',
                          style: OutAboutTypography.labelLarge(
                            colors,
                          ).copyWith(color: colors.primary),
                        ),
                      ),
                    )
                  else
                    _SettingsRow(
                      icon: Icons.location_on_outlined,
                      label: cityName,
                      colors: colors,
                    ),
                ],
              ),
              const SizedBox(height: OutAboutSpacing.md),
              _SettingsSection(
                header: 'Appearance',
                colors: colors,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(OutAboutSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Theme',
                          style: OutAboutTypography.headingSmall(colors),
                        ),
                        const SizedBox(height: OutAboutSpacing.sm),
                        const _ThemeOverrideSelector(),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colors.divider),
                  _TemperatureUnitRow(colors: colors),
                  Divider(height: 1, color: colors.divider),
                  _ScheduleLayoutRow(colors: colors),
                ],
              ),
              const SizedBox(height: OutAboutSpacing.md),
              _SettingsSection(
                header: 'Legal',
                colors: colors,
                children: [
                  const _LegalLinkRow(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    url: LegalUrls.privacyPolicy,
                  ),
                  Divider(height: 1, color: colors.divider),
                  const _LegalLinkRow(
                    icon: Icons.description_outlined,
                    label: 'Terms of Service',
                    url: LegalUrls.termsOfService,
                  ),
                ],
              ),
              const SizedBox(height: OutAboutSpacing.md),
              _SettingsSection(
                header: 'Account',
                colors: colors,
                children: [
                  const _SignOutButton(),
                  Divider(height: 1, color: colors.divider),
                  const _DeleteAccountButton(),
                ],
              ),
              const SizedBox(height: OutAboutSpacing.lg),
              Center(
                child: packageAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (info) => Text(
                    'v${info.version} '
                    '(${info.buildNumber})',
                    style: OutAboutTypography.bodySmall(colors),
                  ),
                ),
              ),
              const SizedBox(height: OutAboutSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SettingsSection
// ---------------------------------------------------------------------------

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    this.header,
    required this.children,
    required this.colors,
  });

  final String? header;
  final List<Widget> children;
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: OutAboutSpacing.xs,
              bottom: OutAboutSpacing.sm,
            ),
            child: Text(header!, style: OutAboutTypography.labelMedium(colors)),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(OutAboutRadius.cards),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _SettingsRow
// ---------------------------------------------------------------------------

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    required this.colors,
  });

  final IconData? icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OutAboutSpacing.md,
            vertical: OutAboutSpacing.sm,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: colors.textSecondary),
                const SizedBox(width: OutAboutSpacing.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  style: OutAboutTypography.bodyMedium(colors),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ProfileRow
// ---------------------------------------------------------------------------

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.displayName, required this.colors});

  final String displayName;
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.all(OutAboutSpacing.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: OutAboutTypography.headingMedium(
                  colors,
                ).copyWith(color: colors.primary),
              ),
            ),
          ),
          const SizedBox(width: OutAboutSpacing.md),
          Expanded(
            child: Text(
              displayName,
              style: OutAboutTypography.headingSmall(colors),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ThemeOverrideSelector
// ---------------------------------------------------------------------------

class _ThemeOverrideSelector extends ConsumerWidget {
  const _ThemeOverrideSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final currentOverride = ref.watch(userThemeOverrideProvider);

    final options = <({String label, WeatherTheme? theme})>[
      (label: 'Adaptive', theme: null),
      ...WeatherTheme.values.map((t) => (label: t.displayName, theme: t)),
    ];

    return Wrap(
      spacing: OutAboutSpacing.sm,
      runSpacing: OutAboutSpacing.sm,
      children: options.map((option) {
        final isActive = option.theme == currentOverride;

        return GestureDetector(
          onTap: () {
            ref
                .read(userThemeOverrideProvider.notifier)
                .setOverride(option.theme);
            OutAboutHaptics.onConditionToggle();
            final themeName = option.theme?.name ?? 'adaptive';
            ref
                .read(behavioralEventServiceProvider)
                .log('theme_override_set', extra: {'theme': themeName});
            ref
                .read(behavioralEventServiceProvider)
                .log(
                  'settings_changed',
                  extra: {'setting': 'theme_override', 'new_value': themeName},
                );
          },
          child: Semantics(
            label:
                'Theme: ${option.label}'
                '${isActive ? ', selected' : ''}',
            button: true,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: OutAboutSpacing.sm,
                vertical: OutAboutSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isActive ? colors.primary : colors.surface,
                borderRadius: BorderRadius.circular(OutAboutRadius.full),
                border: isActive ? null : Border.all(color: colors.divider),
              ),
              child: Text(
                option.label,
                style: OutAboutTypography.labelSmall(colors).copyWith(
                  color: isActive
                      ? (WeatherThemeColors.forTheme(
                                  ref.watch(weatherThemeProvider),
                                ).background ==
                                colors.background
                            ? colors.cardBackground
                            : Colors.white)
                      : colors.text,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// _TemperatureUnitRow
// ---------------------------------------------------------------------------

class _TemperatureUnitRow extends ConsumerWidget {
  const _TemperatureUnitRow({required this.colors});

  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final currentUnit = profileAsync.valueOrNull?.temperatureUnit ?? 'F';

    return _SettingsRow(
      icon: Icons.thermostat_outlined,
      label: 'Temperature unit',
      trailing: Text(
        '\u00B0$currentUnit',
        style: OutAboutTypography.bodyMedium(
          colors,
        ).copyWith(color: colors.textSecondary),
      ),
      onTap: () async {
        final profile = profileAsync.valueOrNull;
        if (profile == null) return;
        final newUnit = currentUnit == 'F' ? 'C' : 'F';
        final client = ref.read(supabaseClientProvider);
        await client
            .from('profiles')
            .update({
              'temperature_unit': newUnit,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', profile.id);
        ref.invalidate(profileProvider);
        OutAboutHaptics.onConditionToggle();
        ref
            .read(behavioralEventServiceProvider)
            .log(
              'settings_changed',
              extra: {'setting': 'temperature_unit', 'new_value': newUnit},
            );
      },
      colors: colors,
    );
  }
}

// ---------------------------------------------------------------------------
// _ScheduleLayoutRow
// ---------------------------------------------------------------------------

class _ScheduleLayoutRow extends ConsumerWidget {
  const _ScheduleLayoutRow({required this.colors});

  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(scheduleLayoutProvider);
    final label = layout == ScheduleLayout.dayFirst
        ? 'Day-first'
        : 'Activity-first';

    return _SettingsRow(
      icon: Icons.view_agenda_outlined,
      label: 'Schedule layout',
      trailing: Text(
        label,
        style: OutAboutTypography.bodyMedium(
          colors,
        ).copyWith(color: colors.textSecondary),
      ),
      onTap: () {
        final newLayout = layout == ScheduleLayout.dayFirst
            ? ScheduleLayout.activityFirst
            : ScheduleLayout.dayFirst;
        ref.read(scheduleLayoutProvider.notifier).setLayout(newLayout);
        OutAboutHaptics.onConditionToggle();
        ref
            .read(behavioralEventServiceProvider)
            .log(
              'settings_changed',
              extra: {
                'setting': 'schedule_layout',
                'new_value': newLayout.name,
              },
            );
      },
      colors: colors,
    );
  }
}

// ---------------------------------------------------------------------------
// _SignOutButton
// ---------------------------------------------------------------------------

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return InkWell(
      onTap: () => _showSignOutDialog(context, ref),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OutAboutSpacing.md,
            vertical: OutAboutSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(Icons.logout, size: 22, color: OutAboutColors.errorColor),
              const SizedBox(width: OutAboutSpacing.sm),
              Text(
                'Sign out',
                style: OutAboutTypography.bodyMedium(
                  colors,
                ).copyWith(color: OutAboutColors.errorColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSignOutDialog(BuildContext context, WidgetRef ref) async {
    final colors = ref.read(weatherThemeColorsProvider);
    // Captured before the dialog await — this widget is stateless, so there
    // is no `mounted` to check on the far side of the gap.
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Text(
          'Sign out?',
          style: OutAboutTypography.headingMedium(colors),
        ),
        content: Text(
          'You\'ll need to sign in again to '
          'access your activities.',
          style: OutAboutTypography.bodyMedium(colors),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: OutAboutTypography.labelLarge(
                colors,
              ).copyWith(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Sign out',
              style: OutAboutTypography.labelLarge(
                colors,
              ).copyWith(color: OutAboutColors.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    ref.read(notificationServiceProvider).clearUserTag();

    final client = ref.read(supabaseClientProvider);
    await client.auth.signOut();

    // Navigate explicitly. The redirect would also fire via the router's
    // auth refreshListenable, but relying on it alone left the user sitting
    // on a signed-out Settings tab.
    router.go(AppRoutes.onboarding);
  }
}

// ---------------------------------------------------------------------------
// _DeleteAccountButton
// ---------------------------------------------------------------------------

class _DeleteAccountButton extends ConsumerWidget {
  const _DeleteAccountButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return Semantics(
      button: true,
      label: 'Delete account. Permanently removes your account and data.',
      child: InkWell(
        onTap: () async {
          final deleted = await showDialog<bool>(
            context: context,
            builder: (_) => const _DeleteAccountDialog(),
          );
          // Navigation lives here, not in the dialog: this context is inside
          // the router's tree, and the dialog's own context is defunct by the
          // time it pops.
          if (deleted == true && context.mounted) {
            context.go(AppRoutes.onboarding);
          }
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OutAboutSpacing.md,
              vertical: OutAboutSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.delete_forever_outlined,
                  size: 22,
                  color: OutAboutColors.errorColor,
                ),
                const SizedBox(width: OutAboutSpacing.sm),
                Text(
                  'Delete Account',
                  style: OutAboutTypography.bodyMedium(
                    colors,
                  ).copyWith(color: OutAboutColors.errorColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DeleteAccountDialog
// ---------------------------------------------------------------------------

/// Confirmation for an irreversible account deletion.
///
/// The confirm control stays disabled until [_confirmationWord] is typed
/// exactly, so the action cannot be triggered by a stray tap.
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  static const _confirmationWord = 'DELETE';

  final _controller = TextEditingController();
  bool _isDeleting = false;
  String? _errorMessage;

  /// Exact match — not trimmed, not case-insensitive. This is deliberate
  /// friction on an irreversible action.
  bool get _canConfirm => _controller.text == _confirmationWord;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    if (!_canConfirm || _isDeleting) return;

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });
    OutAboutHaptics.onActivitySave();

    // Logged before the delete call. The row is removed along with the rest
    // of the user's data — that is intended; it only needs to exist long
    // enough to appear in a replica or backup taken mid-deletion.
    await ref
        .read(behavioralEventServiceProvider)
        .log('account_deletion_requested');

    final result = await ref.read(authServiceProvider).deleteAccount();

    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isDeleting = false;
      _errorMessage = result.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return AlertDialog(
      backgroundColor: colors.cardBackground,
      title: Text(
        'Delete account?',
        style: OutAboutTypography.headingMedium(colors),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This permanently deletes your account and everything in it — '
            'your activities, categories, saved location and preferences. '
            'This cannot be undone, and your account cannot be recovered.',
            style: OutAboutTypography.bodyMedium(colors),
          ),
          const SizedBox(height: OutAboutSpacing.md),
          Text(
            'Type $_confirmationWord to confirm.',
            style: OutAboutTypography.labelMedium(colors),
          ),
          const SizedBox(height: OutAboutSpacing.sm),
          Semantics(
            label: 'Type $_confirmationWord to enable deletion',
            child: TextField(
              controller: _controller,
              enabled: !_isDeleting,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              style: OutAboutTypography.bodyMedium(colors),
              decoration: InputDecoration(
                hintText: _confirmationWord,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    OutAboutRadius.buttons,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: OutAboutSpacing.sm),
            Text(
              _errorMessage!,
              style: OutAboutTypography.bodySmall(
                colors,
              ).copyWith(color: OutAboutColors.errorColor),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            minimumSize: const Size(64, 48),
          ),
          child: Text(
            'Cancel',
            style: OutAboutTypography.labelLarge(
              colors,
            ).copyWith(color: colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _canConfirm && !_isDeleting ? _handleDelete : null,
          style: TextButton.styleFrom(
            minimumSize: const Size(64, 48),
          ),
          child: _isDeleting
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: OutAboutColors.errorColor,
                  ),
                )
              : Text(
                  'Delete Account',
                  style: OutAboutTypography.labelLarge(colors).copyWith(
                    color: _canConfirm
                        ? OutAboutColors.errorColor
                        : colors.textSecondary,
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _LegalLinkRow
// ---------------------------------------------------------------------------

/// Opens a hosted legal document in the browser.
///
/// Apple expects a reachable privacy policy, and linking it in-app is the
/// convention reviewers look for.
class _LegalLinkRow extends ConsumerWidget {
  const _LegalLinkRow({
    required this.icon,
    required this.label,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String url;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final colors = ref.read(weatherThemeColorsProvider);

    final opened = await ref.read(urlLauncherProvider)(Uri.parse(url));
    if (opened) return;

    messenger?.showSnackBar(
      SnackBar(
        backgroundColor: colors.cardBackground,
        content: Text(
          'Could not open $label.',
          style: OutAboutTypography.bodyMedium(colors),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return Semantics(
      button: true,
      link: true,
      label: '$label, opens in browser',
      child: _SettingsRow(
        icon: icon,
        label: label,
        colors: colors,
        onTap: () => _open(context, ref),
        trailing: Icon(
          Icons.open_in_new,
          size: 18,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}
