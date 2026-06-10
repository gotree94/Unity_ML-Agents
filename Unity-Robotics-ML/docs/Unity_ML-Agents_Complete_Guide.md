# Unity-Robotics-ML: 종합 진행 가이드

> Unity 6000.0.40f1 + ROS2 Humble + ML-Agents 기반 Niryo One 로봇암 프로젝트
> 마지막 업데이트: 2025-06-10

---

## 프로젝트 개요

| 항목 | 내용 |
|------|------|
| 로봇 | Niryo One (6-DOF manipulator + gripper) |
| Unity | 6000.0.40f1 |
| ROS2 | Humble Hawksbill (VirtualBox Ubuntu 22.04 VM) |
| ML-Agents | v4.0.0 |
| 통신 | ROS-TCP-Connector v0.7.0 (TCP 10000) |
| 호스트 OS | Windows 11 (AMD Ryzen 9 7940HS) |
| VM IP | 192.168.75.204 |

### 설치된 패키지

| 패키지 | 출처 |
|--------|------|
| `com.unity.ml-agents` | v4.0.0 (로컬) |
| `com.unity.robotics.ros-tcp-connector` | GitHub UPM |
| `com.unity.robotics.urdf-importer` | GitHub UPM |

---

## Phase 0: 환경 설정 ✅ 완료

- VirtualBox VM 생성 (Ubuntu 22.04 LTS)
- ROS2 Humble Desktop 설치
- Unity 6000.0.40f1 프로젝트 생성
- ROS-TCP-Connector / URDF-Importer UPM 설치
- ML-Agents v4.0.0 설치

**참고 문서:** `docs/00_환경_설정_및_프로젝트_생성.md`

---

## Phase 1: ROS2 + Unity 통신 및 Joint Controller ✅ 완료

### 1.1 URDF 임포트

Niryo One URDF (`niryo_one.urdf`)를 Unity URDF-Importer로 임포트.
- 6개 revolute joint (shoulder ~ hand)
- 2개 prismatic joint (gripper left/right, mimic 관계)
- 모든 GameObject명 = link 이름 (= joint 식별자)

### 1.2 JointController.cs 개발

**파일:** `Assets/Scripts/RobotArm/JointController.cs` (320 lines)

#### 구조

```
JointController (MonoBehaviour)
├── ControllableJoint (내부 클래스)
│   ├── Name          : link 이름 (= GameObject.name)
│   ├── Body          : ArticulationBody 참조
│   ├── IsPrismatic   : prismatic 여부
│   ├── GetPosition() : body.jointPosition[0]
│   ├── SetTarget()   : drive target 설정 (revolute: rad→deg)
│   └── ...
├── DiscoverJoints()  : 자식 ArticulationBody 중 Revolute/Prismatic 탐색 (8개)
├── InitializeDrive() : stiffness/damping/forceLimit 초기화
├── PublishJointStates() → /joint_states (30Hz)
├── OnJointCommand()  ← /joint_commands subscriber
└── ApplyTargets()    : 모든 joint에 drive target 적용
```

#### 생명주기

| 단계 | 동작 |
|------|------|
| `Awake()` | targetFrameRate=60, vSyncCount=0, DiscoverJoints(), URDF-Importer 컴포넌트 차단 |
| `Start()` | ROSConnection 생성, pub/sub 등록, InvokeRepeating(30Hz) |
| `FixedUpdate()` | ReadJointStates(), ApplyTargets() (명령 수신 시) |
| `PublishTick()` | PublishJointStates() (Timer 기반 30Hz) |

#### 통신 흐름

```
ROS2 VM                                    Unity
──────                                    ─────
                                              │
  ros2 topic pub /joint_commands ◄────────────┤ OnJointCommand()
  sensor_msgs/JointState                      │ → m_TargetPositions[] 갱신
                                              │
                                     FixedUpdate()
                                              │ → ApplyTargets()
                                              │ → SetTarget() on each ArticulationBody
                                              │ → drive.forceLimit=1000, stiffness=10000
                                              │
  ros2 topic echo /joint_states ◄────────────┤ PublishJointStates() @ 30Hz
```

