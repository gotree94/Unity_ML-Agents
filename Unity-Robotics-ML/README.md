# Unity Robotics + ML-Agents 통합 프로젝트

Unity 6000.0.40f1 + ROS2 Humble + ML-Agents 기반의 로봇암 및 터틀봇 시뮬레이션 프로젝트.

## 프로젝트 구조

```
Unity-Robotics-ML/
├── Assets/
│   ├── Scenes/          # Unity 씬 파일
│   ├── Scripts/         # C# 스크립트
│   ├── URDF/            # 로봇 URDF 모델
│   └── Configs/         # 설정 파일
├── Packages/
│   └── manifest.json    # 패키지 의존성
├── docs/
│   ├── 00_환경_설정_및_프로젝트_생성.md
│   ├── 01_ROS2_설치.md
│   ├── 02_Unity_ROS_통신.md
│   ├── 03_로봇암_PickAndPlace.md
│   ├── 04_로봇암_ML-Agents.md
│   ├── 05_터틀봇_시뮬레이션.md
│   ├── 06_터틀봇_ML-Agents.md
│   ├── 07_실제_로봇_배포.md
│   └── 08_VLA_연동.md
└── README.md
```

## 설치된 패키지

| 패키지 | 버전 | 출처 |
|--------|------|------|
| com.unity.ml-agents | v4.0.0 | 로컬 (ml-agents/com.unity.ml-agents) |
| com.unity.robotics.ros-tcp-connector | 최신 | GitHub (git UPM) |
| com.unity.robotics.urdf-importer | 최신 | GitHub (git UPM) |

## 단계별 진행

| Phase | 내용 | 상태 |
|-------|------|------|
| 0 | 환경 설정 및 프로젝트 생성 | ✅ 완료 |
| 1 | ROS2 + Unity TCP 통신 | ⬜ 대기 |
| 2 | 로봇암 Pick-and-Place | ⬜ 대기 |
| 3 | 로봇암 ML-Agents IK 최적화 | ⬜ 대기 |
| 4 | 터틀봇 시뮬레이션 | ⬜ 대기 |
| 5 | 터틀봇 ML-Agents 경로 최적화 | ⬜ 대기 |
| 6 | 실제 터틀봇 배포 | ⬜ 대기 |
| 7 | VLA 연동 | ⬜ 대기 |
