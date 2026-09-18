# 제작 검증 기록

- 스크린샷: 한국어·영어·일본어 각각 8장. 원본 Android 화면과 해당 언어 헤드라인 사용. 3개 언어 전체 contact sheet 및 feature graphic 육안 확인.
- 문구: 앱 이름 ≤30자, 간단한 설명 ≤80자, 자세한 설명 ≤4000자 자동 검사. 실제 팀명·리그명 등 금지 콘텐츠 검색 결과 없음(조사 문서는 제외).
- 영상: Remotion 4.0.499, 실제 투구 녹화 + 실제 게임 캡처. 8장면, 7회 짧은 전환. 앱 화면을 임의로 늘이지 않음.
- 소스 타입 검사: npx tsc --noEmit 성공.
- 글꼴: WOFF FontFace 로딩 완료 뒤 root 등록. 기존 pinned 버전과 호환되지 않는 top-level await 제거. 수정 후 스크린샷 렌더 전체 성공.
- 음원: 기존 ALAC 파일을 PCM WAV로 변환해 렌더러 코덱 fallback 제거. 음원 mix의 NaN/Inf 0.
- 최종 MP4와 RGB PNG의 규격·길이·프레임·해시 자동 검사는 finalize-play-store.py가 수행하고 upload-manifest.json과 *-probe.json으로 남긴다.
- 기기 환경 복원 확인: 1080×2400, density 420, 격리 QA app locale []. 연결 기기는 emulator-5554 한 대.
- Play Console: 한국어 등록정보 read-only 확인. 외부 저장·업로드·게시 없음.

최종 결과: 6개 MP4 모두 30.000초, 900프레임, 30fps, H.264/AAC. PNG 30개 RGB 및 파일 용량 검사 통과. 한국어·영어·일본어의 가로/세로 장면별 contact sheet 확인 완료. 업로드 파일 및 문안 총 51개 검증.