### 1.3 해결된 문제

#### 문제 1: Editor FPS 저하로 publish 중단
- **증상:** Editor가 idle 상태일 때 FPS가 0에 수렴, InvokeRepeating/publish 중단
- **원인:** Unity Editor는 포커스 없을 때 targetFrameRate를 낮춤
- **해결:** `Application.targetFrameRate = 60` + `QualitySettings.vSyncCount = 0`

#### 문제 2: ArticulationBody drive가 움직이지 않음 (핵심 버그)
- **증상:** OnJointCommand callback까지 도달, SetTarget 실행됨, but arm不動
- **원인:** URDF-Importer의 `Controller.Start()`가 `forceLimit=0`을 설정
  ```csharp
  // Controller.cs (URDF-Importer 내장, Start()에서 실행)
  ArticulationDrive currentDrive = joint.xDrive;
  currentDrive.forceLimit = forceLimit;  // forceLimit 필드 = 0 (미초기화)
  joint.xDrive = currentDrive;
  ```
  forceLimit=0 → drive가 물리력을 전혀 낼 수 없음
- **해결:** `InitializeDrive()`와 `SetTarget()`에서 `drive.forceLimit = 1000f` 명시적 설정
- **추가 조치:** Controller / FKRobot / JointControl 컴포넌트 모두 비활성화 (Awake에서)

### 1.4 ROS ↔ Unity 통신 테스트 절차

```bash
# 1) VM에서 ROS-TCP-Endpoint 실행
ssh rosuser@192.168.75.204
source ~/ros2_ws/install/setup.bash
ros2 run ros_tcp_endpoint default_server_endpoint.py

# 2) Unity Play Mode 실행

# 3) Unity 자체 테스트 (2초 후 shoulder 1.5rad 자동 회전)

# 4) ROS에서 joint 명령 전송
ros2 topic pub /joint_commands sensor_msgs/JointState \
  "{header: {}, name: ['shoulder_link','arm_link','elbow_link'], \
    position: [1.0, -0.5, 0.8], velocity: [], effort: []}" --once

# 5) joint states 확인
ros2 topic echo /joint_states
```

---

## Phase 2: Pick-and-Place ⚙️ 진행 중

### 목표
- 물체 인식 및 그리핑
- IK (Inverse Kinematics) 서비스 연동
- `/compute_ik` 서비스 호출로 목표 자세 계산
- 충돌 감지 및 경로 계획

### 2.1 사전 정의 자세 시퀀스 (v1) ✅ 완료

**파일:** `Assets/Scripts/RobotArm/PickAndPlaceController.cs` (200 lines)

**동작 구조:**
```csharp
PickAndPlaceController (MonoBehaviour)
├── PoseStep (Serializable) ─── 1개 step당 6개 arm joint + 2개 gripper
├── List<PoseStep> m_Sequence ── 8단계 기본 시퀀스
├── Update() → 타이머 카운트 → 시간 초과 시 NextStep()
└── NextStep() → m_JointController.SetJointTargets(fullArray)
```

**기본 시퀀스 (8단계, ~13초):**
```
Home (1s) → Pre-grasp (2s) → Grasp (2s) → Close (1s) → Lift (2s) → Place (2s) → Release (1s) → Return (2s)
```

**설정 방법:**
1. Hierarchy에서 로봇 루트 GameObject 선택 (JointController가 있는 오브젝트)
2. `Add Component` → `Pick And Place Controller`
3. `Joint Controller` 필드가 비어 있으면 직접 드래그
4. `Sequence`가 비어 있으면 Inspector `⋮` → `Reset` 클릭
5. 각 자세의 `armJoints012` / `armJoints345` 값을 씬에 맞게 튜닝
   - IK target이 설정된 step은 armJoints012/345를 무시하고 IK 결과 사용
6. Play Mode 실행 (AutoStart=true → 1초 후 시작)

