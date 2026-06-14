import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Optional cloud analysis only. Magnetometer data stays on-device until you
/// explicitly send a **[redacted] statistical summary** in the prompt.
///
/// Set API key at build time: `--dart-define=GEMINI_API_KEY=your_key`
/// If empty, [analyzeEnvironmentPattern] returns a deterministic local stub.
class GeminiAnalysisService {
  GeminiAnalysisService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const String _model = 'gemini-1.5-flash';

  /// Generates a short expert-style commentary from aggregated stats (not raw high-rate streams).
  Future<String> analyzeEnvironmentPattern(String structuredSummary) async {
    if (_apiKey.isEmpty) {
      return _offlineDummyReport(structuredSummary);
    }
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
    );
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text': '''
당신은 전자기 환경과 학습 집중도에 정통한 연구 보조 AI입니다.
아래는 사용자 기기에서 **요약된 통계**입니다(원시 센서 스트림 아님).
이 패턴이 집중에 미칠 수 있는 메커니즘을 균형 잡힌 톤으로 3~5문장 한국어로 설명하고,
실천 가능한 완화 행동 2가지를 제안하세요. 의학적 진단이나 단정은 피하세요.

데이터 요약:
$structuredSummary
''',
            },
          ],
        },
      ],
    });
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) {
        debugPrint('Gemini HTTP ${res.statusCode}: ${res.body}');
        return _offlineDummyReport(structuredSummary);
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final text = _extractGeminiText(map);
      if (text == null || text.trim().isEmpty) {
        return _offlineDummyReport(structuredSummary);
      }
      return text.trim();
    } catch (e, st) {
      debugPrint('Gemini call failed: $e\n$st');
      return _offlineDummyReport(structuredSummary);
    }
  }

  void close() => _client.close();

  static String? _extractGeminiText(Map<String, dynamic> map) {
    final candidates = map['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;
    final first = candidates.first;
    if (first is! Map<String, dynamic>) return null;
    final content = first['content'];
    if (content is! Map<String, dynamic>) return null;
    final parts = content['parts'];
    if (parts is! List<dynamic> || parts.isEmpty) return null;
    final part0 = parts.first;
    if (part0 is! Map<String, dynamic>) return null;
    return part0['text'] as String?;
  }

  String _offlineDummyReport(String structuredSummary) {
    return '[오프라인/데모 분석] 네트워크 또는 API 키가 없어 로컬 템플릿 리포트를 표시합니다.\n\n'
        '요약 입력 길이: ${structuredSummary.length}자\n\n'
        '• 자기장 변동이 크면 금속 주변 재배치를 검토하세요.\n'
        '• 장시간 동일 자세보다는 짧은 환경 재스캔이 신뢰도를 높입니다.';
  }
}
