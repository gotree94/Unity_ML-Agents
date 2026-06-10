# Session Backup — 2025-06-10

## 프로젝트 개요

- **프로젝트**: Unity-Robotics-ML (Unity 6000.0.40f1 + ROS2 Humble + ML-Agents)
- **로봇**: Niryo One (6-DOF manipulator + gripper)
- **목표**: ROS2 토픽 통신 + ML-Agents 기반 로봇암 제어
- **진행 단계**: Phase 0 (환경 설정) 완료, Phase 1 (ROS2+Unity TCP 통신) 구현 중
- **워크스페이스**: `C:\Unity_ML-Agents\Unity-Robotics-ML\`

---

## 설치된 패키지

| 패키지 | 버전/소스 |
|--------|-----------|
| com.unity.ml-agents | v4.0.0 (로컬: `ml-agents/com.unity.ml-agents`) |
| com.unity.robotics.ros-tcp-connector | GitHub (git UPM) |
| com.unity.robotics.urdf-importer | GitHub (git UPM) |
| com.unity.toolchain.win-x86_64-linux-x86_64 | 2.0.11 |

---

## 프로젝트 구조

```
Unity-Robotics-ML/
├── Assets/
│   ├── Resources/
│   │   ├── GeometryCompassSettings.asset
│   │   └── ROSConnectionPrefab.prefab
│   ├── Scripts/
│   │   └── RobotArm/
│   │       └── JointController.cs         ← 메인 제어 스크립트 (346 lines)
│   ├── URDF/
│   │   └── niryo_one/
│   │       ├── niryo_one.urdf             ← URDF 모델 파일
│   │       ├── Materials/
│   │       └── niryo_one_urdf/            ← URDF-Importer 생성 에셋
│   │           ├── Gripper1/              ← 그리퍼 메시/프리팹
│   │           └── meshes/                ← collada/ + stl/ 메시
│   └── ... (기본 모듈)
├── Packages/
│   └── manifest.json
├── docs/
│   ├── 00_환경_설정_및_프로젝트_생성.md
│   ├── 01_ROS2_설치.md
│   └── download_meshes.ps1
├── docs_plan/
└── README.md
```

---

## URDF 조인트 계층 구조 (Niryo One)

```
world (fixed)
└── base_link
    └── joint_1 (revolute, Z-axis, -3.05 ~ +3.05 rad)  → shoulder_link
        └── joint_2 (revolute, Z-axis, -1.92 ~ +0.64 rad)  → arm_link
            └── joint_3 (revolute, Z-axis, -1.40 ~ +1.57 rad)  → elbow_link
                └── joint_4 (revolute, Z-axis, -3.05 ~ +3.05 rad)  → forearm_link
                    └── joint_5 (revolute, Z-axis, -1.75 ~ +1.92 rad)  → wrist_link
                        └── joint_6 (revolute, Z-axis, -2.57 ~ +2.57 rad)  → hand_link
                            └── hand_tool_joint (fixed) → tool_link
                                └── hand_tool_joint (fixed) → gripper_base
                                    ├── servo_head_joint (fixed) → servo_head
                                    │   ├── control_rod_left (fixed) → control_rod_left
                                    │   │   └── gripper_joint_left (prismatic, -0.026 ~ +0.026 m) → left_gripper
                                    │   └── control_rod_right (fixed) → control_rod_right
                                    │       └── gripper_joint_right (prismatic, mimic left * -1) → right_gripper
                                    └── [gripper fingers]
