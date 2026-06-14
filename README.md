# EMF Quantum Focus

스마트폰 자기장·가속도 센서를 이용해 학습 집중 환경을 측정·시각화하는 Flutter Android 앱입니다.

## 주요 기능

- **Focus Score** (0~100): EMF, 변동, 전력선 대역, 맵 완성도 등을 종합한 상대 지표
- **집중 세션**: 시작/종료, 누적 통계, 임계값 알림 (일반 60 / 도서관 63 / 민감 70)
- **AR EMF 스캔**: 카메라 + 실시간 EMF 오버레이
- **EMF 미니맵**: 책상 평면 히트맵
- **집중 구역 찾기**: 주변 스캔 후 Focus Score 최고 위치 탐색

## 기술 스택

- Flutter / Dart (Material 3)
- provider, sensors_plus, camera, shared_preferences
- 선택: Google Gemini API (요약 통계만, `--dart-define=GEMINI_API_KEY=`)

## 빌드 (Android APK)

```bash
flutter pub get
flutter build apk --release
```

출력: `build/app/outputs/flutter-apk/app-release.apk`

## 프로젝트 구조

- `lib/` — 앱 소스 (screens, providers, services, widgets, signal_processing)
- `test/` — 단위·위젯 테스트
- `android/` — Android 빌드 설정

## 참고

- 의료기기·공인 계측기가 아닌, 일상 환경 **상대 비교·습관 형성**용 앱입니다.
- 원시 센서 데이터는 기기 내 처리가 기본이며, Gemini는 설정 시 요약 통계만 전송합니다.

## 문서

- `docs/EMF_발표_최종.pptx` — 발표 자료
- `docs/EMF_Quantum_Focus_Presentation_Integrated.docx` — 발표 통합 원고 (Word)

## 버전

1.0.0+1