**ROS2 없이도 Unity 단독으로 시퀀스 동작 확인 가능.**

### 2.2 CCD IK Solver (v2) ✅ 완료

**파일:** `Assets/Scripts/RobotArm/IKSolver.cs` (300 lines)

CCD (Cyclic Coordinate Descent) 알고리즘으로 엔드이펙터(hand_link)를 목표 위치에 도달시키는 6개의 관절각 계산.

**FK (Forward Kinematics) 모델:**
- FK 계산은 직접 수학 모델을 사용 (Unity Transform 계층 기반)
- 모든 Niryo One 관절은 URDF Z축 → Unity Y축 회전 (articulation anchor 기준)
- Start() 시점의 `localPosition/localRotation`을 zero-pose 오프셋으로 캐싱
- FK 수식: `child_frame = parent_frame * static_offset(URDF origin) * joint_rotation(θ)`

**CCD 알고리즘:**
```
for iteration in 1..100:
    eePos = FK(current_angles)
    if dist(eePos, target) < 0.01m → converged
    
    for joint = hand → shoulder:
        pivot = position of joint pivot
        align vector(pivot→ee) to vector(pivot→target)
        rotation = acos(dot(toEE, toTarget))
        apply rotation around joint axis, clamped by limits
```

**주요 특징:**
- 모든 6개 관절 `ArticulationBody.anchorRotation`에서 회전축 자동 읽기
- URDF 관절 리미트 자동 적용 (SerializeField 기본값으로 내장)
- `m_JointChain`을 Inspector에서 직접 할당 가능 (shoulder_link ~ hand_link)
- `Reset()` 시 자동 체인 탐색: 자식 중 첫 6개 RevoluteJoint 수집
- 실패 시 `null` 반환, PickAndPlaceController가 하드코딩 각도로 폴백
- Editor Gizmos: 체인 시각화 (청록색 선/구), 엔드이펙터 노란색 강조

**설정 방법:**
1. JointController가 있는 GameObject에 `Add Component` → `IK Solver`
2. `Joint Chain` 배열에 shoulder_link, arm_link, elbow_link, forearm_link, wrist_link, hand_link 할당
3. (선택) PickAndPlaceController의 각 PoseStep에 `IK Target`(Transform)을 설정하면 해당 step은 IK 사용

### 다음 단계 (3/4)
| 단계 | 방식 | 상태 |
|------|------|------|
| v1 | 사전 정의 자세 (hardcoded angles) | ✅ 완료 |
| v2 | Unity 자체 IK (CCD) | ✅ 완료 |
| v3 | ROS2 MoveIt2 서비스 연동 | ⬜ 예정 |

### 아키텍처 (v2 업데이트)

```
Unity Scene (단독 동작)
────
PickAndPlaceController
├── PoseStep (8단계 시퀀스)
│   ├── IK Target (Transform) ──── 선택적, 설정 시 IK 사용
│   ├── armJoints012/345 ───────── IK 실패 시 폴백
│   └── gripperLeft/Right
│
├── IKSolver (CCD, 100 iterations, 1cm tolerance)
│   └── ForwardKinematics(angles) → EE position in root space
│
└── JointController.SetJointTargets(fullArray[8])

Unity + ROS2 VM (v3 예정)
─────
JointController                              │
  ├── /joint_states → [position] ───────────┤ MoveIt2
  ├── /joint_commands ← [target] ───────────┤
  │                                          │
  ├── /compute_ik ───────── request ────────►│ IK Solver
  └── /compute_ik ◄─────── response ────────┤
```

---

## Phase 3: ML-Agents 통합 (예정)

### 목표
- 강화학습으로 로봇암 제어 최적화
- JointController.SetJointTargets()를 ML-Agents Action으로 연결

### 필요 작업
| 작업 | 설명 |
|------|------|
| Agent 스크립트 작성 | NiryoOneAgent.cs (DecisionRequester + Agent) |
| Observation 설계 | joint positions, velocities, target position |
| Action 매핑 | joint target deltas (연속 제어) |
| 보상 함수 설계 | 목표 도달 거리 기반 |
| Training 실행 | ML-Agents 학습 파이프라인 |