```

### 키 포인트
- **6개 revolute joint** (joint_1 ~ joint_6): 모든 축이 robot의 로컬 Z-axis 기준
- **2개 prismatic joint** (gripper_joint_left, gripper_joint_right): gripper_joint_right는 mimic joint로 left의 -1배
- **모든 joint는 URDF-Importer에 의해 ArticulationBody로 변환됨**
- **GameObject 이름 = link 이름** (예: `shoulder_link`, `arm_link` 등)
- URDF-Importer가 생성하는 오브젝트 이름은 링크 이름을 따름

---

## JointController.cs (v1.0) — 전체 구조

### 파일: `Assets/Scripts/RobotArm/JointController.cs` (346 lines)

### 역할
- Niryo One 6-DOF + 그리퍼를 위한 ROS2 joint state publisher + command subscriber
- URDF-Importer가 생성한 ArticulationBody 계층을 자동 탐색
- FKRobot 컴포넌트 비활성화 (ROS-TCP 방식과 충돌 방지)

### Public Members

| 멤버 | 타입 | 설명 |
|------|------|------|
| `SetJointTargets(double[])` | method | 외부(Ml-Agents 등)에서 목표 위치 설정 |

### Serialized Fields (Inspector 노출)

| 필드 | 기본값 | 설명 |
|------|--------|------|
| `m_JointStateTopic` | `/joint_states` | publish topic |
| `m_JointCommandTopic` | `/joint_commands` | subscribe topic |
| `m_PublishRateHz` | 30f | publish frequency |
| `m_DriveStiffness` | 10000f | ArticulationDrive stiffness |
| `m_DriveDamping` | 100f | ArticulationDrive damping |
| `m_RobotRoot` | null (→ self) | 로봇 루트 GameObject |

### 내부 클래스: `ControllableJoint`

| 멤버 | 설명 |
|------|------|
| `Name` | joint 식별자 (= GameObject.name, 즉 link 이름) |
| `Body` | ArticulationBody 참조 |
| `IsPrismatic` | prismatic 여부 (false = revolute) |
| `GetPosition()` | `body.jointPosition[0]` (rad 또는 m) |
| `GetVelocity()` | `body.jointVelocity[0]` |
| `GetEffort()` | `body.jointForce[0]` |
| `SetTarget()` | Drive target 설정. **Revolute: rad→deg 변환, Prismatic: m 직접 사용** |

### 생명주기

1. **Awake()**
   - Robot root 검증
   - `DiscoverJoints()` — 모든 자식 ArticulationBody 중 Revolute/Prismatic 수집
   - FKRobot 컴포넌트 비활성화

2. **Start()**
   - 조인트 배열 초기화 (names/positions/velocities/efforts/targets)
   - ROSConnection 생성
   - `/joint_states` publisher 등록
   - `/joint_commands` subscriber 등록 (`OnJointCommand`)
   - 2초 후 `TestDirectDrive()` 호출 (shoulder_link 0.5rad)

3. **Update()**
   - `ReadJointStates()` — 실제 joint position/velocity/effort 읽기
   - Publish interval 체크 → `PublishJointStates()`
   - 명령 수신 시 `ApplyTargets()` — 모든 joint에 drive target 적용

### 데이터 흐름

```
ROS (Python)                     Unity (C#)
━━━━━━━━━━━                     ━━━━━━━━━━━
                                    │
     ┌─ /joint_commands ◄───────────┤ Subscribe (OnJointCommand)
     │                              │   → m_TargetPositions[] 갱신
     │                              │
     │                    Update()  │   ReadJointStates()
     │                              │   → m_Positions[] / m_Velocities[] / m_Efforts[]
     │                              │
     └─ ► /joint_states ───────────┤ Publish (30Hz)
                                    │
                              ArticulationBody.drive.target 적용
```

### 주요 로직 상세

#### `DiscoverJoints()`
```csharp
모든 GetComponentsInChildren<ArticulationBody>() 순회:
  - FixedJoint → skip (base_link 등)
  - RevoluteJoint 또는 PrismaticJoint만 수집
  - InitializeDrive() 호출 (stiffness/damping 설정)
  - ControllableJoint 리스트에 추가
```

#### `SetTarget()` (ControllableJoint)
```csharp
drive.target = IsPrismatic
  ? targetRadiansOrMeters          // prismatic: meters 그대로
  : targetRadiansOrMeters * Rad2Deg; // revolute: rad → deg 변환
```

### 변경 이력 (이 세션)

| 변경 | 설명 |
|------|------|
| ControllableJoint 클래스 도입 | Name, Body, IsPrismatic 캡슐화 |
| SetTarget()에 rad↔deg 변환 추가 | ArticulationBody는 degrees 사용, ROS는 radians |
| Prismatic drive damping 감소 | prismatic일 때 damping 10%로 낮춤 |
| TestDirectDrive() 추가 | Start 2초 후 shoulder_link 0.5rad 테스트 |
| OnJointCommand 로깅 개선 | 수신된 joint 이름과 위치 로깅 |
| InitializeDrive() 분리 | joint 초기화 로직 정리 |
| FKRobot 비활성화 | URDF-Importer 기본 제어와 충돌 방지 |
| m_RobotRoot 필드 추가 | Inspector에서 루트 오브젝트 지정 가능 |
| PublishJointState()에 frame_id="base_link" 추가 | ROS 표준 준수 |

---

## 현재 Debug 상태

| 항목 | 상태 |
|------|------|
| `DiscoverJoints()` ArticulationBody 자동 탐색 | ✅ 로직 완료 |
| `/joint_states` publish (30Hz) | ✅ 구현 |
| `/joint_commands` subscribe | ✅ 구현 |
| rad↔deg 변환 | ✅ 구현 |
| Prismatic gripper 지원 | ✅ 구현 |
| FKRobot 충돌 방지 | ✅ 구현 |
| TestDirectDrive (shoulder 0.5rad) | ✅ 구현 |
| **실제 Unity 씬에서의 검증** | ❌ 미수행 (씬 없음) |
| **ROS2와의 실제 통신 테스트** | ❌ 미수행 |
| **ML-Agents 통합** | ❌ 미구현 |

---

## 다음 단계 (To-Do)

1. **Phase 1: Unity ↔ ROS2 통신 테스트**
   - Unity 씬 생성 (Niryo One 배치)
   - JointController를 로봇 root에 연결
   - ROS2 Humble TCP-Endpoint 실행
   - `/joint_states` 수신 확인 (`ros2 topic echo /joint_states`)
   - `/joint_commands` 전송 테스트 (`ros2 topic pub`)

2. **Phase 2: Pick-and-Place**
   - IK 서비스 연동 (`/compute_ik`)
   - 물리 시뮬레이션 및 충돌 감지

3. **Phase 3: ML-Agents 통합**
   - DecisionRequester + Agent 스크립트
   - JointController.SetJointTargets() 호출

---

## 참고 사항

- Niryo One URDF의 gripper_joint_right는 `<mimic joint="gripper_joint_left" multiplier="-1"/>` — URDF-Importer가 mimic을 ArticulationBody로 변환하는지 확인 필요
- 모든 revolute joint 축이 로컬 Z축 기준이므로 URDF-Importer 변환 시 축 정합성 확인 필요
- ROS-TCP-Connector는 `ROSConnection.GetOrCreateInstance()`로 싱글톤 사용
