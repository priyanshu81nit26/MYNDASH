import 'package:flutter/material.dart';

import '../core/state.dart';
import '../engine/rating_catalog.dart';
import '../theme_district.dart';

Future<int?> pickBotRating(BuildContext context, String label,
    {Color accent = const Color(0xFF38BDF8)}) {
  final suggested = RatingCatalog.normalize(AppData.i.elo);
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: DC.bg2,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('BOT RATING · $label',
            style: Theme.of(sheetContext).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Choose the exact strength you want to face.',
            style: TextStyle(fontSize: 11, color: DC.dim)),
        const SizedBox(height: 14),
        SizedBox(
          height: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.55,
            ),
            itemCount: RatingCatalog.bands.length,
            itemBuilder: (_, index) {
              final rating = RatingCatalog.bands[index];
              final selected = rating == suggested;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.pop(sheetContext, rating),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(colors: [
                      accent.withOpacity(selected ? 0.28 : 0.16),
                      DC.violet.withOpacity(selected ? 0.18 : 0.08),
                    ]),
                    border: Border.all(color: selected ? DC.amber : DC.fg12),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$rating',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 15)),
                      if (selected)
                        Text('FOR YOU',
                            style: TextStyle(
                                color: DC.amber,
                                fontSize: 7,
                                fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    ),
  );
}
