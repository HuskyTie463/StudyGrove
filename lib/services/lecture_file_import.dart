import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'study_ai_client.dart';
import 'study_ai_settings.dart';

class LectureImportResult {
  const LectureImportResult({
    required this.filename,
    required this.text,
    required this.source,
    this.bytes,
    this.mediaType,
  });

  final String filename;
  final String text;
  final String source;
  final Uint8List? bytes;
  final String? mediaType;

  bool get isPdf => mediaType == 'application/pdf' && bytes != null;
}

/// Reads lecture files. PDFs stay as attachments for the model; other
/// types are turned into plain text for the notes field.
class LectureFileImport {
  const LectureFileImport();

  static const allowedExtensions = [
    'pdf',
    'txt',
    'md',
    'rtf',
    'csv',
    'docx',
    'pptx',
    'png',
    'jpg',
    'jpeg',
    'webp',
  ];

  Future<LectureImportResult> importBytes({
    required String filename,
    required Uint8List bytes,
  }) async {
    final ext = _ext(filename);
    switch (ext) {
      case 'txt':
      case 'md':
      case 'csv':
        return LectureImportResult(
          filename: filename,
          text: utf8.decode(bytes, allowMalformed: true).trim(),
          source: 'file',
        );
      case 'rtf':
        return LectureImportResult(
          filename: filename,
          text: _fromRtf(utf8.decode(bytes, allowMalformed: true)),
          source: 'file',
        );
      case 'docx':
        return LectureImportResult(
          filename: filename,
          text: _fromDocx(bytes),
          source: 'file',
        );
      case 'pptx':
        return LectureImportResult(
          filename: filename,
          text: _fromPptx(bytes),
          source: 'file',
        );
      case 'pdf':
        return _fromPdf(filename, bytes);
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
        return _fromImage(filename, ext, bytes);
      default:
        throw StudyAiException(
          '“$filename” is not a supported lecture file. Use PDF, Word, PowerPoint, text, or an image.',
        );
    }
  }

  Future<LectureImportResult> importPath(String path) async {
    if (FileSystemEntity.isDirectorySync(path)) {
      throw StudyAiException('Drop a file, not a folder.');
    }
    final file = File(path);
    if (!file.existsSync()) {
      throw StudyAiException('Could not open that file.');
    }
    final name = path.split(RegExp(r'[\\/]')).last;
    return importBytes(filename: name, bytes: await file.readAsBytes());
  }

  /// Local text pull for storing the lecture / OpenAI fallback. Does not
  /// belong in the paste-notes field.
  static String extractPdfText(List<int> bytes) {
    try {
      final doc = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(doc).extractText().trim();
      doc.dispose();
      return text;
    } catch (_) {
      return '';
    }
  }

  Future<LectureImportResult> _fromPdf(String filename, Uint8List bytes) async {
    return LectureImportResult(
      filename: filename,
      text: '',
      source: 'pdf',
      bytes: bytes,
      mediaType: 'application/pdf',
    );
  }

  Future<LectureImportResult> _fromImage(
    String filename,
    String ext,
    Uint8List bytes,
  ) async {
    if (!studyAiSettings.hasKey) {
      throw StudyAiException(
        'Images need an API key so the lecture can be read. Add one in Settings, or paste the text.',
      );
    }
    final media = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final ai = await StudyAiClient.instance.transcribeFile(
      bytes: bytes,
      filename: filename,
      mediaType: media,
    );
    return LectureImportResult(
      filename: filename,
      text: ai.trim(),
      source: 'ai',
    );
  }

  String _fromDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final file = archive.findFile('word/document.xml');
    if (file == null) {
      throw StudyAiException('That Word file has no readable document.xml.');
    }
    return _stripXml(utf8.decode(file.content, allowMalformed: true));
  }

  String _fromPptx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final slides = archive.files
        .where((f) =>
            f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (slides.isEmpty) {
      throw StudyAiException('That PowerPoint file has no readable slides.');
    }
    final buf = StringBuffer();
    for (var i = 0; i < slides.length; i++) {
      final text = _stripXml(
        utf8.decode(slides[i].content, allowMalformed: true),
      );
      if (text.isEmpty) continue;
      buf.writeln('Slide ${i + 1}');
      buf.writeln(text);
      buf.writeln();
    }
    return buf.toString().trim();
  }

  String _fromRtf(String raw) {
    return raw
        .replaceAll(RegExp(r'\\[a-z]+\d* ?'), ' ')
        .replaceAll(RegExp(r'[{}]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _stripXml(String xml) {
    return xml
        .replaceAll(RegExp(r'</w:p>'), '\n')
        .replaceAll(RegExp(r'</a:p>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _ext(String filename) {
    final i = filename.lastIndexOf('.');
    if (i < 0) return '';
    return filename.substring(i + 1).toLowerCase();
  }
}
