import 'package:flutter/material.dart';

import 'tower_flat_selector.dart';

class VerifyPassScreen extends StatefulWidget {
  const VerifyPassScreen({
    super.key,
    this.language,
    this.initialCode = '',
    this.onBack,
    this.onVerify,
    this.scannerBuilder,
    this.isVerifying = false,
  });

  final ValueNotifier<bool>? language;
  final String initialCode;
  final VoidCallback? onBack;
  final ValueChanged<String>? onVerify;
  final WidgetBuilder? scannerBuilder;
  final bool isVerifying;

  @override
  State<VerifyPassScreen> createState() => _VerifyPassScreenState();
}

class _VerifyPassScreenState extends State<VerifyPassScreen> {
  late String _code;
  var _scan = false;

  @override
  void initState() {
    super.initState();
    _code = RegExp(r'[0-9]')
        .allMatches(widget.initialCode)
        .take(6)
        .map((match) => match.group(0)!)
        .join();
  }

  void _verify() {
    if (_code.length == 6 && !widget.isVerifying) {
      widget.onVerify?.call(_code);
    }
  }

  Widget _tab(String label, IconData icon, bool scan) {
    final selected = _scan == scan;
    final color = selected ? Colors.white : GateStyle.green;
    return Expanded(
      child: GateTile(
        selected: selected,
        radius: 14,
        color: selected ? GateStyle.green : GateStyle.sand,
        onTap: widget.isVerifying ? null : () => setState(() => _scan = scan),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 47),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 21.2),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _key(String label, {bool erase = false}) {
    return Expanded(
      flex: label == '0' ? 2 : 1,
      child: Semantics(
        label: erase ? label : null,
        child: GateTile(
          onTap: widget.isVerifying
              ? null
              : () => setState(() {
                  if (erase && _code.isNotEmpty) {
                    _code = _code.substring(0, _code.length - 1);
                  } else if (!erase && _code.length < 6) {
                    _code += label;
                  }
                }),
          child: SizedBox(
            height: 64,
            child: Center(
              child: erase
                  ? const Icon(
                      Icons.backspace_outlined,
                      color: GateStyle.green,
                      size: 32.2,
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: GateStyle.green,
                          fontSize: 36.8,
                          height: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = widget.language ?? gateIsHindi;
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, hindi, _) {
        String t(String en, String hi) => gateText(hindi, en, hi);
        return GatePage(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 6, 16, 0),
                child: GateHeader(
                  title: t('Verify a Pass', 'पास जाँचें'),
                  language: notifier,
                  onBack: widget.onBack,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [
                    Text(
                      t(
                        'Ask resident for 6-digit code OR scan QR',
                        'निवासी से 6 अंकों का कोड पूछें या QR स्कैन करें',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: GateStyle.muted,
                        fontSize: 13.8,
                      ),
                    ),
                    const SizedBox(height: 18),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: GateStyle.sand,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: GateStyle.line),
                      ),
                      child: Row(
                        children: [
                          _tab(
                            t('123 Enter Code', '123 कोड डालें'),
                            Icons.apps_rounded,
                            false,
                          ),
                          _tab(
                            t('QR Scan Camera', 'कैमरे से QR स्कैन'),
                            Icons.qr_code_scanner,
                            true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_scan)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: widget.scannerBuilder == null
                              ? ColoredBox(
                                  color: GateStyle.green,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.qr_code_scanner_rounded,
                                          size: 84.6,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          t(
                                            "Point camera at visitor's QR code",
                                            'कैमरा आगंतुक के QR कोड की ओर करें',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.7,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Builder(builder: widget.scannerBuilder!),
                        ),
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: GateStyle.line),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Semantics(
                              label: t('Entered code', 'डाला गया कोड'),
                              value: _code.characters.join(' '),
                              excludeSemantics: true,
                              child: Row(
                                children: [
                                  for (var i = 0; i < 6; i++)
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          right: i == 5 ? 0 : 5,
                                        ),
                                        child: Container(
                                          height: 63,
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: GateStyle.sand,
                                            border: Border.all(
                                              color: GateStyle.line,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              9,
                                            ),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              i < _code.length ? _code[i] : '',
                                              style: const TextStyle(
                                                color: GateStyle.green,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 35,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 13),
                            GateButton(
                              label: t('Verify Pass', 'पास जाँचें'),
                              busy: widget.isVerifying,
                              onPressed:
                                  _code.length == 6 && widget.onVerify != null
                                  ? _verify
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (var row = 0; row < 3; row++) ...[
                        Row(
                          children: [
                            _key('${row * 3 + 1}'),
                            const SizedBox(width: 6),
                            _key('${row * 3 + 2}'),
                            const SizedBox(width: 6),
                            _key('${row * 3 + 3}'),
                          ],
                        ),
                        const SizedBox(height: 7),
                      ],
                      Row(
                        children: [
                          _key('0'),
                          const SizedBox(width: 6),
                          _key(
                            t('Delete last digit', 'आखिरी अंक मिटाएँ'),
                            erase: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: GateStyle.mint,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 44.2,
                              color: GateStyle.green,
                            ),
                            const SizedBox(width: 10),
                            const SizedBox(
                              height: 43,
                              child: VerticalDivider(
                                width: 1,
                                color: GateStyle.green,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t('Have a QR pass?', 'QR पास है?'),
                                    style: const TextStyle(
                                      color: GateStyle.green,
                                      fontSize: 14.7,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    t(
                                      "Tap 'QR Scan Camera' above",
                                      'ऊपर कैमरे से QR स्कैन चुनें',
                                    ),
                                    style: const TextStyle(
                                      color: GateStyle.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.mobile_friendly_rounded,
                              size: 27.6,
                              color: GateStyle.green,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
