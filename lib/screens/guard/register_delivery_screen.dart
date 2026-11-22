import 'package:flutter/material.dart';

import 'tower_flat_selector.dart';

enum DeliveryCategory {
  grocery('Grocery', 'किराना', Icons.shopping_cart_rounded),
  parcel('Parcel', 'पार्सल', Icons.inventory_2_rounded),
  food('Food', 'खाना', Icons.restaurant_rounded),
  document('Document', 'कागज़ात', Icons.description_rounded),
  other('Other', 'अन्य', Icons.more_horiz_rounded);

  const DeliveryCategory(this.english, this.hindi, this.icon);
  final String english;
  final String hindi;
  final IconData icon;
}

enum DeliveryBrand {
  blinkit(
    'Blinkit',
    'blinkit',
    0xFFF8CB46,
    0xFF1A241E,
    DeliveryCategory.grocery,
  ),
  zepto('Zepto', 'zepto', 0xFF3B006A, 0xFFFFFFFF, DeliveryCategory.grocery),
  swiggy('Swiggy', 'Swiggy', 0xFFFC8019, 0xFF201005, DeliveryCategory.food),
  zomato('Zomato', 'zomato', 0xFFE23744, 0xFF1D0A0B, DeliveryCategory.food),
  amazon('Amazon', 'amazon', 0xFF131921, 0xFFFFFFFF, DeliveryCategory.parcel),
  flipkart(
    'Flipkart',
    'Flipkart',
    0xFF2874F0,
    0xFF101E36,
    DeliveryCategory.parcel,
  ),
  bigBasket(
    'BigBasket',
    'bigbasket',
    0xFF84C225,
    0xFF15210B,
    DeliveryCategory.grocery,
  ),
  myntra('Myntra', 'M', 0xFFFDE4EA, 0xFF1A241E, DeliveryCategory.parcel),
  other('Other', '+', 0xFFEFECE6, 0xFF1A241E, DeliveryCategory.other),
  delhivery(
    'Delhivery',
    'Delhivery',
    0xFF222222,
    0xFFFFFFFF,
    DeliveryCategory.parcel,
  ),
  blueDart(
    'Blue Dart',
    'Blue Dart',
    0xFF004B8D,
    0xFFFFFFFF,
    DeliveryCategory.parcel,
  ),
  dtdc('DTDC', 'DTDC', 0xFF1B365D, 0xFFFFFFFF, DeliveryCategory.parcel),
  eKart('Ekart', 'Ekart', 0xFFE1ECFE, 0xFF124079, DeliveryCategory.parcel),
  xpressbees(
    'Xpressbees',
    'Xpressbees',
    0xFFFFE8E3,
    0xFF822623,
    DeliveryCategory.parcel,
  ),
  ecomExpress(
    'Ecom Express',
    'Ecom',
    0xFFE5F2EB,
    0xFF145338,
    DeliveryCategory.parcel,
  ),
  indiaPost(
    'India Post',
    'Post',
    0xFFAA2025,
    0xFFFFFFFF,
    DeliveryCategory.document,
  ),
  dhl('DHL', 'DHL', 0xFFFFCC00, 0xFF8A001D, DeliveryCategory.parcel),
  fedEx('FedEx', 'FedEx', 0xFF4D148C, 0xFFFFFFFF, DeliveryCategory.parcel),
  shadowfax(
    'Shadowfax',
    'Shadowfax',
    0xFFEDE5FA,
    0xFF401E62,
    DeliveryCategory.parcel,
  ),
  porter('Porter', 'Porter', 0xFF164AD6, 0xFFFFFFFF, DeliveryCategory.parcel),
  shiprocket(
    'Shiprocket',
    'Shiprocket',
    0xFFF0E9FB,
    0xFF44247C,
    DeliveryCategory.parcel,
  );

  const DeliveryBrand(
    this.label,
    this.mark,
    this.background,
    this.foreground,
    this.category,
  );

  final String label;
  final String mark;
  final int background;
  final int foreground;
  final DeliveryCategory category;
}

class DeliverySubmission {
  const DeliverySubmission({
    required this.tower,
    required this.flat,
    required this.brand,
    required this.category,
    this.courierName,
  });

