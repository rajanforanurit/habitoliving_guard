import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GateStyle {
  GateStyle._();

  static const background = Color(0xFFF9F8F5);
  static const sand = Color(0xFFEFECE6);
  static const green = Color(0xFF145338);
  static const ink = Color(0xFF1A241E);
  static const muted = Color(0xFF505750);
  static const line = Color(0xFFE2DED6);
  static const mint = Color(0xFFEBF3EE);
  static const pink = Color(0xFFFCE8E8);
  static const red = Color(0xFFC53030);
}

final gateIsHindi = ValueNotifier<bool>(false);

String gateText(bool hindi, String english, String hindiText) =>
    hindi ? hindiText : english;

class GateLanguageButton extends StatelessWidget {
  const GateLanguageButton({super.key, required this.notifier});
  final ValueNotifier<bool> notifier;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () => notifier.value = !notifier.value,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      backgroundColor: GateStyle.sand,
      foregroundColor: GateStyle.green,
      side: const BorderSide(color: GateStyle.line),
      textStyle: const TextStyle(fontSize: 13.8, fontWeight: FontWeight.w800),
    ),
    child: const Text('हिंदी / EN'),
  );
}

class GatePage extends StatelessWidget {
  const GatePage({
    super.key,
    required this.body,
    this.footer,
    this.maxWidth = 540,
  });

  final Widget body;
  final Widget? footer;
  final double maxWidth;

  static final _theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: GateStyle.green),
    scaffoldBackgroundColor: GateStyle.background,
    useMaterial3: true,
    iconTheme: const IconThemeData(size: 22),
  );

  Widget centered(Widget child) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Theme(
      data: _theme,
      child: Scaffold(
        body: SafeArea(
          bottom: footer == null,
          child: Column(
            children: [
              Expanded(child: centered(body)),
              if (footer != null)
                SafeArea(top: false, child: centered(footer!)),
            ],
          ),
        ),
      ),
    ),
  );
}

class GateHeader extends StatelessWidget {
  const GateHeader({
    super.key,
    required this.title,
    required this.language,
    this.onBack,
  });

  final String title;
  final ValueNotifier<bool> language;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: gateText(language.value, 'Back', 'वापस'),
        onPressed: onBack ?? () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_rounded, color: GateStyle.green),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: GateStyle.green,
            fontSize: 24.8,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(width: 6),
      GateLanguageButton(notifier: language),
    ],
  );
}