### 아키텍처

```
ML-Agents (Unity)                    ROS2 VM
────────────────                    ────────
NiryoOneAgent                          │
  ├── CollectObservations() ──── [state]
  ├── OnActionReceived() ────── [action]
  │       │
  │       ▼
  │  JointController.SetJointTargets()
  │       │
  │       ▼
  │  ArticulationBody drive → robot moves
  │       │
  │       ▼
  ├── /joint_states ───────────────────► RViz / MoveIt2
  │
  └── Academy / Trainer (Python) ──── [reward]
```

---

## Phase 4: TurtleBot 시뮬레이션 (예정)

- TurtleBot URDF import
- ROS2 odometry + cmd_vel 통신
- SLAM / Navigation2 연동
- ML-Agents 경로 최적화

---

## 알려진 이슈 및 주의사항

| 이슈 | 설명 |
|------|------|
| **forceLimit=0 버그** | URDF-Importer Controller.Start()가 drive.forceLimit을 0으로 설정. 향후 URDF-Importer 업데이트 시 재확인 필요 |
| **Editor vs Standalone** | targetFrameRate=60은 Editor에서만 필요. Standalone 빌드 시 제거 가능 |
| **FixedUpdate 속도** | ArticulationBody 물리는 FixedUpdate 기반. Time.fixedDeltaTime(기본 0.02s)에 따라 drive update rate 결정 |
| **Joint name 일치** | ROS2 측 joint name = Unity link name (= GameObject.name). URDF 재임포트 시 이름 변경 주의 |
| **Gripper mimic joint** | gripper_joint_right가 gripper_joint_left의 mimic. 현재는 양쪽 prismatic을 별도 제어. 필요시 단일 제어로 단순화 가능 |

---

## 파일 인덱스

| 파일 | 설명 |
|------|------|
| `Assets/Scripts/RobotArm/JointController.cs` | 메인 joint 제어 스크립트 |
| `Assets/URDF/niryo_one/niryo_one.urdf` | Niryo One URDF 원본 |
| `Assets/URDF/niryo_one/niryo_one_urdf/` | URDF-Importer 생성 에셋 |
| `Assets/Resources/ROSConnectionPrefab.prefab` | ROSConnection 프리팹 |
| `Packages/manifest.json` | 패키지 의존성 |
| `docs/00_환경_설정_및_프로젝트_생성.md` | 환경 설정 문서 |
| `docs/01_ROS2_설치.md` | ROS2 설치 및 통신 설정 문서 |
| `docs/session_backup_2025-06-10.md` | 세션 백업 |

---

## Quick Start (현재 상태에서)

### Unity 씬 설정 (최초 1회)

1. Hierarchy에서 URDF-Importer가 생성한 로봇 루트 GameObject 선택
   - 보통 최상위 `NiryoOne` 또는 `niryo_one` (Prefab 해제 상태)
   - **선택 팁:** Hierarchy에서 제일 위에 있는 로봇 이름을 찾거나,
     `base_link`의 부모를 따라 올라가면 됩니다
2. `JointController`가 없다면 `Add Component` → `Joint Controller`
3. `Robot Root` 필드에 **같은 GameObject**를 드래그 (또는 비워두면 self 참조)
4. `ROSConnection` 프리팹이 씬에 있는지 확인
   - `Assets/Resources/ROSConnectionPrefab.prefab` → Hierarchy에 드래그
   - ROS IP Address: `192.168.75.204`, Port: `10000`
5. `PickAndPlaceController`를 추가하려면 같은 GameObject에
   `Add Component` → `Pick And Place Controller`
   - `Joint Controller` 필드가 자동으로 채워지지 않으면 직접 드래그
   - `Sequence`가 비어 있으면 Inspector 우측 상단 `⋮` → `Reset` 클릭

