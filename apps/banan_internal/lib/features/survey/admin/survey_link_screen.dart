import 'dart:ui' as ui;

import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

import '../../../shared/internal_shell.dart';
import '../../../shared/save_file.dart';
import '../../../shared/widgets.dart';

const _qrCaption = 'Quét để chia sẻ trải nghiệm';

/// ONE fixed public link for every table at every branch. Deliberately no
/// per-table/per-branch QR list and no rotation — printed QRs must never
/// die, and the guest picks the branch on the form itself.
class SurveyLinkScreen extends StatelessWidget {
  const SurveyLinkScreen({super.key});

  /// The canonical public URL — the CUSTOMER app domain, never this admin
  /// app's origin. Built from [Env.customerAppUrl] (trailing slashes
  /// trimmed), so prod QRs encode `https://banancakes.vn/survey`.
  static String surveyUrl({String? customerBase}) {
    final base = (customerBase ?? Env.customerAppUrl).replaceAll(RegExp(r'/+$'), '');
    return '$base/survey';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = surveyUrl();
    return InternalShell(
      title: 'Link & QR khảo sát',
      subtitle: 'Một link duy nhất cho mọi bàn, mọi chi nhánh',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BananSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(BananSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BananRadii.rmd,
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(url, style: theme.textTheme.titleSmall),
                      ),
                      IconButton(
                        tooltip: 'Sao chép link',
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: url));
                          if (context.mounted) showSnack(context, 'Đã sao chép link.');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: BananSpacing.lg),
                Center(child: SurveyQrPreview(url: url)),
                const SizedBox(height: BananSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Tải QR PNG'),
                        onPressed: () => _downloadPng(context, url),
                      ),
                    ),
                    const SizedBox(width: BananSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Tải PDF để in'),
                        onPressed: () => _downloadPdf(context, url),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: BananSpacing.lg),
                Text(
                  'In một mẫu QR này cho tất cả bàn và tất cả chi nhánh. Khách tự chọn '
                  'chi nhánh trong khảo sát, nên không cần QR riêng theo bàn hay chi nhánh '
                  '— và không đổi QR để mã đã in không bao giờ mất hiệu lực.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadPng(BuildContext context, String url) async {
    final bytes = await renderSurveyQrPng(url);
    saveBytesAsFile(bytes, 'banan-survey-qr.png', 'image/png');
    if (context.mounted) showSnack(context, 'Đã tải QR PNG.');
  }

  Future<void> _downloadPdf(BuildContext context, String url) async {
    final png = await renderSurveyQrPng(url);
    // All visible text is baked into the PNG (the PDF built-in fonts have no
    // Vietnamese glyphs) — the page is just the poster image, print-ready.
    final doc = pw.Document()
      ..addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          build: (context) => pw.Center(
            child: pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.contain),
          ),
        ),
      );
    final bytes = await doc.save();
    saveBytesAsFile(Uint8List.fromList(bytes), 'banan-survey-qr.pdf', 'application/pdf');
    if (context.mounted) showSnack(context, 'Đã tải PDF.');
  }
}

/// On-screen QR with the Banan wordmark in the middle (error correction H
/// leaves ~30% headroom for the overlay).
class SurveyQrPreview extends StatelessWidget {
  const SurveyQrPreview({required this.url, super.key});
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BananRadii.rmd,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              QrImageView(
                data: url,
                size: 220,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
                backgroundColor: Colors.white,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.white,
                child: const Text(
                  'Banan',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: BananColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.sm),
          Text(_qrCaption, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

/// Print-quality poster PNG: QR (with the wordmark overlay) + caption. Text
/// is rendered HERE so downstream formats never need Vietnamese PDF fonts.
Future<Uint8List> renderSurveyQrPng(String url) async {
  const qrSize = 900.0;
  const pad = 70.0;
  const captionSpace = 150.0;
  const width = qrSize + pad * 2;
  const height = qrSize + pad * 2 + captionSpace;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.white,
    );

  final painter = QrPainter(
    data: url,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.H,
    // ignore: avoid_redundant_argument_values
    gapless: true,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1A1A1A)),
    dataModuleStyle:
        const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1A1A1A)),
  );
  canvas
    ..save()
    ..translate(pad, pad);
  painter.paint(canvas, const Size(qrSize, qrSize));
  canvas.restore();

  // Wordmark overlay (H-level error correction absorbs it).
  final logo = TextPainter(
    text: const TextSpan(
      text: 'Banan',
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 64,
        color: BananColors.primary,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final logoBox = Rect.fromCenter(
    center: const Offset(width / 2, pad + qrSize / 2),
    width: logo.width + 48,
    height: logo.height + 24,
  );
  canvas.drawRect(logoBox, Paint()..color = Colors.white);
  logo.paint(
    canvas,
    Offset(width / 2 - logo.width / 2, pad + qrSize / 2 - logo.height / 2),
  );

  final caption = TextPainter(
    text: const TextSpan(
      text: _qrCaption,
      style: TextStyle(fontSize: 52, fontWeight: FontWeight.w600, color: Color(0xFF3B2A22)),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width - pad * 2);
  caption.paint(
    canvas,
    Offset((width - caption.width) / 2, qrSize + pad * 2 + (captionSpace - caption.height) / 2),
  );

  final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
