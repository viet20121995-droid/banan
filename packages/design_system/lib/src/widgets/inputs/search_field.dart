import 'dart:async';

import 'package:flutter/material.dart';

/// Debounced search field. [onChanged] fires once the user stops typing for
/// [debounce] (default 350ms). Pass a [controller] if you need external clear.
class SearchField extends StatefulWidget {
  const SearchField({
    required this.onChanged,
    this.hint = 'Search',
    this.controller,
    this.debounce = const Duration(milliseconds: 350),
    super.key,
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final TextEditingController? controller;
  final Duration debounce;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(value));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  _controller.clear();
                  _onChanged('');
                  widget.onChanged('');
                },
              ),
      ),
    );
  }
}