### Play Mode 실행

```bash
# 1) VM에서 ROS-TCP-Endpoint 실행
ssh rosuser@192.168.75.204
ros2 run ros_tcp_endpoint default_server_endpoint.py

# 2) Unity Play Mode 실행
#    (PickAndPlaceController.AutoStart=true → 1초 후 시퀀스 시작)

# 3) ROS에서 수동 joint 명령 전송
ros2 topic pub /joint_commands sensor_msgs/JointState \
  "{header: {}, name: ['shoulder_link','arm_link','elbow_link','forearm_link','wrist_link','hand_link'], \
    position: [0.8, -1.0, 1.2, -0.5, 0.3, 0.0], velocity: [], effort: []}" --once

# 4) joint states 확인
ros2 topic echo /joint_states
```

### 주의사항
- `JointController`의 `Robot Root`가 **올바른 로봇 루트 GameObject**를 가리키는지 반드시 확인
  - 잘못된 경우: `shoulder_link` 같은 자식이 루트로 설정됨 → joint 탐색 실패
  - 올바른 경우: 모든 ArticulationBody를 포함한 최상위 부모
- `PickAndPlaceController`는 `JointController`와 **같은 GameObject**에 추가

---

---

## Debugging Journey: Phase 1

이 섹션은 Phase 1 개발 과정에서 겪은 **실제 디버깅 과정**을 단계별로 기록합니다.
처음부터 완벽한 해결책을 찾은 것이 아니라, **가정 → 실험 → 실패 → 재가정**의 반복을 통해
진행되었습니다.

---

### Episode 1: "Arm이 전혀 움직이지 않는다"

#### 상황
JointController를 구현하고 `/joint_commands` subscriber까지 확인했지만,
팔이 한 치도 움직이지 않음.

#### 가정 1: "ROS 통신 문제일 것이다"
**행동:** VM에서 ROS 명령을 보내고 Unity 로그를 확인.

**결과:**
```
[JointController] OnJointCommand CALLED with 1 joints
[JointController] Received command: joints=[shoulder_link], positions=[0.5000]
[JointController] Alive ... pos[0]=0.0000
```
- ✅ subscriber callback 정상 도달
- ✅ `m_TargetPositions` 갱신됨
- ✅ `ApplyTargets()` 코드 경로 실행됨
- ❌ `pos[0]=0.0000` — joint position이 전혀 변하지 않음

**교훈:** callback이 도달하는 것과 실제 물리가 동작하는 것은 별개의 문제.

#### 가정 2: "움직임이 너무 작아서 못 보는 것일 수도 있다"
**행동:** TestDirectDrive 값을 0.5rad → 1.5rad으로 증가.
```csharp
float testTarget = 0.5f;  // → 1.5f로 변경
```

**결과:**
```
[JointController] TEST drive state: target=85.94° | stiffness=10000 | damping=100 | forceLimit=1000
```
- ✅ target이 85.94°로 설정됨
- ❌ stiffness=10000, damping=100, forceLimit=1000 — 모두 정상값
- ❌ 하지만 여전히 arm不動

**교훈:** 로그만 보고 "설정됐으니 작동하겠지"라고 믿으면 안 됨. 실제 물리 결과를 봐야 함.

#### 가정 3: "다른 스크립트가 drive 설정을 덮어쓰고 있다"
**행동:** URDF-Importer 소스코드를 분석 (PackageCache에서 직접 읽음).

발견한 내용:
```csharp
// Controller.cs (URDF-Importer 내장)
void Start()
{
    this.gameObject.AddComponent<FKRobot>();
    foreach (ArticulationBody joint in articulationChain)
    {
        joint.gameObject.AddComponent<JointControl>();
        ArticulationDrive currentDrive = joint.xDrive;
        currentDrive.forceLimit = forceLimit;  // forceLimit = 0 (미초기화!)
        joint.xDrive = currentDrive;
    }
}
```

