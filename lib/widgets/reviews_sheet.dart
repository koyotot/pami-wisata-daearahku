import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../data/review_state.dart';
import '../services/api_client.dart';

class ReviewsSheet extends StatefulWidget {
  final String? destinationGuid;
  final BusinessRepository? repository;
  const ReviewsSheet({super.key, this.destinationGuid, this.repository});

  @override
  State<ReviewsSheet> createState() => _ReviewsSheetState();
}

class _ReviewsSheetState extends State<ReviewsSheet> {
  late final _repository = widget.repository ?? BusinessRepository();
  final _reviews = RequestState<List<Review>>();

  @override
  void initState() {
    super.initState();
    _reviews.addListener(_changed);
    _repository.api.session.sessionChanges.addListener(_sessionChanged);
    _load();
  }

  void _load() => _reviews.load(() =>
      loadAllReviews(_repository, destinationGuid: widget.destinationGuid));

  void _changed() {
    if (mounted) setState(() {});
  }

  void _sessionChanged() {
    _reviews.reset();
    if (widget.destinationGuid != null ||
        _repository.api.session.authenticated.value) {
      _load();
    }
  }

  @override
  void dispose() {
    _repository.api.session.sessionChanges.removeListener(_sessionChanged);
    _reviews.removeListener(_changed);
    _reviews.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const text = Color(0xFF102D59);
    const muted = Color(0xFF728099);
    const border = Color(0xFFDCE4F0);
    final items = _reviews.data ?? const <Review>[];
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text(widget.destinationGuid == null ? 'Riwayat Ulasan' : 'Ulasan',
            style: const TextStyle(
                color: text, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Expanded(
          child: _reviews.loading
              ? const Center(child: CircularProgressIndicator())
              : _reviews.error != null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${_reviews.error}',
                          style: const TextStyle(color: muted)),
                      TextButton(
                          onPressed: _load, child: const Text('Coba lagi')),
                    ]))
                  : items.isEmpty
                      ? const Center(
                          child: Text('Belum ada ulasan.',
                              style: TextStyle(color: muted)))
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: border.withValues(alpha: 0.5)),
                          itemBuilder: (context, i) {
                            final review = items[i];
                            return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        const Icon(Icons.place_rounded,
                                            color: Color(0xFF1976D2), size: 14),
                                        const SizedBox(width: 4),
                                        Expanded(
                                            child: Text(review.destinationName,
                                                style: const TextStyle(
                                                    color: text,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13))),
                                        Row(
                                            children: List.generate(
                                                5,
                                                (s) => Icon(Icons.star_rounded,
                                                    size: 13,
                                                    color: s < review.rating
                                                        ? const Color(
                                                            0xFFFF9800)
                                                        : border))),
                                      ]),
                                      const SizedBox(height: 4),
                                      Text(review.comment,
                                          style: const TextStyle(
                                              color: muted,
                                              fontSize: 12.5,
                                              height: 1.4)),
                                    ]));
                          }),
        ),
      ]),
    );
  }
}