class GateSection extends StatelessWidget {
  const GateSection(this.icon, this.title, {super.key, this.suffix});
  final IconData icon;
  final String title;
  final String? suffix;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon, color: GateStyle.green, size: 23),
        const SizedBox(width: 10),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: title,
              children: [
                if (suffix != null)
                  TextSpan(
                    text: '  ${suffix!}',
                    style: const TextStyle(
                      color: GateStyle.muted,
                      fontSize: 12.9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            style: const TextStyle(
              color: GateStyle.ink,
              fontSize: 16.6,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class GateButton extends StatelessWidget {
  const GateButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: GateStyle.green,
        foregroundColor: Colors.white,
        disabledBackgroundColor: GateStyle.green,
        disabledForegroundColor: Colors.white70,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            const SizedBox.square(
              dimension: 19,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else if (icon != null)
            Icon(icon, size: 20.2),
          if (busy || icon != null) const SizedBox(width: 9),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16.6,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class GateTile extends StatelessWidget {
  const GateTile({
    super.key,
    required this.child,
    required this.onTap,
    this.color = GateStyle.sand,
    this.radius = 16,
    this.selected,
    this.outlined = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final double radius;
  final bool? selected;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: outlined
          ? const BorderSide(color: GateStyle.green, width: 2)
          : BorderSide.none,
    );
    return Semantics(
      selected: selected,
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(customBorder: shape, onTap: onTap, child: child),
      ),
    );
  }
}

class TowerFlatSelector extends StatefulWidget {
  const TowerFlatSelector({
    super.key,
    required this.flatsByTower,
    required this.onSelectionChanged,
    this.language,
  });

  final Map<String, List<String>> flatsByTower;
  final void Function(String? tower, String? flat) onSelectionChanged;
  final ValueNotifier<bool>? language;

  @override
  State<TowerFlatSelector> createState() => _TowerFlatSelectorState();
}

class _TowerFlatSelectorState extends State<TowerFlatSelector> {
  String? _tower;
  String? _flat;
  var _notification = 0;

  void _reconcile() {
    final towers = widget.flatsByTower;
    final tower = towers.length == 1
        ? towers.keys.single
        : towers.containsKey(_tower)
        ? _tower
        : null;
    if (tower != _tower || !(towers[tower]?.contains(_flat) ?? false)) {
      _flat = null;
    }
    _tower = tower;
  }

  void _notifyAfterBuild() {
    final notification = ++_notification;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && notification == _notification) {
        widget.onSelectionChanged(_tower, _flat);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _reconcile();
    if (_tower != null) _notifyAfterBuild();
  }

  @override
  void didUpdateWidget(covariant TowerFlatSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = (_tower, _flat);
    _reconcile();
    if (previous != (_tower, _flat)) _notifyAfterBuild();
  }

  void _select(String? tower, String? flat) {
    _notification++;
    setState(() {
      _tower = tower;
      _flat = flat;
    });
    widget.onSelectionChanged(tower, flat);
  }

  Widget _grid(
    List<String> items,
    int columns,
    String Function(String) label,
    ValueChanged<String> onTap,
    Key key,
  ) {
    const height = 46.0;
    const gap = 7.0;
    final rows = math.min(4, (items.length / columns).ceil());
    return SizedBox(
      height: rows * height + (rows - 1) * gap,
      child: GridView.builder(
        key: key,
        primary: false,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: height,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
        ),
        itemBuilder: (context, index) => GateTile(
          radius: 11,
          onTap: () => onTap(items[index]),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label(items[index]),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: GateStyle.ink,
                  fontSize: 13.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.language ?? gateIsHindi,
    builder: (context, hindi, _) {
      final tower = _tower;
      final flats = widget.flatsByTower[tower] ?? const <String>[];
      String towerLabel(String value) => hindi && value.startsWith('Tower ')
          ? 'टावर ${value.substring(6)}'
          : value;

      if (widget.flatsByTower.isEmpty) {
        return Text(
          gateText(hindi, 'No towers available', 'कोई टावर उपलब्ध नहीं है'),
        );
      }
      if (tower == null) {
        return _grid(
          widget.flatsByTower.keys.toList(),
          3,
          towerLabel,
          (value) => _select(value, null),
          const ValueKey('towers'),
        );
      }
      if (_flat != null) {
        final flatLabel = gateText(hindi, 'Flat', 'फ़्लैट');
        return Container(
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            color: GateStyle.mint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${towerLabel(tower)}  •  $flatLabel $_flat',
                  style: const TextStyle(
                    color: GateStyle.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: GateStyle.green),
                onPressed: () => _select(tower, null),
                child: Text(gateText(hindi, 'Change', 'बदलें')),
              ),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputChip(
            label: Text(towerLabel(tower)),
            backgroundColor: GateStyle.mint,
            labelStyle: const TextStyle(
              color: GateStyle.green,
              fontWeight: FontWeight.w700,
            ),
            deleteIconColor: GateStyle.green,
            deleteButtonTooltipMessage: gateText(
              hindi,
              'Change tower',
              'टावर बदलें',
            ),
            side: BorderSide.none,
            shape: const StadiumBorder(),
            onDeleted: widget.flatsByTower.length > 1
                ? () => _select(null, null)
                : null,
          ),
          const SizedBox(height: 6),
          if (flats.isEmpty)
            Text(
              gateText(
                hindi,
                'No flats available',
                'कोई फ़्लैट उपलब्ध नहीं है',
              ),
            )
          else
            _grid(
              flats,
              4,
              (value) => value,
              (value) => _select(tower, value),
              ValueKey(tower),
            ),
        ],
      );
    },
  );
}

/// A centered gate status that can scroll if the available height is small.
class GateStatusMessage extends StatelessWidget {
  const GateStatusMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: GateStyle.green, size: 49.7),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GateStyle.ink,
              fontSize: 20.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GateStyle.muted,
              fontSize: 13.8,
              height: 1.45,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 22), action!],
        ],
      ),
    ),
  );
}