```csharp
// JointControl.cs (URDF-Importer 내장)
void FixedUpdate(){
    ArticulationDrive currentDrive = joint.xDrive;
    float newTargetDelta = (int)direction * Time.fixedDeltaTime * speed;
    // direction=0(None) → newTargetDelta = 0
    currentDrive.target += newTargetDelta;
    joint.xDrive = currentDrive;
}
```

**핵심 발견:**
1. `forceLimit = 0`으로 설정됨 — drive가 낼 수 있는 최대 힘이 0
2. `Controller.Start()`는 `Awake()`보다 늦게 실행되어 우리가 설정한 값을 덮어씀
3. `JointControl.FixedUpdate()`도 계속 실행 중

**해결:**
```csharp
// InitializeDrive()와 SetTarget()에 추가
drive.forceLimit = 1000f;
```

추가로 모든 URDF-Importer 제어 컴포넌트 비활성화:
```csharp
var controllers = m_RobotRoot.GetComponents<Controller>();
foreach (var ctrl in controllers) ctrl.enabled = false;

var jointControls = m_RobotRoot.GetComponentsInChildren<JointControl>();
foreach (var jc in jointControls) jc.enabled = false;
```

**결과:**
```
[JointController] TEST drive state: target=85.94° | ... | forceLimit=1000
[JointController] Alive t=145.0s | ... | pos[0]=1.5000
```
- ✅ `pos[0]=1.5000` — 드디어 shoulder_link가 목표 위치에 정확히 도달!
- ✅ 실제로 팔이 회전하는 것을 확인

**교훈:** ArticulationDrive에서 `stiffness`와 `damping`만 중요하다고 생각했지만,
`forceLimit`이 0이면 **설정 자체가 무의미**해진다. Unity 물리에서 drive의 세 가지 축(stiffness/damping/forceLimit)은
**모두** 유효해야 동작한다.

---

### Episode 2: "Gripper 방향이 헷갈린다"

#### 상황
그리퍼 제어 테스트 중, left_gripper와 right_gripper의 방향 부호를 반복해서 혼동.

#### 시행착오 과정

| 시도 | 명령 (left, right) | 예상 | 실제 결과 |
|------|-------------------|------|----------|
| 1차 | `[0.02, 0.02]` | 좌우 동시 오무리기 | ❌ 둘 다 오른쪽으로 shift (같은 방향) |
| 2차 | `[-0.02, -0.02]` | 좌우 동시 펼치기 | ❌ 둘 다 왼쪽으로 shift |
| 3차 | `[-0.02, +0.02]` | 좌우 반대 = 오무리기 | ✅ 오무리기 (but 물리 관통) |
| 4차 | `[+0.02, -0.02]` | 좌우 반대 = 펼치기 | ✅ 펼치기 정상 |

**발견한 사실:**
- URDF의 `<mimic joint="gripper_joint_left" multiplier="-1"/>`가 Unity에서 **자동 변환되지 않음**
- `[left, right]`에 **반대 부호**를 넣어야 집게 동작이 됨
- `[-left, +right]` = 서로 모아짐 (close)
- `[+left, -right]` = 서로 벌어짐 (open)
- 실제 테스트 결과 사용자가 직접 명령을 보내면서 방향을 하나씩 검증하지 않으면 계속 혼동할 수 있는 부분

**교훈:** 
- Robotiq/Niryo 등 실제 gripper는 한쪽만 제어해도 양쪽이 mirror 동작한다.
- 하지만 Unity URDF-Importer는 `<mimic>`을 해석하지 못한다.
- 따라서 양쪽을 **항상 쌍으로** 제어해야 한다.
- 방향 부호는 **실제 테스트로만** 확정할 수 있다. (이론만으로 결정하지 말 것)

---

### Episode 3: "Gripper가 서로를 관통한다"

#### 상황
오무리기 명령 시 left_gripper와 right_gripper가 서로를 물리적으로 통과해버림.

#### 원인 분석

URDF 충돌 설정:
```xml
<disable_collision link1="right_gripper" link2="gripper_base"/>
<disable_collision link1="left_gripper" link2="gripper_base"/>
```

