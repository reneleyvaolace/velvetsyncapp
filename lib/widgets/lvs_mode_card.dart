import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:velvet_sync/theme.dart';

enum ModeCardType { game, companion, dice, roulette, reader, kegel }

class LvsModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String iconPath;
  final ModeCardType type;
  final VoidCallback onTap;
  final bool isLocked;
  final String? lockMessage;

  const LvsModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconPath,
    required this.type,
    required this.onTap,
    this.isLocked = false,
    this.lockMessage,
  });

  Color get _accentColor {
    switch (type) {
      case ModeCardType.companion:
        return LvsColors.amber;
      case ModeCardType.dice:
      case ModeCardType.roulette:
        return LvsColors.violet;
      case ModeCardType.reader:
        return LvsColors.teal;
      case ModeCardType.kegel:
        return const Color(0xFF00F5FF);
      case ModeCardType.game:
        return LvsColors.pink;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLocked
          ? () {
              HapticFeedback.heavyImpact();
              if (lockMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(lockMessage!),
                    backgroundColor: LvsColors.red.withOpacity(0.9),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          : () {
              HapticFeedback.lightImpact();
              onTap();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _accentColor.withOpacity(isLocked ? 0.05 : 0.15),
              LvsColors.bgCard.withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isLocked
                ? Colors.white.withOpacity(0.05)
                : _accentColor.withOpacity(0.4),
          ),
          boxShadow: isLocked
              ? null
              : [
                  BoxShadow(
                    color: _accentColor.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isLocked
                    ? Colors.white.withOpacity(0.05)
                    : _accentColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLocked ? Icons.lock_outline : Icons.play_arrow_rounded,
                color: isLocked ? LvsColors.text3 : _accentColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isLocked ? LvsColors.text3 : LvsColors.text1,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      if (isLocked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('BLOQUEADO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: LvsColors.text3, letterSpacing: 1)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLocked ? (lockMessage ?? 'Conecta un dispositivo para desbloquear') : subtitle,
                    style: TextStyle(
                      color: isLocked ? LvsColors.text3 : LvsColors.text2,
                      fontSize: 11,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isLocked)
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: _accentColor.withOpacity(0.6),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class LvsModeCardGrid extends StatelessWidget {
  final List<LvsModeCard> cards;
  final int crossAxisCount;

  const LvsModeCardGrid({
    super.key,
    required this.cards,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: cards,
    );
  }
}