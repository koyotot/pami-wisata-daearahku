// Project-standard "select": a field that opens a bottom-sheet option list
// (drag handle, title + close button, rounded rows, tinted selected row
// with a check), matching the country and destination pickers.
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

const _navy = Color(0xFF102D59);
const _blue = Color(0xFF1976D2);
const _tint = Color(0xFFE6F0FC);
const _muted = Color(0xFF728099);
const _dim = Color(0xFF9AA7BC);
const _border = Color(0xFFDCE4F0);

class SelectOption<T> {
  final T value;
  final String label;
  final String? description;
  const SelectOption(this.value, this.label, {this.description});
}

/// Shows the option sheet; resolves to the picked value, or null if closed.
Future<T?> showSelectSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<SelectOption<T>> options,
  T? selected,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SelectSheet<T>(
          title: title,
          subtitle: subtitle,
          options: options,
          selected: selected),
    );

class _SelectSheet<T> extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<SelectOption<T>> options;
  final T? selected;
  const _SelectSheet(
      {required this.title,
      this.subtitle,
      required this.options,
      this.selected});

  @override
  State<_SelectSheet<T>> createState() => _SelectSheetState<T>();
}

class _SelectSheetState<T> extends State<_SelectSheet<T>> {
  String _query = '';

  // Search only pays off on longer lists.
  bool get _searchable => widget.options.length > 8;

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final options = query.isEmpty
        ? widget.options
        : widget.options
            .where((o) => '${o.label} ${o.description ?? ''}'
                .toLowerCase()
                .contains(query))
            .toList();
    final searchBorder = OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom) *
                .75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                                color: _navy,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(widget.subtitle!,
                              style: const TextStyle(
                                  color: _muted, fontSize: 12.5)),
                        ],
                      ]),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF0F3F8),
                      foregroundColor: _muted),
                  icon: const Icon(PhosphorIconsRegular.x, size: 16),
                ),
              ]),
            ),
            if (_searchable)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: TextField(
                  style: const TextStyle(color: _navy, fontSize: 14),
                  decoration: InputDecoration(
                      hintText: 'Cari...',
                      hintStyle: const TextStyle(color: _dim, fontSize: 14),
                      prefixIcon: const Icon(
                          PhosphorIconsRegular.magnifyingGlass,
                          color: _muted,
                          size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF5F8FD),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: searchBorder,
                      enabledBorder: searchBorder,
                      focusedBorder: searchBorder.copyWith(
                          borderSide:
                              const BorderSide(color: _blue, width: 1.5))),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            const SizedBox(height: 12),
            Flexible(
              child: options.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Tidak ada pilihan yang cocok',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted)))
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final selected = option.value == widget.selected;
                        return Semantics(
                          selected: selected,
                          button: true,
                          child: Material(
                            color: selected ? _tint : Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                    color: selected ? _blue : _border,
                                    width: selected ? 1.3 : 1)),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => Navigator.pop(context, option.value),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(children: [
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(option.label,
                                              style: TextStyle(
                                                  color:
                                                      selected ? _blue : _navy,
                                                  fontSize: 14,
                                                  fontWeight: selected
                                                      ? FontWeight.w700
                                                      : FontWeight.w600)),
                                          if (option.description != null) ...[
                                            const SizedBox(height: 2),
                                            Text(option.description!,
                                                style: const TextStyle(
                                                    color: _muted,
                                                    fontSize: 12)),
                                          ],
                                        ]),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                      selected
                                          ? PhosphorIconsFill.checkCircle
                                          : PhosphorIconsRegular.circle,
                                      size: 20,
                                      color: selected ? _blue : _border),
                                ]),
                              ),
                            ),
                          ),
                        );
                      }),
            ),
          ],
        ),
      ),
    );
  }
}

/// Form field that looks like the project's inputs and opens [showSelectSheet].
/// [value] is owned by the caller; [validator] receives it on validate.
class SelectFormField<T> extends StatelessWidget {
  final T? value;
  final List<SelectOption<T>> options;
  final String sheetTitle;
  final String? sheetSubtitle;
  final String hint;
  final InputDecoration decoration;
  final bool enabled;
  final ValueChanged<T> onChanged;
  final String? Function(T?)? validator;
  const SelectFormField({
    super.key,
    required this.value,
    required this.options,
    required this.sheetTitle,
    this.sheetSubtitle,
    this.hint = 'Pilih',
    this.decoration = const InputDecoration(),
    this.enabled = true,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    String? label;
    for (final option in options) {
      if (option.value == value) label = option.label;
    }
    return FormField<T>(
      validator: validator == null ? null : (_) => validator!(value),
      builder: (field) {
        // The value can be restored from outside (e.g. a list reloaded);
        // clear a stale "required" error once it is valid again.
        if (field.hasError && validator != null && validator!(value) == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (field.mounted) field.validate();
          });
        }
        return Semantics(
          button: true,
          enabled: enabled,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: !enabled || options.isEmpty
                ? null
                : () async {
                    final picked = await showSelectSheet<T>(context,
                        title: sheetTitle,
                        subtitle: sheetSubtitle,
                        options: options,
                        selected: value);
                    if (picked == null || picked == value) return;
                    onChanged(picked);
                    field.didChange(picked);
                    // Re-check after the parent rebuilds with the new value so
                    // a "required" error clears straight away.
                    if (field.hasError) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (field.mounted) field.validate();
                      });
                    }
                  },
            child: InputDecorator(
              isEmpty: label == null,
              decoration: decoration.copyWith(
                hintText: hint,
                errorText: field.errorText,
                enabled: enabled,
                suffixIcon: const Icon(PhosphorIconsRegular.caretDown,
                    color: _muted, size: 18),
              ),
              child: Text(label ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _navy, fontSize: 14)),
            ),
          ),
        );
      },
    );
  }
}

/// Project-standard confirmation bottom sheet (drag handle, icon, title,
/// message, stacked buttons). Resolves to true when the destructive action is
/// confirmed; false when the user keeps going or dismisses the sheet.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  IconData icon = PhosphorIconsRegular.warning,
  Color confirmColor = const Color(0xFFE5484D),
  bool emphasizeConfirm = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: confirmColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: confirmColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: _navy,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(message,
                        style: const TextStyle(
                            color: _muted, fontSize: 13, height: 1.45)),
                  ]),
            ),
          ]),
          const SizedBox(height: 20),
          if (emphasizeConfirm) ...[
            _sheetFilled(confirmLabel, confirmColor,
                () => Navigator.pop(sheetContext, true)),
            const SizedBox(height: 10),
            _sheetOutlined(cancelLabel, _muted, _border,
                () => Navigator.pop(sheetContext, false)),
          ] else ...[
            _sheetFilled(
                cancelLabel, _blue, () => Navigator.pop(sheetContext, false)),
            const SizedBox(height: 10),
            _sheetOutlined(confirmLabel, confirmColor,
                confirmColor.withValues(alpha: .35),
                () => Navigator.pop(sheetContext, true)),
          ],
        ],
      ),
    ),
  );
  return result ?? false;
}

Widget _sheetFilled(String label, Color color, VoidCallback onPressed) =>
    FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      child: Text(label),
    );

Widget _sheetOutlined(
        String label, Color color, Color border, VoidCallback onPressed) =>
    OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      child: Text(label),
    );