- `right_gripper` ↔ `gripper_base` 간 충돌 비활성화 (정상, 서로 연결되어 있으므로)
- `right_gripper` ↔ `left_gripper` 간 충돌은 **활성화됨** (설정상 문제 없음)
- 하지만 STL collision mesh가 gripper finger 내부 형상을 충분히 표현하지 못함

**원인:**
1. URDF collision mesh = `G1_ClampRight.STL` / `G1_ClampLeft.STL`
2. 이 STL 파일들의 collision 형상이 실제 물리 접촉을 정확히 표현하지 않음
3. `±0.02m` 이동 거리에서 핑거 두께보다 많이 움직여 서로 통과

**현재 상태:** 물리 관통 발생하지만 기능상 오무리기는 가능.
**개선 방안 (추후):**

| 방법 | 난이도 | 설명 |
|------|--------|------|
| 이동 범위 축소 | 쉬움 | `0.02` → `0.01` 또는 `0.005`로 제한 |
| Collision mesh 개선 | 중간 | Unity에서 단순 collision primitive(Cube)로 대체 |
| ArticulationBody collision 검사 | 어려움 | 드라이브 force에 반발력 추가 |

**교훈:**
- URDF의 collision mesh가 반드시 정확한 물리 충돌을 보장하지는 않는다.
- 시뮬레이션의 물리 관통은 생각보다 자주 발생한다.
- 실제 로봇과 달리 시뮬레이션에서는 joint limit만으로 완벽한 충돌 회피가 어렵다.

---

### Episode 4: "Editor에서 FPS가 0으로 떨어진다"

#### 상황
Play Mode 실행 후 다른 창으로 포커스를 옮기면 joint state publish가 멈춤.

**원인:**
- Unity Editor는 백그라운드에서 `Application.targetFrameRate`를 강제로 낮춤
- `InvokeRepeating`도 FPS에 간접적 영향을 받음
- FPS ≈ 0이면 `Update()`와 `InvokeRepeating`이 사실상 중단

**해결:**
```csharp
void Awake()
{
    Application.targetFrameRate = 60;  // frame rate floor 설정
    QualitySettings.vSyncCount = 0;    // VSync 해제 (Editor에서 중요)
}
```

추가로 `ProjectSettings > Player > Run in Background` 활성화.

**교훈:**
- Unity Editor에서 ROS 통신을 개발할 때는 **Editor의 백그라운드 동작**을 반드시 고려해야 함.
- `targetFrameRate`는 **천장이 아니라 바닥**을 설정한다 (vSyncCount=0일 때).
- Standalone 빌드에서는 이 문제가 발생하지 않지만, 개발 단계에서 편하게 작업하려면 Editor 설정이 중요.

---

### Episode 5: "JointController 리팩토링 — 진단 도구를 치우다"

#### 상황
Phase 1 디버깅이 완료되고 VM 통신까지 확인됨. 하지만 코드에
**진단용 임시 코드**가 잔뜩 남아 있음.

#### 문제점
| 항목 | 문제 | 제거 사유 |
|------|------|----------|
| `TestDirectDrive()` | 2초 후 shoulder를 1.5rad으로 강제 회전 | 디버깅 완료. 더 이상 필요 없음 |
| `Invoke(nameof(TestDirectDrive), 2.0f)` | Start()에서 호출 | 운영 중에는 불필요한 동작 |
| `PublishTick()` alive 로그 | 초당 1회 ros/sub/pos 로그 | Console이 로그로 가득 참 |
| `OnJointCommand()` 중복 로그 | 같은 내용을 다른 포맷으로 2회 출력 | 불필요한 중복 |
| 하드코딩된 `forceLimit = 1000f` | 코드 내 상수 | Inspector에서 튜닝 불가능 |
| private 메서드 docstring | `/// <summary>...` 6개 | 메서드명이 이미 역할을 설명 |

#### 해결 과정

