import 'package:flutter/material.dart';
import 'app_image.dart';
import '../models/court.dart' show formatLkr;
import '../models/court_listing.dart';
import '../theme/app_colors.dart';
import 'primary_button.dart';

class CourtListingCard extends StatefulWidget {
  final CourtListing listing;
  final VoidCallback onOpen;
  final void Function(SlotOffer? slot) onBook;
  const CourtListingCard(
      {super.key,
      required this.listing,
      required this.onOpen,
      required this.onBook});

  @override
  State<CourtListingCard> createState() => _CourtListingCardState();
}

class _CourtListingCardState extends State<CourtListingCard> {
  bool _fav = false;
  int? _slot;

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: AppColors.textDark.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.onOpen,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 170,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(l.imageAsset),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Wrap(
                        spacing: 6,
                        children: [
                          if (l.topPick)
                            _tag('TOP PICK', AppColors.primary, Colors.white,
                                icon: Icons.verified),
                          if (l.instantLock)
                            _tag('INSTANT LOCK',
                                Colors.white.withValues(alpha: 0.94),
                                AppColors.textDark),
                          if (l.tag != null)
                            _tag(l.tag!, Colors.white.withValues(alpha: 0.94),
                                AppColors.primary),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: GestureDetector(
                        onTap: () => setState(() => _fav = !_fav),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              shape: BoxShape.circle),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                                _fav ? Icons.favorite : Icons.favorite_border,
                                key: ValueKey(_fav),
                                size: 20,
                                color: _fav
                                    ? AppColors.danger
                                    : AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: _tag('', Colors.white.withValues(alpha: 0.94),
                          AppColors.textDark,
                          custom: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star,
                                  size: 16, color: AppColors.warning),
                              const SizedBox(width: 4),
                              Text('${l.rating}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                              Text(' (${l.reviews} reviews)',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          )),
                    ),
                    if (l.certified != null)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: _tag(l.certified!,
                            Colors.white.withValues(alpha: 0.94),
                            AppColors.primary),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: widget.onOpen,
            child: Text(l.name,
                style: const TextStyle(
                    fontSize: 21, height: 1.2, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '${l.distanceKm} km',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(
                      text: '  •  ${l.area}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ])),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in l.amenities)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(a.icon, size: 15, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(a.label,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          l.featuredSlots ? _featuredSlots(l) : _openSlots(l),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('STANDARD RATE',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppColors.textSecondary)),
                    Text.rich(TextSpan(
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800),
                      children: [
                        TextSpan(text: 'LKR ${formatLkr(l.rate)}'),
                        const TextSpan(
                            text: ' /hr',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary)),
                      ],
                    )),
                  ],
                ),
              ),
              SizedBox(
                width: 150,
                child: PrimaryButton(
                    label: 'Book Slot',
                    icon: Icons.arrow_forward,
                    onPressed: () => widget.onBook(
                        _slot == null ? null : l.slots[_slot!])),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featuredSlots(CourtListing l) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule, size: 18, color: AppColors.primary),
              SizedBox(width: 6),
              Expanded(
                child: Text("TONIGHT'S AVAILABLE SLOTS",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.textSecondary)),
              ),
              Text('Fast Reserve',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < l.slots.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _slot = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _slot == i ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Text(l.slots[i].time,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _slot == i
                                      ? Colors.white
                                      : AppColors.textDark)),
                          Text('LKR ${formatLkr(l.slots[i].price)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _slot == i
                                      ? Colors.white70
                                      : AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _openSlots(CourtListing l) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, right: 10),
            child: Text('OPEN SLOTS:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary)),
          ),
          Expanded(
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: l.slots.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final on = _slot == i;
                  return GestureDetector(
                    onTap: () => setState(() => _slot = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: on ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(14)),
                      child: Text(
                          '${l.slots[i].time} (LKR ${formatLkr(l.slots[i].price)})',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: on ? Colors.white : AppColors.textDark)),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg,
      {IconData? icon, Widget? custom}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: custom ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 4),
              ],
              Text(text,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: fg)),
            ],
          ),
    );
  }
}