  final String tower;
  final String flat;
  final DeliveryBrand brand;
  final DeliveryCategory category;
  final String? courierName;
}

class RegisterDeliveryScreen extends StatefulWidget {
  const RegisterDeliveryScreen({
    super.key,
    this.flatsByTower = const {},
    this.language,
    this.initialBrand,
    this.onBack,
    this.onSubmit,
    this.isSubmitting = false,
  });

  final Map<String, List<String>> flatsByTower;
  final ValueNotifier<bool>? language;
  final DeliveryBrand? initialBrand;
  final VoidCallback? onBack;
  final ValueChanged<DeliverySubmission>? onSubmit;
  final bool isSubmitting;

  @override
  State<RegisterDeliveryScreen> createState() => _RegisterDeliveryScreenState();
}

class _RegisterDeliveryScreenState extends State<RegisterDeliveryScreen> {
  final _courier = TextEditingController();
  final _brandsScroll = ScrollController();
  String? _tower;
  String? _flat;
  DeliveryBrand? _brand;
  DeliveryCategory? _category;

  @override
  void initState() {
    super.initState();
    _brand = widget.initialBrand;
    _category = _brand?.category;
  }

  @override
  void dispose() {
    _courier.dispose();
    _brandsScroll.dispose();
    super.dispose();
  }

  bool get _ready =>
      _tower != null &&
      _flat != null &&
      _brand != null &&
      _category != null &&
      (_brand != DeliveryBrand.other || _courier.text.trim().length >= 2);

