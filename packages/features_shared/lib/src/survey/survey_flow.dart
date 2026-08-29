import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'survey_draft.dart';
import 'survey_public_models.dart';

String _t(String locale, String vi, String en) => locale == 'en' ? en : vi;

final _vnDate = DateFormat('dd/MM/yyyy');

const _emojiIcons = [
  Icons.sentiment_very_dissatisfied,
  Icons.sentiment_dissatisfied,
  Icons.sentiment_neutral,
  Icons.sentiment_satisfied,
  Icons.sentiment_very_satisfied,
];

const _emojiLabelsVi = ['Chưa hài lòng', 'Tạm được', 'Bình thường', 'Hài lòng', 'Tuyệt vời'];
const _emojiLabelsEn = ['Not satisfied', 'Okay', 'Neutral', 'Satisfied', 'Excellent'];

/// One step of the flow: the branch picker, a single question, or a group of
/// consecutive RATING questions.
class _Step {
  const _Step.store()
      : isStore = true,
        questions = const [];
  const _Step.questions(this.questions) : isStore = false;
  final bool isStore;
  final List<SurveyQuestionView> questions;
}

/// The guest survey flow — served on the CUSTOMER domain and also embedded
/// as the internal editor's mobile preview (`preview: true` disables the
/// real submit), so what admins preview IS what guests get.
class SurveyFlow extends StatefulWidget {
  const SurveyFlow({
    required this.template,
    required this.stores,
    required this.onSubmit,
    super.key,
    this.reward,
    this.initialDraft,
    this.onDraftChanged,
    this.preview = false,
  });

  final SurveyTemplateView template;
  final List<SurveyStoreRef> stores;
  final SurveyRewardTeaser? reward;
  final SurveyDraft? initialDraft;
  final void Function(SurveyDraft draft)? onDraftChanged;
  final bool preview;

  /// Returns the submit result, or a failure with a guest-safe message.
  final Future<Result<SurveySubmitResult, AppFailure>> Function(SurveyDraft draft) onSubmit;

  @override
  State<SurveyFlow> createState() => _SurveyFlowState();
}

class _SurveyFlowState extends State<SurveyFlow> {
  late SurveyDraft _draft;
  String get _locale => _draft.locale;
  String? _error;
  bool _busy = false;
  SurveySubmitResult? _done;
  final _scroll = ScrollController();
  final _errorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft ?? SurveyDraft();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _persist() => widget.onDraftChanged?.call(_draft);

  Map<String, int> get _numericByCode => _draft.numbers;

  List<SurveyQuestionView> get _visibleQuestions =>
      widget.template.questions.where((q) => q.visibleFor(_numericByCode)).toList();

  /// Store first, then one question per step — consecutive RATINGs grouped
  /// into one short block so the flow stays 45–60s.
  List<_Step> get _steps {
    final steps = <_Step>[const _Step.store()];
    var ratingRun = <SurveyQuestionView>[];
    void flush() {
      if (ratingRun.isNotEmpty) {
        steps.add(_Step.questions(List.of(ratingRun)));
        ratingRun = [];
      }
    }

    for (final q in _visibleQuestions) {
      if (q.type == 'RATING') {
        ratingRun.add(q);
      } else {
        flush();
        steps.add(_Step.questions([q]));
      }
    }
    flush();
    return steps;
  }

  bool _answered(SurveyQuestionView q) {
    if (q.type == 'TEXT') return (_draft.texts[q.code] ?? '').trim().isNotEmpty;
    if (q.type == 'SINGLE_CHOICE' || q.type == 'MULTI_CHOICE') {
      return (_draft.choices[q.code] ?? const []).isNotEmpty;
    }
    return _draft.numbers.containsKey(q.code);
  }