**1단계: forceLimit을 SerializeField로 분리**
```csharp
// Before
drive.forceLimit = 1000f;  // 하드코딩

// After
[SerializeField] float m_DriveForceLimit = 1000f;  // Inspector 노출
drive.forceLimit = m_DriveForceLimit;

// SetTarget()에도 파라미터 추가
public void SetTarget(float target, float stiffness, float damping, float forceLimit)
```

**2단계: TestDirectDrive 제거**
```csharp
// Before
InvokeRepeating(nameof(PublishTick), m_PublishInterval, m_PublishInterval);
Invoke(nameof(TestDirectDrive), 2.0f);  // ← 삭제

// After
InvokeRepeating(nameof(PublishTick), m_PublishInterval, m_PublishInterval);
```
`TestDirectDrive()` 메서드 19줄 전체 삭제.

**3단계: PublishTick 단순화**
```csharp
// Before (15줄)
void PublishTick()
{
    m_PublishTickCounter++;
    if (m_PublishTickCounter % m_PublishRateHz == 0)
    {
        bool hasSub = m_Ros != null && m_Ros.HasSubscriber(m_JointCommandTopic);
        string subStatus = hasSub ? "OK" : "NONE";
        Debug.Log($"[JointController] Alive t={Time.time:F1}s | ...");
    }
    PublishJointStates();
}

// After (3줄)
void PublishTick()
{
    PublishJointStates();
}
```

**4단계: OnJointCommand 중복 로그 제거**
```csharp
// Before (2개의 Debug.Log가 같은 내용 출력)
Debug.Log($"[JointController] OnJointCommand: joints=[...] pos=[...]");  // 첫 번째
string names = string.Join(", ", command.name);
string positions = string.Join(", ", command.position.Select(p => $"{p:F4}"));
Debug.Log($"[JointController] Received command: joints=[{names}], positions=[{positions}]");  // 두 번째 (중복)

// After (불필요한 로그 제거, null 체크만 간결하게)
if (command.name == null || command.position == null) return;
```

#### 결과

| 지표 | 전 | 후 | 감소 |
|------|----|----|------|
| 전체 라인 수 | **392 lines** | **320 lines** | -72줄 (-18%) |
| Debug.Log 호출 | 11곳 | 7곳 | -4곳 |
| 주석/docstring | 과다 | 최소화 | 핵심만 유지 |
| Inspector 노출 필드 | 5개 | 6개 (+forceLimit) | 튜닝 가능 |

**교훈:**
- 디버깅이 끝나면 **진단 코드를 반드시 정리**해야 한다. 로그가 너무 많으면 오히려 실제 문제를 가린다.
- 하드코딩된 값은 반드시 `SerializeField`로 빼서 Inspector에서 튜닝 가능하게 해야 한다.
- "나중에 필요할지도 몰라"라는 생각으로 코드를 남겨두면 **기술 부채**가 쌓인다. Git에 기록되어 있으니 삭제를 두려워하지 말 것.

---

## Version History

| 날짜 | 버전 | 변경 내용 |
|------|------|----------|
| 2025-06-10 | v1.0 | JointController 최초 구현 (392 lines). forceLimit=0 버그 발견 및 수정. Unity 자체 구동 확인 |
| 2025-06-10 | v1.1 | ROS2 VM 통신 테스트 완료. 그리퍼 제어 확인 (mimic 미지원 확인) |
| 2025-06-10 | v1.2 | **리팩토링**: TestDirectDrive 제거, 로그 정리, forceLimit→SerializeField, docstring 제거 (320 lines, -72줄) |
| 2025-06-10 | v2.0 | **Pick-and-Place v1**: PickAndPlaceController.cs (160 lines), 8단계 사전 정의 시퀀스, 그리퍼 통합 |
| 2025-06-10 | v2.1 | **CCD IK Solver (v2)**: IKSolver.cs (300 lines), FK 수학 모델, CCD 100회 iteration, joint limits, IK target per PoseStep, 하드코딩 폴백 |