  void _submit() {
    if (!_ready || widget.isSubmitting) return;
    FocusScope.of(context).unfocus();
    widget.onSubmit?.call(
      DeliverySubmission(
        tower: _tower!,
        flat: _flat!,
        brand: _brand!,
        category: _category!,
        courierName: _brand == DeliveryBrand.other
            ? _courier.text.trim()
            : null,
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
                padding: const EdgeInsets.fromLTRB(5, 6, 16, 5),
                child: GateHeader(
                  title: t('Delivery', 'डिलीवरी'),
                  language: notifier,
                  onBack: widget.onBack,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    const Divider(color: GateStyle.line, height: 15),
                    GateSection(
                      Icons.home_rounded,
                      t('Select Flat', 'फ़्लैट चुनें'),
                    ),
                    TowerFlatSelector(
                      flatsByTower: widget.flatsByTower,
                      language: notifier,
                      onSelectionChanged: (tower, flat) => setState(() {
                        _tower = tower;
                        _flat = flat;
                      }),
                    ),
                    const Divider(color: GateStyle.line, height: 30),
                    GateSection(
                      Icons.storefront,
                      t('From where', 'कहाँ से है'),
                    ),
                    SizedBox(
                      // Show three rows and a glimpse of the next row.
                      height: 256,
                      child: Scrollbar(
                        controller: _brandsScroll,
                        thumbVisibility: true,
                        child: GridView.builder(
                          controller: _brandsScroll,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                mainAxisExtent: 76,
                              ),
                          padding: EdgeInsets.zero,
                          itemCount: DeliveryBrand.values.length,
                          itemBuilder: (context, index) {
                            final brand = DeliveryBrand.values[index];
                            return _BrandBadge(
                              brand: brand,
                              label: brand == DeliveryBrand.other
                                  ? t('Other', 'अन्य')
                                  : brand.label,
                              selected: _brand == brand,
                              onTap: () {
                                if (brand != DeliveryBrand.other) {
                                  FocusScope.of(context).unfocus();
                                }
                                setState(() {
                                  _category = brand.category;
                                  _brand = brand;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.topCenter,
                        child: _brand == DeliveryBrand.other
                            ? Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: TextField(
                                  controller: _courier,
                                  maxLength: 80,
                                  onChanged: (_) => setState(() {}),
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.done,
                                  decoration: InputDecoration(
                                    labelText: t(
                                      'Courier name',
                                      'कूरियर का नाम',
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.local_shipping_outlined,
                                    ),
                                    counterText: '',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    const Divider(color: GateStyle.line, height: 28),
                    GateSection(
                      Icons.inventory_2_rounded,
                      t('What it is', 'क्या आया है'),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final category in DeliveryCategory.values)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: category == DeliveryCategory.other
                                    ? 0
                                    : 5,
                              ),
                              child: _categoryChip(category, hindi),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          footer: Padding(
            padding: const EdgeInsets.fromLTRB(13, 8, 13, 11),
            child: GateButton(
              label: t('Register and notify', 'दर्ज करें और सूचना दें'),
              icon: Icons.notifications_rounded,
              busy: widget.isSubmitting,
              onPressed: _ready && widget.onSubmit != null ? _submit : null,
            ),
          ),
        );
      },
    );
  }

  Widget _categoryChip(DeliveryCategory category, bool hindi) {
    final selected = _category == category;
    final color = selected ? Colors.white : GateStyle.ink;
    return GateTile(
      selected: selected,
      color: selected ? GateStyle.green : GateStyle.sand,
      onTap: () => setState(() => _category = category),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, size: 15.6, color: color),
              Text(
                gateText(hindi, category.english, category.hindi),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 10.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({
    required this.brand,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final DeliveryBrand brand;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  Widget _wordmark() {
    const heavy = TextStyle(
      fontSize: 21.2,
      fontWeight: FontWeight.w900,
      height: 1,
    );
    return switch (brand) {
      DeliveryBrand.blinkit => const Text.rich(
        TextSpan(
          text: 'blink',
          children: [
            TextSpan(
              text: 'it',
              style: TextStyle(color: Color(0xFF145338)),
            ),
          ],
        ),
        style: heavy,
      ),
      DeliveryBrand.zepto => Text(
        brand.mark,
        style: heavy.copyWith(color: const Color(0xFFFF7294)),
      ),
      DeliveryBrand.swiggy => Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.location_on, color: Colors.white, size: 37.7),
          Transform.translate(
            offset: const Offset(0, -2),
            child: Text(
              'S',
              style: heavy.copyWith(
                fontSize: 18.4,
                color: Color(brand.background),
              ),
            ),
          ),
        ],
      ),
      DeliveryBrand.zomato => Text(
        brand.mark,
        style: heavy.copyWith(color: Colors.white, fontStyle: FontStyle.italic),
      ),
      DeliveryBrand.amazon => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(brand.mark, style: heavy.copyWith(color: Colors.white)),
          ClipRect(
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 0.5,
              child: Container(
                width: 35,
                height: 12,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFFAE40), width: 2),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
      DeliveryBrand.flipkart => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            brand.mark,
            style: heavy.copyWith(
              color: Colors.white,
              fontSize: 18.4,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 3),
          const Icon(Icons.shopping_bag, color: Color(0xFFFFE664), size: 23),
        ],
      ),
      DeliveryBrand.bigBasket => const Text.rich(
        TextSpan(
          text: 'big',
          style: TextStyle(color: Color(0xFF9C1325)),
          children: [
            TextSpan(
              text: 'basket',
              style: TextStyle(color: GateStyle.ink),
            ),
          ],
        ),
        style: TextStyle(fontSize: 18.4, fontWeight: FontWeight.w800),
      ),
      DeliveryBrand.myntra => const Text.rich(
        TextSpan(
          text: 'M',
          style: TextStyle(
            color: Color(0xFFCA1858),
            fontStyle: FontStyle.italic,
          ),
        ),
        style: TextStyle(fontSize: 35, fontWeight: FontWeight.w900, height: 1),
      ),
      DeliveryBrand.other => Text(
        brand.mark,
        style: heavy.copyWith(fontSize: 29.4),
      ),
      _ => Text(brand.mark, style: heavy),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      button: true,
      selected: selected,
      onTap: onTap,
      child: GateTile(
        color: Color(brand.background),
        radius: 12,
        outlined: selected,
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 7, 6, 7),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _wordmark(),
                      ),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Color(brand.foreground),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Positioned(
                top: 4,
                right: 4,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 10,
                  child: Icon(
                    Icons.check_rounded,
                    size: 13.8,
                    color: GateStyle.green,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