  void _showError(String message) {
    setState(() => _error = message);
    // The offending step is already on screen — bring its message into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _errorKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 200));
      }
    });
  }

  bool _validateStep(_Step step) {
    if (step.isStore) {
      if (_draft.storeId == null) {
        _showError(_t(_locale, 'Vui lòng chọn chi nhánh bạn đã ghé.',
            'Please pick the branch you visited.',),);
        return false;
      }
      return true;
    }
    for (final q in step.questions) {
      if (q.required && !_answered(q)) {
        _showError(_t(_locale, 'Vui lòng chọn câu trả lời để tiếp tục.',
            'Please answer to continue.',),);
        return false;
      }
      if (q.code == 'contact_request' && _draft.numbers[q.code] == 1) {
        if (!_draft.contactConsent) {
          _showError(_t(_locale, 'Tick đồng ý liên hệ, hoặc chọn "Không".',
              'Tick the consent box, or choose "No".',),);
          return false;
        }
        // "Please contact me" needs a callable number — mirrors the server
        // rule (SURVEY_CONTACT_PHONE_INVALID).
        final phone = _draft.contactPhone.replaceAll(RegExp(r'[\s.()-]'), '');
        if (!RegExp(r'^(\+84|0)\d{8,10}$').hasMatch(phone)) {
          _showError(_t(_locale,
              'Cần số điện thoại hợp lệ (vd 09xx xxx xxx) để Banan liên hệ.',
              'Please enter a valid phone number so Banan can reach you.',),);
          return false;
        }
      }
    }
    return true;
  }

  void _next() {
    final steps = _steps;
    if (!_validateStep(steps[_draft.step])) return;
    setState(() {
      _error = null;
      if (_draft.step < _steps.length - 1) {
        _draft.step += 1;
      }
    });
    _persist();
    _scroll.jumpTo(0);
    if (_draft.step >= _steps.length) _draft.step = _steps.length - 1;
  }

  void _back() {
    setState(() {
      _error = null;
      if (_draft.step > 0) _draft.step -= 1;
    });
    _persist();
  }

  Future<void> _submit() async {
    final steps = _steps;
    // Validate EVERY step; jump to the first broken one (auto focus/scroll).
    for (var i = 0; i < steps.length; i++) {
      if (!_validateStep(steps[i])) {
        setState(() => _draft.step = i);
        _persist();
        return;
      }
    }
    if (widget.preview) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(
            _t(_locale, 'Bản xem thử — không gửi thật.', 'Preview only — nothing was sent.'),
          ),
        ),);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await widget.onSubmit(_draft);
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      success: (r) => setState(() => _done = r),
      failure: (f) => _showError(_guestMessage(f)),
    );
  }

  /// Guests never see technical errors — everything maps to a friendly line.
  String _guestMessage(AppFailure f) => switch (f.code) {
        'SURVEY_STORE_NOT_FOUND' || 'SURVEY_TEMPLATE_INVALID' => _t(_locale,
            'Trang đã cũ — vui lòng tải lại và thử lại.', 'Please reload the page and try again.',),
        'SURVEY_CONTACT_PHONE_INVALID' => _t(_locale,
            'Số điện thoại chưa đúng — kiểm tra lại nhé.',
            'That phone number does not look right — please check it.',),
        'HTTP_429' => _t(_locale, 'Bạn thao tác hơi nhanh — chờ một chút rồi thử lại.',
            'A little too fast — please wait a moment and try again.',),
        _ => _t(_locale, 'Chưa gửi được — kiểm tra kết nối mạng rồi thử lại nhé.',
            'Could not send yet — please check your connection and try again.',),
      };

  @override
  Widget build(BuildContext context) {
    if (_done != null) return _ThankYouView(result: _done!, locale: _locale);
    final steps = _steps;
    if (_draft.step >= steps.length) _draft.step = steps.length - 1;
    final step = steps[_draft.step];
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Banan',
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: BananColors.primary, fontWeight: FontWeight.w700),
              ),
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'vi', label: Text('VI')),
                ButtonSegment(value: 'en', label: Text('EN')),
              ],
              selected: {_locale},
              showSelectedIcon: false,
              onSelectionChanged: (s) {
                setState(() => _draft.locale = s.first);
                _persist();
              },
            ),
          ],
        ),
        const SizedBox(height: BananSpacing.sm),
        LinearProgressIndicator(
          value: (_draft.step + 1) / steps.length,
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
        const SizedBox(height: BananSpacing.xs),
        Text(
          '${_draft.step + 1}/${steps.length}',
          style: theme.textTheme.labelSmall,
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: BananSpacing.md),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (step.isStore) _storeStep() else ...step.questions.map(_questionBlock),
                if (_error != null)
                  Padding(
                    key: _errorKey,
                    padding: const EdgeInsets.only(top: BananSpacing.md),
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: BananSpacing.md),
        Row(
          children: [
            if (_draft.step > 0)
              TextButton(
                onPressed: _busy ? null : _back,
                child: Text(_t(_locale, 'Quay lại', 'Back')),
              ),
            const Spacer(),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : (_draft.step == steps.length - 1 ? _submit : _next),
                child: _busy
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2),)
                    : Text(
                        _draft.step == steps.length - 1
                            ? _t(_locale, 'Gửi khảo sát', 'Send feedback')
                            : _t(_locale, 'Tiếp tục', 'Next'),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _storeStep() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _t(_locale, 'Bạn đang trải nghiệm tại chi nhánh nào?',
              'Which branch are you visiting?',),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: BananSpacing.md),
        // Deliberately NO preselection — a wrong default would poison the
        // per-branch reports.
        for (final s in widget.stores)
          Padding(
            padding: const EdgeInsets.only(bottom: BananSpacing.sm),
            child: Material(
              color: _draft.storeId == s.id
                  ? BananColors.primary.withValues(alpha: 0.08)
                  : theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BananRadii.rmd,
                side: BorderSide(
                  color: _draft.storeId == s.id ? BananColors.primary : theme.dividerColor,
                ),
              ),
              child: InkWell(
                borderRadius: BananRadii.rmd,
                onTap: () {
                  setState(() {
                    _draft.storeId = s.id;
                    _error = null;
                  });
                  _persist();
                },
                child: Padding(
                  padding: const EdgeInsets.all(BananSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        _draft.storeId == s.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: _draft.storeId == s.id ? BananColors.primary : theme.hintColor,
                      ),
                      const SizedBox(width: BananSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: theme.textTheme.titleSmall),
                            if (s.address != null)
                              Text(s.address!, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _questionBlock(SurveyQuestionView q) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(q.text(_locale), style: theme.textTheme.titleMedium),
          if (!q.required)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _t(_locale, 'Không bắt buộc', 'Optional'),
                style: theme.textTheme.labelSmall,
              ),
            ),
          const SizedBox(height: BananSpacing.md),
          switch (q.type) {
            'EMOJI_SCALE' => _emojiInput(q),
            'RATING' => _ratingInput(q),
            'NPS' => _npsInput(q),
            'SINGLE_CHOICE' || 'MULTI_CHOICE' => _choiceInput(q),
            'TEXT' => _textInput(q),
            'YES_NO' => _yesNoInput(q),
            _ => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }

  void _setNumber(SurveyQuestionView q, int? value) {
    setState(() {
      _error = null;
      if (value == null) {
        _draft.numbers.remove(q.code);
      } else {
        _draft.numbers[q.code] = value;
      }
      // Prune answers to questions that just became hidden — the server
      // rejects them, and stale picks must not resurface later.
      final visible = _visibleQuestions.map((v) => v.code).toSet();
      _draft.numbers.removeWhere((code, _) => !visible.contains(code));
      _draft.choices.removeWhere((code, _) => !visible.contains(code));
      _draft.texts.removeWhere((code, _) => !visible.contains(code));
    });
    _persist();
  }

  Widget _emojiInput(SurveyQuestionView q) {
    final labels = _locale == 'en' ? _emojiLabelsEn : _emojiLabelsVi;
    final selected = _draft.numbers[q.code];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 1; i <= 5; i++)
          Expanded(
            child: Semantics(
              button: true,
              label: labels[i - 1],
              child: InkWell(
                borderRadius: BorderRadius.circular(BananSpacing.sm),
                onTap: () => _setNumber(q, i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: BananSpacing.sm),
                  child: Column(
                    children: [
                      Icon(
                        _emojiIcons[i - 1],
                        size: 44,
                        color: selected == i
                            ? BananColors.primary
                            : Theme.of(context).hintColor.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[i - 1],
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: selected == i ? BananColors.primary : null,
                              fontWeight: selected == i ? FontWeight.w700 : null,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _ratingInput(SurveyQuestionView q) {
    final selected = _draft.numbers[q.code];
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          Semantics(
            button: true,
            label: '$i/5',
            child: IconButton(
              iconSize: 34,
              onPressed: () => _setNumber(q, selected == i ? null : i),
              icon: Icon(
                selected != null && i <= selected ? Icons.star : Icons.star_border,
                color: selected != null && i <= selected
                    ? const Color(0xFFE5A33D)
                    : Theme.of(context).hintColor,
              ),
            ),
          ),
        if (selected != null)
          Text('$selected/5', style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }

  Widget _npsInput(SurveyQuestionView q) {
    final selected = _draft.numbers[q.code];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: BananSpacing.xs,
          runSpacing: BananSpacing.xs,
          children: [
            for (var i = 0; i <= 10; i++)
              ChoiceChip(
                label: SizedBox(
                  width: 20,
                  child: Text('$i', textAlign: TextAlign.center),
                ),
                selected: selected == i,
                onSelected: (_) => _setNumber(q, selected == i ? null : i),
              ),
          ],
        ),
        const SizedBox(height: BananSpacing.xs),
        Row(
          children: [
            Flexible(
              child: Text(_t(_locale, 'Không giới thiệu', 'Not likely'),
                  style: Theme.of(context).textTheme.labelSmall,),
            ),
            const Spacer(),
            Flexible(
              child: Text(_t(_locale, 'Chắc chắn giới thiệu', 'Very likely'),
                  style: Theme.of(context).textTheme.labelSmall,
                  textAlign: TextAlign.right,),
            ),
          ],
        ),
      ],
    );
  }

  Widget _choiceInput(SurveyQuestionView q) {
    final picked = _draft.choices[q.code] ?? const <String>[];
    return Wrap(
      spacing: BananSpacing.sm,
      runSpacing: BananSpacing.sm,
      children: [
        for (final o in q.options)
          FilterChip(
            label: Text(o.label(_locale)),
            selected: picked.contains(o.value),
            onSelected: (sel) {
              setState(() {
                _error = null;
                final next = List<String>.of(picked);
                if (q.type == 'SINGLE_CHOICE') {
                  next
                    ..clear()
                    ..add(o.value);
                  if (!sel) next.clear();
                } else if (sel) {
                  next.add(o.value);
                } else {
                  next.remove(o.value);
                }
                if (next.isEmpty) {
                  _draft.choices.remove(q.code);
                } else {
                  _draft.choices[q.code] = next;
                }
              });
              _persist();
            },
          ),
      ],
    );
  }

  Widget _textInput(SurveyQuestionView q) {
    return TextFormField(
      initialValue: _draft.texts[q.code],
      maxLength: q.maxLength ?? 1000,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: _t(_locale, 'Chia sẻ của bạn…', 'Your thoughts…'),
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        if (v.trim().isEmpty) {
          _draft.texts.remove(q.code);
        } else {
          _draft.texts[q.code] = v;
        }
        _persist();
      },
    );
  }

  Widget _yesNoButton(SurveyQuestionView q, int value, String label, int? selected) {
    return SizedBox(
      height: 48,
      child: selected == value
          ? FilledButton(onPressed: () => _setNumber(q, value), child: Text(label))
          : OutlinedButton(onPressed: () => _setNumber(q, value), child: Text(label)),
    );
  }

  Widget _yesNoInput(SurveyQuestionView q) {
    final selected = _draft.numbers[q.code];
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _yesNoButton(q, 1, _t(_locale, 'Có', 'Yes'), selected)),
            const SizedBox(width: BananSpacing.md),
            Expanded(child: _yesNoButton(q, 0, _t(_locale, 'Không', 'No'), selected)),
          ],
        ),
        // The contact block appears ONLY after an explicit "yes" — PII is
        // never requested otherwise.
        if (q.code == 'contact_request' && selected == 1) ...[
          const SizedBox(height: BananSpacing.lg),
          TextFormField(
            initialValue: _draft.contactName,
            decoration: InputDecoration(
              labelText: _t(_locale, 'Tên của bạn', 'Your name'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              _draft.contactName = v;
              _persist();
            },
          ),
          const SizedBox(height: BananSpacing.md),
          TextFormField(
            initialValue: _draft.contactPhone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d+ ]'))],
            decoration: InputDecoration(
              labelText: _t(_locale, 'Số điện thoại', 'Phone number'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              _draft.contactPhone = v;
              _persist();
            },
          ),
          const SizedBox(height: BananSpacing.sm),
          CheckboxListTile(
            value: _draft.contactConsent,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              _t(_locale, 'Tôi đồng ý để Banan liên hệ về góp ý này.',
                  'I agree that Banan may contact me about this feedback.',),
              style: theme.textTheme.bodySmall,
            ),
            onChanged: (v) {
              setState(() => _draft.contactConsent = v ?? false);
              _persist();
            },
          ),
        ],
      ],
    );
  }
}

class _ThankYouView extends StatelessWidget {
  const _ThankYouView({required this.result, required this.locale});
  final SurveySubmitResult result;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reward = result.reward;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: BananSpacing.xl),
          const Icon(Icons.check_circle_outline, size: 64, color: BananColors.primary),
          const SizedBox(height: BananSpacing.md),
          Text(
            _t(locale, 'Cảm ơn bạn đã chia sẻ!', 'Thank you for sharing!'),
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: BananSpacing.sm),
          Text(
            _t(locale, 'Góp ý của bạn giúp Banan phục vụ tốt hơn mỗi ngày.',
                'Your feedback helps Banan get better every day.',),
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          // The gift is revealed ONLY here — after a successful submit.
          if (reward != null) ...[
            const SizedBox(height: BananSpacing.xl),
            Container(
              padding: const EdgeInsets.all(BananSpacing.lg),
              decoration: BoxDecoration(
                color: BananColors.primary.withValues(alpha: 0.06),
                borderRadius: BananRadii.rmd,
                border: Border.all(color: BananColors.primary.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.card_giftcard, size: 40, color: BananColors.primary),
                  const SizedBox(height: BananSpacing.sm),
                  Text(reward.name, style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,),
                  if (reward.description != null)
                    Padding(
                      padding: const EdgeInsets.only(top: BananSpacing.xs),
                      child: Text(reward.description!, style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,),
                    ),
                  if (reward.voucherCode != null) ...[
                    const SizedBox(height: BananSpacing.md),
                    SelectableText(
                      reward.voucherCode!,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: Text(_t(locale, 'Sao chép mã', 'Copy code')),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: reward.voucherCode!));
                      },
                    ),
                  ],
                  if (reward.expiresAt != null)
                    Text(
                      _t(locale, 'Hạn dùng: ', 'Valid until: ') +
                          _vnDate.format(reward.expiresAt!.toLocal()),
                      style: theme.textTheme.labelSmall,
                    ),
                  if (reward.instructions != null)
                    Padding(
                      padding: const EdgeInsets.only(top: BananSpacing.sm),
                      child: Text(reward.instructions!, style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
