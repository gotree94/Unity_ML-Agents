# Unity ML-Agents 완벽 가이드 (Release 23 기준)

> **최신 버전**: Release 23 (2025년 8월 28일)  
> **Python 패키지**: ml-agents 1.1.0  
> **Unity 패키지**: com.unity.ml-agents 4.0.0  
> **환경 관리**: venv (Python 내장) 또는 Conda (Miniconda 권장)  
> **공식 문서**: https://docs.unity3d.com/Packages/com.unity.ml-agents@4.0/manual/index.html  
> **GitHub 릴리즈**: https://github.com/Unity-Technologies/ml-agents/releases/tag/release_23_tag  
> **소스코드**: https://github.com/Unity-Technologies/ml-agents/tree/release_23

---

## 목차

1. [ML-Agents 개요](#1-ml-agents-개요)
2. [Release 23 주요 변경사항](#2-release-23-주요-변경사항)
3. [환경 설정 (Environment Setup)](#3-환경-설정-environment-setup)
4. [커리큘럼](#4-커리큘럼)
   - 4.1 [Dodge 프로젝트](#41-dodge-프로젝트)
   - 4.2 [PPO 알고리즘](#42-ppo-알고리즘)
   - 4.3 [Dodge 환경 수정을 통한 Attention PPO](#43-dodge-환경-수정을-통한-attention-ppo)
   - 4.4 [적대적 강화학습 PPO (Self-Play)](#44-적대적-강화학습-ppo-self-play)
   - 4.5 [방탈출 (Dungeon Escape)](#45-방탈출-dungeon-escape)
   - 4.6 [COMA 알고리즘](#46-coma-알고리즘)
   - 4.7 [MA-POCA 알고리즘](#47-ma-poca-알고리즘)
   - 4.8 [MA-POCA 코드 구현](#48-ma-poca-코드-구현)
   - 4.9 [메이즈 환경 만들기](#49-메이즈-환경-만들기)
   - 4.10 [RND 알고리즘](#410-rnd-알고리즘)
   - 4.11 [투 미션 환경 만들기](#411-투-미션-환경-만들기)
   - 4.12 [Hypernetworks](#412-hypernetworks)
5. [프로젝트](#5-프로젝트)
   - 5.1 [자율주행 연구 환경 구축](#51-자율주행-연구-환경-구축)
   - 5.2 [ML-Agents를 이용한 유튜브 사례](#52-ml-agents를-이용한-유튜브-사례)
   - 5.3 [산업 문제에 ML-Agents 적용 사례](#53-산업-문제에-ml-agents-적용-사례)
   - 5.4 [상용 게임에 ML-Agents 적용 사례](#54-상용-게임에-ml-agents-적용-사례)

---

# 1. ML-Agents 개요

## 1.1 Unity ML-Agents Toolkit이란?

Unity ML-Agents Toolkit은 Unity 엔진을 강화학습(Reinforcement Learning) 환경으로 변환해주는 오픈소스 프로젝트입니다. 게임 개발자와 연구자들이 Unity로 만든 2D/3D 환경에서 지능형 에이전트(Agent)를 훈련할 수 있도록 설계되었습니다.

**핵심 구성 요소:**

| 구성 요소 | 설명 |
|-----------|------|
| **Learning Environment** | Unity 씬(Scene)과 모든 게임 캐릭터를 포함하는 학습 환경 |
| **Python Low-Level API** | Python에서 Unity 환경을 제어할 수 있는 저수준 인터페이스 |
| **External Communicator** | Unity와 Python 프로세스 간 통신 (gRPC 기반) |
| **Trainer 구현체** | PPO, SAC, MA-POCA 등 강화학습 알고리즘 구현 |
| **Unity SDK (C#)** | Agent, Behavior Parameters 등 C# SDK |

## 1.2 지원 알고리즘

ML-Agents Toolkit은 다음과 같은 강화학습 알고리즘을 기본 제공합니다:

| 알고리즘 | 유형 | 특징 |
|----------|------|------|
| **PPO** (Proximal Policy Optimization) | 단일 에이전트, On-Policy | 안정적인 정책 최적화, 클리핑 기법 |
| **SAC** (Soft Actor-Critic) | 단일 에이전트, Off-Policy | 최대 엔트로피 기반, 샘플 효율 우수 |
| **MA-POCA** (Multi-Agent POCA) | 다중 에이전트, 협력 | 그룹 단위 학습, 중앙 비평자(Centralized Critic) |
| **Self-Play** (Ghost Trainer) | 경쟁 환경 | 자기 자신을 상대로 학습 |
| **BC** (Behavioral Cloning) | 모방 학습 | 데모로부터 학습 |
| **GAIL** (Generative Adversarial Imitation Learning) | 모방 학습 | 생성적 적대 신경망 기반 |

**보조 기능:**
- Curriculum Learning (커리큘럼 학습)
- Environment Parameter Randomization (환경 파라미터 무작위화)
- Curiosity / RND (희소 보상 환경 탐험)
- LSTM (메모리 기반 에이전트)

## 1.3 학습 방식

ML-Agents는 다음 두 가지 학습 방식을 지원합니다:

1. **내장 트레이너 (Built-in Trainer)**: Python 패키지(`mlagents-learn`)를 사용한 학습
2. **커스텀 트레이너 (Custom Trainer Plugin)**: 사용자 정의 알고리즘 플러그인

---

# 2. Release 23 주요 변경사항

## 2.1 버전 개요

| 항목 | 내용 |
|------|------|
| **릴리즈명** | Release 23 (v4.0.0) |
| **릴리즈 날짜** | 2025년 8월 28일 |
| **Python 패키지** | ml-agents 1.1.0 |
| **Unity 패키지** | com.unity.ml-agents 4.0.0 |
| **태그** | `release_23_tag` |
| **소스 브랜치** | `release_23` |

## 2.2 주요 변경사항

### Major Changes

1. **Inference Engine 2.2.1 업그레이드**
   - `com.unity.ml-agents`가 최신 Inference Engine 2.2.1로 업그레이드됨
   - 크로스 플랫폼 추론 성능 및 안정성 향상

2. **최소 Unity 버전 변경**
   - 최소 지원 Unity 버전이 **6000.0**으로 업데이트됨
   - 이전 버전(2022 LTS 등)과의 호환성 중단

3. **확장 패키지 통합**
   - `com.unity.ml-agents.extensions` 패키지가 메인 패키지로 병합됨
   - 별도 확장 패키지 설치 불필요

### Minor Changes

- **손상된 샘플 제거**: 패키지 내 손상된 샘플이 제거됨
- **문서 이전 완료**: 주요 개발자 문서가 Unity 패키지 문서로 완전히 이전됨
  - 웹 문서(https://unity-technologies.github.io/ml-agents/)는 더 이상 유지보수되지 않음
- **gRPC 버전 범위 조정**: `grpcio >=1.11.0, <=1.53.2`

## 2.3 마이그레이션 참고사항

Release 22 이하에서 Release 23으로 업그레이드 시 다음 사항을 확인하세요:

1. **Unity 버전**: Unity 6000.0 이상 필수
2. **Python 패키지**: `pip install mlagents==1.1.0`으로 업데이트
3. **ONNX 모델**: 기존 `.onnx` 모델은 Inference Engine 2.2.1과 호환됨
4. **확장 패키지**: 더 이상 `com.unity.ml-agents.extensions`를 별도로 추가하지 않음

---

# 3. 환경 설정 (Environment Setup)

## 3.1 사전 요구사항

### 시스템 요구사항

| 구성 요소 | 요구사항 |
|-----------|----------|
| **OS** | Windows 10/11 (64-bit), macOS 12+, Ubuntu 20.04+ |
| **Unity** | Unity 6000.0+ (2026 LTS 권장) |
| **Python** | Python 3.10 ~ 3.12 |
| **Conda** (선택) | Miniconda 3 (Python 3.10+ 포함) 또는 Anaconda 2024+ |
| **CUDA** (선택) | CUDA 11.8+ (NVIDIA GPU 가속) |
| **메모리** | 최소 8GB RAM (16GB+ 권장) |
| **디스크** | 최소 5GB 여유 공간 |

> **Conda vs venv 선택 가이드:**
> - **venv**: Python 기본 내장, 가볍고 단순, ML-Agents 단일 환경에 충분함
> - **Conda**: 패키지 의존성 충돌 관리에 강력함, CUDA 버전 관리 용이, 재현 가능한 환경(`environment.yml`) 공유에 최적
> - **권장**: 팀 협업이나 복잡한 의존성이 필요하면 Conda, 개인 학습은 venv로 충분

### 설치 구성도

```
[Unity Editor (Unity 6000.0+)]
  └── com.unity.ml-agents 4.0.0 (Package Manager)
       ├── C# SDK (Agent, Behavior Parameters 등)
       ├── 예제 환경 (Examples)
       └── Inference Engine 2.2.1

[Python 환경 (3.10~3.12)]
  └── mlagents 1.1.0 (pip)
       ├── mlagents-learn (CLI 트레이너)
       ├── PPO/SAC/MA-POCA 구현체
       └── gRPC 통신 (Unity ↔ Python)
```

## 3.2 Python 환경 설정

ML-Agents Python 환경은 아래 두 가지 방법 중 하나로 구성할 수 있습니다.
환경 이름은 `mlagents_env`로 통일합니다.

---

### 방법 A: venv (Python 내장, 간단 설정)

```bash
# Windows (PowerShell)
python -m venv mlagents_env
.\mlagents_env\Scripts\Activate.ps1

# macOS / Linux
python3 -m venv mlagents_env
source mlagents_env/bin/activate
```

### 방법 B: Conda (의존성 관리, 재현성 우수)

#### Conda 설치 (아직 없는 경우)

| OS | 다운로드 | 설치 명령어 |
|----|----------|-------------|
| **Windows** | https://docs.conda.io/en/latest/miniconda.html | Miniconda 설치 프로그램 실행 |
| **macOS** | https://docs.conda.io/en/latest/miniconda.html | `bash Miniconda3-latest-MacOSX-x86_64.sh` |
| **Linux** | https://docs.conda.io/en/latest/miniconda.html | `bash Miniconda3-latest-Linux-x86_64.sh` |

설치 후 터미널을 재시작하거나 `conda init`을 실행하세요.

#### Conda 환경 생성

```bash
conda create -n mlagents_env python=3.10 -y
conda activate mlagents_env
```

#### conda-forge 채널 우선 설정 (선택 사항)

```bash
conda config --add channels conda-forge
conda config --set channel_priority strict
```

---

### Step 2: ML-Agents Python 패키지 설치

#### 방법 A (venv 사용 시)

**PyPI에서 설치 (권장)**

```bash
pip install mlagents==1.1.0
pip install torch==2.1.0 --index-url https://download.pytorch.org/whl/cu118  # CUDA 11.8
pip install tensorboard
```

**소스에서 설치 (최신 개발 버전)**

```bash
git clone --branch release_23 https://github.com/Unity-Technologies/ml-agents.git
cd ml-agents

# ml-agents-envs 먼저 설치
cd ml-agents-envs
pip install -e .
cd ..

# ml-agents 설치
cd ml-agents
pip install -e .
cd ..
```

#### 방법 B (Conda 사용 시)

Conda 채널과 pip를 혼용합니다. conda 패키지를 **먼저** 설치한 후 pip를 실행하세요.

```bash
# 1) conda 채널 (CUDA 포함 PyTorch)
conda install pytorch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 cudatoolkit=11.8 -c pytorch -c nvidia -y
conda install numpy pandas matplotlib tensorboard -c conda-forge -y

# 2) pip (conda 채널에 없는 패키지)
pip install mlagents==1.1.0

# 3) gRPC (Unity 통신, 버전 범위 준수)
pip install protobuf==3.20.3 "grpcio>=1.11.0,<=1.53.2"
```

> **참고:** conda → pip 순서를 반드시 지키세요. 반대 순서로 설치하면 PyTorch와 CUDA 의존성이 꼬일 수 있습니다.

---

### environment.yml을 사용한 재현 가능한 환경 (Conda)

#### 1) 기본 ML-Agents 환경

`environment_mlagents.yml`:

```yaml
name: mlagents_env
channels:
  - pytorch
  - nvidia
  - conda-forge
  - defaults
dependencies:
  - python=3.10
  - pytorch=2.1.0
  - torchvision=0.16.0
  - torchaudio=2.1.0
  - cudatoolkit=11.8
  - numpy=1.24.3
  - pandas=2.0.3
  - matplotlib=3.7.2
  - tensorboard=2.14.0
  - pip>=23.0
  - pip:
    - mlagents==1.1.0
    - protobuf==3.20.3
    - grpcio==1.53.2
```

```bash
conda env create -f environment_mlagents.yml
conda activate mlagents_env
```

#### 2) 올인원 환경 (ML-Agents + SB3 + CUDA)

`environment_mlagents_full.yml`:

```yaml
name: mlagents_full
channels:
  - pytorch
  - nvidia
  - conda-forge
  - defaults
dependencies:
  # --- Python ---
  - python=3.10
  - pip>=23.0

  # --- PyTorch + CUDA ---
  - pytorch=2.1.0
  - torchvision=0.16.0
  - torchaudio=2.1.0
  - cudatoolkit=11.8

  # --- 데이터/시각화 ---
  - numpy=1.24.3
  - pandas=2.0.3
  - matplotlib=3.7.2
  - tensorboard=2.14.0
  - scipy=1.11.1
  - scikit-learn=1.3.0

  # --- pip 설치 ---
  - pip:
    # Unity ML-Agents
    - mlagents==1.1.0

    # 강화학습 (커스텀 트레이너 등)
    - stable-baselines3==2.3.0
    - sb3-contrib==2.3.0

    # gRPC (Unity 통신)
    - protobuf==3.20.3
    - grpcio==1.53.2

    # 모델 변환/추론
    - onnx==1.14.0
    - onnxruntime==1.15.1

    # 유틸리티
    - pyyaml==6.0.1
    - tqdm==4.65.0
    - psutil==5.9.5
```

```bash
conda env create -f environment_mlagents_full.yml
conda activate mlagents_full
```

> **설치 시간:** 위 올인원 환경은 약 5~10분 소요됩니다.

#### environment.yml 업데이트 및 내보내기

```bash
# 환경에 새 패키지를 추가한 후
conda env export -n mlagents_env > environment_backup.yml          # 전체 (플랫폼 종속)
conda env export -n mlagents_env --from-history > environment.yml  # 간소화 (이식성 높음)
```

> **팀 협업 팁:** `--from-history`를 사용하고 pip 섹션은 수동 추가하여 OS에 독립적인 yml 유지

#### 환경 제거

```bash
conda deactivate
conda env remove -n mlagents_env
conda info --envs
```

---

### Python 환경 비교 요약

| 항목 | venv | Conda |
|------|------|-------|
| **설치 필요** | Python에 내장 | Miniconda 별도 설치 |
| **환경 위치** | 프로젝트 폴더 내 | `~/miniconda3/envs/` |
| **격리 수준** | pip 패키지만 | Python + 시스템 라이브러리(CUDA 등) |
| **CUDA 관리** | 수동 (pip 인덱스 지정) | conda 채널로 자동 (`cudatoolkit`) |
| **재현성** | `requirements.txt` (pip freeze) | `environment.yml` (완전 재현) |
| **디스크 사용량** | 작음 (~200MB) | 큼 (~2-4GB, CUDA 포함 시) |
| **권장 사용자** | 간단한 단일 환경 | 팀 협업, 복잡한 의존성 |

---

### Step 3: 설치 확인

```bash
mlagents-learn --help
```
정상 출력 시 ML-Agents 학습에 필요한 CLI 도구가 준비된 것입니다.

```bash
# 상세 확인
python -c "import mlagents; print(f'ml-agents: {mlagents.__version__}')"
python -c "import torch; print(f'PyTorch {torch.__version__}, CUDA: {torch.cuda.is_available()}')"
python -c "import grpc; print(f'gRPC {grpc.__version__}')"
tensorboard --logdir=results  # 텐서보드 실행 테스트
```

## 3.3 Unity 환경 설정 (Unity 6000.0+)

### Step 1: Unity 프로젝트 생성

1. Unity Hub 실행
2. **New Project** 클릭
3. 템플릿: **3D (Built-In Render Pipeline)** 선택
4. 프로젝트 이름과 위치 지정
5. **Create project** 클릭

### Step 2: ML-Agents 패키지 설치

1. Unity Editor에서 `Window > Package Manager` 메뉴 열기
2. **Packages:** 드롭다운에서 **Unity Registry** 선택
3. 검색창에 **ML Agents** 입력
4. `ML Agents` 패키지 선택
5. 우측 하단 **Install** 버튼 클릭 (버전 4.0.0)
6. 설치 완료 확인

### Step 3: 예제 환경 임포트

1. Package Manager에서 ML-Agents 패키지 선택
2. **Samples** 탭 확장
3. 원하는 예제(예: `3D Ball`)의 **Import** 버튼 클릭
4. `Assets/ML-Agents/Examples/` 경로에 예제 파일들이 추가됨

### Step 4: 예제 실행 테스트

1. `Assets/ML-Agents/Examples/3DBall/Scenes/3DBall` 씬 열기
2. 계층 뷰에서 `Ball3DAcademy` → `Agent` 객체 선택
3. `Behavior Parameters` 컴포넌트의 `Behavior Type`을 `Inference Only`로 설정
4. **Play** 버튼 클릭
5. 사전 훈련된 모델로 공 균형 맞추기 동작 확인

## 3.4 학습 실행 테스트

### Step 1: Unity 씬 설정

1. 예제 씬(예: 3DBall) 열기
2. `Behavior Parameters`에서 `Behavior Type`을 **Default**로 설정
3. 에디터에서 Play 모드 진입하지 않고 대기

### Step 2: 훈련 실행

```bash
# 3DBall 예제 학습
mlagents-learn config/ppo/3DBall.yaml --run-id=test_3dball
```

**YAML 설정 파일 예시 (`config/ppo/3DBall.yaml`):**

```yaml
behaviors:
  3DBall:
    trainer_type: ppo
    hyperparameters:
      batch_size: 1024
      buffer_size: 10240
      learning_rate: 3.0e-4
      beta: 5.0e-3
      epsilon: 0.2
      lambd: 0.95
      num_epoch: 3
      learning_rate_schedule: linear
    network_settings:
      normalize: false
      hidden_units: 128
      num_layers: 2
    reward_signals:
      extrinsic:
        gamma: 0.99
        strength: 1.0
    max_steps: 5.0e5
    time_horizon: 64
    summary_freq: 10000
```

### Step 3: TensorBoard로 학습 모니터링

```bash
tensorboard --logdir=results
```

브라우저에서 `http://localhost:6006` 접속하여 Cumulative Reward, Policy Loss, Value Loss 등 확인

### Step 4: 훈련된 모델 저장

훈련 완료 후 `.onnx` 파일이 `results/<run-id>/` 경로에 생성됩니다.

### Step 5: Unity에서 모델 사용

1. 생성된 `.onnx` 파일을 Unity 프로젝트의 `Assets` 폴더로 드래그
2. Agent의 `Behavior Parameters` → `Model` 필드에 할당
3. `Behavior Type`을 `Inference Only`로 변경
4. Play 모드로 동작 확인

## 3.5 일반적인 문제 해결

| 문제 | 해결 방법 |
|------|-----------|
| Python과 Unity 버전 불일치 | 릴리즈 표에서 동일한 버전 쌍 사용 확인 |
| gRPC 통신 오류 | 방화벽 확인, `grpcio` 버전 범위 준수 |
| CUDA/CPU 텐서 혼합 오류 | `threaded: false` 설정 시도 |
| 학습 성능 저하 | GPU 사용 확인, `torch.cuda.is_available()` |
| 카메라 센서 오류 | Python과 Unity 패키지 버전 일치 확인 |
| **Conda 환경 생성 실패** | `conda clean --all` 후 재시도. `conda update conda -n base -c conda-forge`로 conda 업데이트 |
| **Conda + pip 충돌** | conda 패키지를 먼저 설치한 후 pip 실행. 환경을 새로 만들고 순서 준수 |
| **`conda env create` 느림** | `mamba` 설치 후 `mamba env create -f environment_mlagents.yml` (5배 빠름) |
| **PyTorch CUDA 미인식** | `conda install cudatoolkit=11.8 -c nvidia` 명시적 설치. `nvidia-smi`로 드라이버 확인 |
| **`pip install mlagents` 오류** | Python 3.10 확인, `protobuf==3.20.3` 고정, `pip install --no-cache-dir` 시도 |

---

# 4. 커리큘럼

## 4.1 Dodge 프로젝트

### 4.1.1 개요

**DodgeBall 환경**은 Unity ML-Agents 팀이 제공하는 공식 예제 환경입니다. 협력(Cooperative)과 경쟁(Competitive) 시나리오가 혼합된 다중 에이전트 환경으로, 실제 게임과 유사한 환경에서 ML-Agents를 테스트할 수 있습니다.

**GitHub**: https://github.com/Unity-Technologies/ml-agents-dodgeball-env

### 4.1.2 게임 모드

DodgeBall 환경은 3가지 게임 모드를 지원합니다:

| 모드 | 설명 |
|------|------|
| **Team Elimination (팀 제거전)** | 두 팀이 공을 던져 상대 팀원을 제거. 모든 팀원이 제거되면 패배 |
| **Capture the Flag (깃발 뺏기)** | 상대 진영의 깃발을 가져와 아군 진영으로 귀환 |
| **Solo (개인전)** | 개인 간 자유로운 대결 |

### 4.1.3 환경 구성

**Agent 사양:**
- **관측 (Observations)**: Ray Perception (레이 캐스트), 자체 속도/위치
- **액션 (Actions)**: 연속적 이동 (x,z), 회전, 공 던지기
- **보상 (Rewards)**:
  - `elimination_hit_reward` (기본값 0.1): 상대 명중 시
  - `ctf_hit_reward` (기본값 0.02): CTF 모드 명중 시
  - 제거 시 상대 팀 -1.0 / 아군 +1.0

**하이퍼파라미터 예시:**
```yaml
behaviors:
  DodgeBall:
    trainer_type: ppo
    hyperparameters:
      batch_size: 128
      buffer_size: 2048
      learning_rate: 3.0e-4
      beta: 5.0e-3
      epsilon: 0.2
      lambd: 0.95
      num_epoch: 3
    network_settings:
      normalize: true
      hidden_units: 256
      num_layers: 2
    reward_signals:
      extrinsic:
        gamma: 0.99
        strength: 1.0
    max_steps: 1.0e7
    time_horizon: 1000
    summary_freq: 30000
```

### 4.1.4 학습 방법

1. Unity에서 DodgeBall 씬 열기
2. Behavior Parameters를 "Default"로 설정
3. 다음 명령어로 학습 실행:
```bash
mlagents-learn config/ppo/DodgeBall.yaml --run-id=dodgeball_01
```

### 4.1.5 환경 확장

DodgeBall 환경은 다음과 같이 확장 가능합니다:
- 새로운 게임 모드 추가
- 맵 구조 변경 (장애물 추가/제거)
- 에이전트 수 조정
- 보상 함수 재정의
- 멀티 에이전트 협력 태스크 추가

---

## 4.2 PPO 알고리즘

### 4.2.1 개요

**PPO (Proximal Policy Optimization)** 는 OpenAI에서 개발한 강화학습 알고리즘으로, ML-Agents의 기본 트레이너입니다. 정책(Policy) 업데이트를 제한(Clipping)하여 학습 안정성을 확보하는 것이 특징입니다.

- **논문**: "Proximal Policy Optimization Algorithms" (Schulman et al., 2017)
- **유형**: On-Policy, Actor-Critic
- **ML-Agents 구현**: PyTorch 기반

### 4.2.2 핵심 개념

#### 목적 함수 (Clipped Surrogate Objective)

PPO의 핵심은 클리핑된 서로게이트 목적 함수입니다:

```
L^CLIP(θ) = Ê_t[min(r_t(θ)Â_t, clip(r_t(θ), 1-ε, 1+ε)Â_t)]
```

- `r_t(θ)`: 확률비 (새 정책 / 이전 정책)
- `Â_t`: 이점 함수 (Advantage Function)
- `ε`: 클리핑 범위 (보통 0.2)

#### PPO vs 다른 알고리즘

| 알고리즘 | 샘플 효율 | 학습 안정성 | 구현 복잡도 |
|----------|-----------|------------|-------------|
| **PPO** | 중간 | 높음 | 중간 |
| **SAC** | 높음 | 중간 | 높음 |
| **DQN** | 낮음 | 낮음 | 낮음 |
| **A3C** | 중간 | 중간 | 높음 |

### 4.2.3 ML-Agents PPO 하이퍼파라미터

| 파라미터 | 설명 | 일반 범위 | 기본값 |
|----------|------|-----------|--------|
| `batch_size` | 미니배치 크기 | 512 ~ 4096 | 1024 |
| `buffer_size` | 경험 버퍼 크기 | 2048 ~ 65536 | 10240 |
| `learning_rate` | 학습률 | 1e-5 ~ 1e-3 | 3e-4 |
| `beta` | 엔트로피 계수 | 1e-4 ~ 0.01 | 5e-3 |
| `epsilon` | 클리핑 범위 | 0.1 ~ 0.3 | 0.2 |
| `lambd` | GAE 파라미터 | 0.9 ~ 0.99 | 0.95 |
| `num_epoch` | 에포크 수 | 3 ~ 10 | 3 |
| `gamma` | 할인 계수 | 0.8 ~ 0.9997 | 0.99 |
| `time_horizon` | 시간 지평선 | 32 ~ 2048 | 64 |
| `hidden_units` | 은닉층 뉴런 수 | 64 ~ 512 | 128 |
| `num_layers` | 은닉층 수 | 1 ~ 3 | 2 |

### 4.2.4 PPO 학습 모범 사례

1. **보상 정규화 (Reward Normalization)**
   - 보상 스케일이 너무 크거나 작지 않도록 조정
   - `normalize: true` 설정 권장

2. **네트워크 구조**
   - 간단한 환경: `hidden_units: 128`, `num_layers: 2`
   - 복잡한 환경: `hidden_units: 256~512`, `num_layers: 3~4`

3. **버퍼 크기 조정**
   - `buffer_size`가 너무 작으면 샘플 다양성 부족
   - `buffer_size`가 너무 크면 학습 속도 저하

4. **학습률 스케줄**
   - `learning_rate_schedule: linear` (선형 감소) 권장
   - `learning_rate_schedule: constant` (고정)는 초기 학습에 사용

### 4.2.5 PPO 학습 커맨드

```bash
# 기본 PPO 학습
mlagents-learn config/ppo/MyConfig.yaml --run-id=my_ppo_run

# 멀티 환경 학습 (속도 향상)
mlagents-learn config/ppo/MyConfig.yaml --run-id=my_ppo_run --num-envs=4

# 기존 모델 불러와서 추가 학습
mlagents-learn config/ppo/MyConfig.yaml --run-id=my_ppo_run --resume

# 기존 모델로 초기화
mlagents-learn config/ppo/MyConfig.yaml --run-id=my_ppo_v2 --initialize-from=my_ppo_run
```

---

## 4.3 Dodge 환경 수정을 통한 Attention PPO

### 4.3.1 Attention Mechanism (어텐션 메커니즘) 개요

어텐션 메커니즘은 입력 데이터의 중요한 부분에 "주목"할 수 있게 하는 신경망 기술입니다. 원래 트랜스포머(Transformer) 아키텍처에서 도입되었으며, 강화학습에서는 에이전트가 환경 내 중요한 객체에 선택적으로 집중할 수 있게 합니다.

### 4.3.2 Self-Attention의 핵심 개념

Self-Attention은 시퀀스 내 각 요소가 다른 모든 요소와의 관계를 계산합니다:

```
Attention(Q, K, V) = softmax(QK^T / √d_k)V
```

- **Q (Query)**: 현재 요소가 "질문"하는 벡터
- **K (Key)**: 다른 요소들이 "답변"하는 키 벡터
- **V (Value)**: 실제 정보가 담긴 값 벡터
- **d_k**: 스케일링 팩터

### 4.3.3 ML-Agents에서의 어텐션 활용

ML-Agents Toolkit은 공식적으로 트랜스포머 기반 어텐션을 기본 트레이너에 내장하고 있지 않습니다. 그러나 다음과 같은 방법으로 어텐션을 통합할 수 있습니다:

#### 방법 1: BufferSensor를 통한 가변 길이 관측

ML-Agents 4.0.0은 `BufferSensor`를 지원하여 가변 개체 수 관측이 가능합니다. 이를 통해 에이전트가 주변 에이전트/객체에 대한 정보를 동적으로 수신할 수 있습니다.

```csharp
// C# BufferSensor 사용 예시
public class DodgeBallAttentionAgent : Agent
{
    public BufferSensorComponent bufferSensor;
    
    public override void CollectObservations(VectorSensor sensor)
    {
        // 고정 관측 (자신의 상태)
        sensor.AddObservation(this.transform.localPosition);
        sensor.AddObservation(this.GetComponent<Rigidbody>().velocity);
        
        // 가변 길이 관측 (주변 에이전트/공 정보)
        var bufferSensorComponent = GetComponent<BufferSensorComponent>();
        var nearbyObjects = FindNearbyObjects();
        
        foreach (var obj in nearbyObjects)
        {
            float[] obs = new float[5];
            obs[0] = obj.relativePosition.x;
            obs[1] = obj.relativePosition.z;
            obs[2] = obj.velocity.x;
            obs[3] = obj.velocity.z;
            obs[4] = obj.isEnemy ? 1.0f : 0.0f;
            bufferSensorComponent.AppendObservation(obs);
        }
    }
}
```

#### 방법 2: 커스텀 트레이너 플러그인 (어텐션 레이어 추가)

```python
# Python 커스텀 트레이너 예시 - 어텐션 레이어를 네트워크에 추가
import torch
import torch.nn as nn

class AttentionPPONetwork(nn.Module):
    def __init__(self, observation_size, action_size, hidden_size=128):
        super().__init__()
        self.embedding = nn.Linear(observation_size, hidden_size)
        
        # Multi-Head Self-Attention
        self.attention = nn.MultiheadAttention(
            embed_dim=hidden_size,
            num_heads=4,
            batch_first=True
        )
        
        self.actor = nn.Sequential(
            nn.Linear(hidden_size, hidden_size),
            nn.ReLU(),
            nn.Linear(hidden_size, action_size)
        )
        
        self.critic = nn.Sequential(
            nn.Linear(hidden_size, hidden_size),
            nn.ReLU(),
            nn.Linear(hidden_size, 1)
        )
    
    def forward(self, x):
        # x shape: (batch, seq_len, obs_size)
        x = self.embedding(x)  # (batch, seq_len, hidden)
        x, _ = self.attention(x, x, x)  # Self-Attention
        x = x.mean(dim=1)  # Pool over sequence
        
        action_probs = self.actor(x)
        value = self.critic(x)
        return action_probs, value
```

#### 방법 3: TransformerXL (GTrXL) 적용

최신 연구(SECT-PPO, 2025)에서는 GTrXL(Gated Transformer XL)과 PPO를 결합하여 성능 향상을 보여주고 있습니다. HPC 작업 스케줄링에 적용된 이 프레임워크는 이중 게이트 메커니즘으로 장기 시퀀스 모델링 효율을 개선합니다.

### 4.3.4 Dodge 환경에 어텐션 PPO 적용하기

**단계별 접근:**

1. **환경 분석**: DodgeBall에서 각 에이전트가 관측해야 할 객체 식별
2. **BufferSensor 설정**: 주변 에이전트/공/장애물 정보를 BufferSensor로 수집
3. **네트워크 수정**:
   - 관측 임베딩 레이어 추가
   - Self-Attention 레이어 (4-8 head) 추가
   - 출력을 Actor/Critic으로 분기
4. **학습**: 수정된 네트워크로 PPO 학습 실행
5. **평가**: 기존 PPO 대비 성능 비교 (수렴 속도, 최종 보상)

> **참고**: 어텐션 메커니즘은 에이전트 수가 많거나 부분 관측성이 강한 환경에서 특히 효과적입니다.

---

## 4.4 적대적 강화학습 PPO (Self-Play)

### 4.4.1 Self-Play 개요

Self-Play는 에이전트가 자기 자신의 과거 정책들을 상대로 학습하는 방식입니다. 이는 경쟁 환경에서 점진적으로 실력을 향상시키는 효과적인 방법입니다. AlphaGo, OpenAI Five, AlphaStar 등의 성공에 핵심적으로 사용되었습니다.

**Self-Play의 핵심 원리:**
- 에이전트가 자신과 비슷한 수준의 상대와 대결
- 상대가 너무 강하거나 약하면 학습이 효과적이지 않음
- 시간이 지남에 따라 상대도 함께 발전

### 4.4.2 ML-Agents Self-Play 아키텍처

ML-Agents는 **Ghost Trainer**라는 이름으로 Self-Play를 구현합니다.

```
┌───────────────────────────────────────────────┐
│              Training Loop                     │
│                                               │
│  ┌──────────┐          ┌──────────┐           │
│  │ Agent A  │◄────────►│ Agent B  │           │
│  │ (Current)│          │ (Past/Snapshot)       │
│  └──────────┘          └──────────┘           │
│        │                      │                │
│        ▼                      ▼                │
│  ┌──────────────────────────────────┐          │
│  │      Opponent Pool               │          │
│  │  ┌────┐ ┌────┐ ┌────┐ ┌────┐   │          │
│  │  │T=1 │ │T=2 │ │T=3 │ │T=4 │...│          │
│  │  └────┘ └────┘ └────┘ └────┘   │          │
│  └──────────────────────────────────┘          │
└───────────────────────────────────────────────┘
```

### 4.4.3 Self-Play 하이퍼파라미터

| 파라미터 | 설명 | 기본값 |
|----------|------|--------|
| `swap_steps` | 상대방 변경 스텝 간격 | 10000 |
| `window` | 저장할 과거 정책 수 | 10 |
| `play_against_latest_model_ratio` | 최신 모델과 대결할 확률 | 0.5 |
| `save_steps` | 정책 저장 스텝 간격 | 20000 |
| `team_change` | 팀 변경 주기 | 100000 |
| `ghota` | Self-Play GAIL 사용 여부 | false |

### 4.4.4 Self-Play 설정 예시

```yaml
behaviors:
  Soccer:
    trainer_type: ppo
    hyperparameters:
      batch_size: 128
      buffer_size: 2048
      learning_rate: 3.0e-4
      beta: 1.0e-2
      epsilon: 0.2
      lambd: 0.95
      num_epoch: 3
    network_settings:
      normalize: true
      hidden_units: 256
      num_layers: 2
    reward_signals:
      extrinsic:
        gamma: 0.99
        strength: 1.0
    self_play:
      window: 10
      play_against_latest_model_ratio: 0.5
      save_steps: 20000
      swap_steps: 10000
      team_change: 100000
    max_steps: 5.0e6
    time_horizon: 64
    summary_freq: 10000
```

### 4.4.5 Dodge 환경에서 Self-Play 적용

DodgeBall 환경은 본질적으로 팀 대 팀 경쟁 환경이므로 Self-Play 적용에 적합합니다.

**적용 단계:**
1. DodgeBall 씬에서 각 팀이 동일한 Behavior Parameters 사용하도록 설정
2. Self-Play 설정을 YAML 파일에 추가
3. 학습 실행 시 `--self-play` 관련 파라미터 자동 적용
4. TensorBoard로 ELO 점수(Elo Rating) 변화 모니터링

### 4.4.6 Self-Play 모범 사례

1. **상대 풀 크기**: `window=10~20`이 적당. 너무 크면 다양한 상대에 과적합, 너무 작으면 일반화 부족
2. **최신 모델 대결 비율**: `play_against_latest_model_ratio=0.5` → 절반은 최신, 절반은 과거 정책과 대결
3. **안정성 vs 다양성**: 낮은 `swap_steps`는 안정적인 학습, 높은 `swap_steps`는 다양한 전략 학습
4. **ELO 모니터링**: Self-Play 학습 시 ELO 점수가 꾸준히 증가하는지 확인

---

## 4.5 방탈출 (Dungeon Escape)

### 4.5.1 개요

Dungeon Escape는 ML-Agents의 예제 환경 중 하나로, 협력적 다중 에이전트 시나리오입니다. 여러 에이전트가 함께 던전을 탐험하고 탈출구를 찾아야 합니다.

### 4.5.2 환경 구성

- **시나리오**: 여러 에이전트가 던전에 갇혀 협력하여 탈출
- **에이전트**: 2~4명의 협력 에이전트
- **관측**: Ray Perception, 상대 위치, 방향 정보
- **액션**: 이동, 상호작용
- **보상**: 탈출 성공 시 +1.0, 단계별 소폭 패널티

### 4.5.3 SimpleMultiAgentGroup 사용

Dungeon Escape는 `SimpleMultiAgentGroup`을 사용한 협력 학습을 보여줍니다.

```csharp
public class DungeonEscapeAgent : Agent
{
    private SimpleMultiAgentGroup agentGroup;

    public override void Initialize()
    {
        agentGroup = GetComponentInParent<SimpleMultiAgentGroup>();
    }

    public override void OnEpisodeBegin()
    {
        // 에피소드 초기화
    }

    public override void CollectObservations(VectorSensor sensor)
    {
        // 관측 수집
        sensor.AddObservation(transform.localPosition);
        // 추가 관측...
    }

    public override void OnActionReceived(ActionBuffers actions)
    {
        // 액션 처리
        var move = actions.ContinuousActions[0];
        var rotate = actions.ContinuousActions[1];
        
        // 이동 로직...
        
        // 탈출 성공 시 그룹 보상
        if (reachedExit)
        {
            agentGroup.AddGroupReward(1.0f);
            agentGroup.EndGroupEpisode();
        }
    }
}
```

### 4.5.4 MA-POCA 설정

```yaml
behaviors:
  DungeonEscape:
    trainer_type: poca  # MA-POCA 트레이너
    hyperparameters:
      batch_size: 128
      buffer_size: 2048
      learning_rate: 3.0e-4
      beta: 5.0e-3
      epsilon: 0.2
      lambd: 0.95
      num_epoch: 3
    network_settings:
      normalize: true
      hidden_units: 256
      num_layers: 2
    reward_signals:
      extrinsic:
        gamma: 0.99
        strength: 1.0
    max_steps: 2.0e6
    time_horizon: 128
    summary_freq: 10000
```

---

## 4.6 COMA 알고리즘

### 4.6.1 개요

**COMA (Counterfactual Multi-Agent Policy Gradients)** 는 다중 에이전트 강화학습을 위한 Actor-Critic 알고리즘입니다. Foerster et al. (2018)이 AAAI 2018에서 발표했으며, 중앙 비평자(Centralized Critic)와 분산 행위자(Decentralized Actor) 구조를 사용합니다.

- **논문**: "Counterfactual Multi-Agent Policy Gradients" (Foerster et al., 2018)
- **적용 분야**: StarCraft 유닛 마이크로매니지먼트, 협력 다중 에이전트 태스크
- **핵심**: Counterfactual Baseline을 통한 크레딧 할당(Credit Assignment)

### 4.6.2 핵심 개념

#### 1. Centralized Critic with Decentralized Actors (CTDE)

```
┌──────────────────────────────────────────┐
│           Training (중앙 집중)              │
│  ┌────────┐  ┌────────┐  ┌────────┐      │
│  │Agent 1 │  │Agent 2 │  │Agent 3 │      │
│  └───┬────┘  └───┬────┘  └───┬────┘      │
│      │           │           │            │
│      └─────┬─────┴─────┬─────┘            │
│            │           │                  │
│      ┌─────▼───────────▼──────┐           │
│      │   Centralized Critic   │           │
│      │    Q(s, a₁, a₂, a₃)   │           │
│      └────────────────────────┘           │
│                                           │
│  Inference (분산 실행)                     │
│  각 에이전트는 자신의 관측만으로 행동 결정    │
└──────────────────────────────────────────┘
```

#### 2. Counterfactual Baseline

COMA의 핵심 혁신은 Counterfactual Baseline입니다. 이는 특정 에이전트의 행동을 고정하고 다른 에이전트의 행동을 주변화(marginalize)하여 해당 에이전트의 기여도를 측정합니다:

```
A_i(s, a) = Q(s, a) - Σ_{a'_i} π_i(a'_i | τ_i) Q(s, (a'_{-i}, a'_i))
```

- `Q(s, a)`: 전체 행동 조인트에 대한 Q-값
- `π_i(a'_i | τ_i)`: 에이전트 i의 정책
- 두 번째 항: 에이전트 i의 행동을 변경했을 때의 기대 Q-값

#### 3. 효율적 구현

COMA의 비평자는 단일 forward pass로 모든 에이전트의 counterfactual baseline을 계산할 수 있도록 설계되었습니다.

### 4.6.3 COMA 알고리즘 슈도코드

```
1. 각 에피소드 시작 시 환경 초기화
2. for each timestep t:
   a. 각 에이전트 i가 자신의 관측 τ_i(t)에 기반하여 행동 a_i(t) 샘플링
   b. 모든 에이전트의 행동을 환경에 적용 → 다음 상태 s(t+1), 보상 r(t)
   c. 경험 저장: (s(t), a(t), r(t), s(t+1))
3. for each 학습 스텝:
   a. 미니배치 샘플링
   b. Centralized Critic 업데이트: Q(s, a) 학습
   c. 각 에이전트 i의 Counterfactual Advantage 계산
   d. 각 에이전트 i의 정책 π_i 업데이트 (Advantage 사용)
```

### 4.6.4 ML-Agents와 COMA

> **참고:** ML-Agents는 COMA 알고리즘을 공식적으로 내장하고 있지 않습니다. 그러나 COMA의 CTDE(Centralized Training with Decentralized Execution) 개념은 MA-POCA에 영감을 주었습니다. COMA를 사용하려면 커스텀 트레이너 플러그인으로 구현해야 합니다.

**COMA vs MA-POCA 비교:**

| 특징 | COMA | MA-POCA |
|------|------|---------|
| 비평자 구조 | 중앙 Q-함수 | 그룹 단위 Q-함수 |
| 크레딧 할당 | Counterfactual Baseline | 그룹 보상 공유 |
| 확장성 | 에이전트 수 증가 시 Q-함수 차원 폭발 | 그룹 단위로 확장 가능 |
| 적용 | StarCraft 등 소규모 | 협력/경쟁 일반 환경 |

---

## 4.7 MA-POCA 알고리즘

### 4.7.1 개요

**MA-POCA (Multi-Agent POCA)** 는 ML-Agents가 제공하는 다중 에이전트 협력 학습 알고리즘입니다. POCA(Policy Optimization via Centralized Advantage)의 확장판으로, `SimpleMultiAgentGroup`을 통해 에이전트 그룹 단위로 학습합니다.

- **도입 버전**: Release 15 (ML-Agents v1.0)
- **유형**: On-Policy, Centralized Critic with Decentralized Actors
- **적용 환경**: 협력 다중 에이전트 태스크

### 4.7.2 핵심 개념

#### 그룹 기반 학습

MA-POCA는 `SimpleMultiAgentGroup`을 통해 여러 에이전트를 하나의 그룹으로 묶어 학습합니다:

```csharp
// 그룹 생성
var group = new SimpleMultiAgentGroup();

// 에이전트를 그룹에 추가
group.RegisterAgent(agent1);
group.RegisterAgent(agent2);
group.RegisterAgent(agent3);

// 그룹에 보상 부여
group.AddGroupReward(1.0f);

// 그룹 종료
group.EndGroupEpisode();
```

#### 그룹 보상 메커니즘

- **그룹 보상**: 모든 그룹 멤버가 동일한 보상을 공유
- **개인 보상**: 개별 에이전트에게 추가 보상 가능
- **그룹 종료**: 모든 에이전트가 동시에 에피소드 종료

### 4.7.3 MA-POCA 학습 프로세스

```
1. Unity 씬에서 SimpleMultiAgentGroup 생성
2. 그룹에 에이전트 등록
3. 각 에이전트가 독립적으로 관측 수집 및 행동 결정
4. 환경이 그룹 보상 계산
5. 매 스텝마다 그룹 보상 정보가 Python 트레이너로 전송
6. MA-POCA 트레이너가 그룹 단위로 정책 최적화
```

### 4.7.4 YAML 설정

```yaml
behaviors:
  CooperativeTask:
    trainer_type: poca  # MA-POCA 지정
    hyperparameters:
      batch_size: 128
      buffer_size: 2048
      learning_rate: 3.0e-4
      beta: 5.0e-3
      epsilon: 0.2
      lambd: 0.95
      num_epoch: 3
    network_settings:
      normalize: true
      hidden_units: 256
      num_layers: 2
    reward_signals:
      extrinsic:
        gamma: 0.99
        strength: 1.0
      # 그룹 보상 신호
      gec:
        gamma: 0.99
        strength: 1.0
    max_steps: 2.0e6
    time_horizon: 128
    summary_freq: 10000
```

### 4.7.5 적용 환경

MA-POCA가 적용된 ML-Agents 예제 환경:
- **Cooperative Push Block**: 여러 에이전트가 협력하여 블록 밀기
- **Dungeon Escape**: 협력 탈출
- **Soccer (Team)**: 팀 기반 축구

---

## 4.8 MA-POCA 코드 구현

### 4.8.1 C# (Unity 측) 구현

#### Agent 클래스 구현

```csharp
using Unity.MLAgents;
using Unity.MLAgents.Sensors;
using Unity.MLAgents.Actuators;
using UnityEngine;

public class CooperativeAgent : Agent
{
    [SerializeField] private Transform targetObject;
    private SimpleMultiAgentGroup agentGroup;
    private Rigidbody rb;

    public override void Initialize()
    {
        rb = GetComponent<Rigidbody>();
        agentGroup = GetComponentInParent<EnvironmentManager>().AgentGroup;
        agentGroup.RegisterAgent(this);
    }

    public override void OnEpisodeBegin()
    {
        // 에이전트 위치 초기화
        transform.localPosition = new Vector3(
            Random.Range(-3f, 3f),
            0.5f,
            Random.Range(-3f, 3f)
        );
        rb.velocity = Vector3.zero;
        rb.angularVelocity = Vector3.zero;
    }

    public override void CollectObservations(VectorSensor sensor)
    {
        // 자신의 위치와 속도
        sensor.AddObservation(transform.localPosition);
        sensor.AddObservation(rb.velocity);

        // 목표 객체까지의 상대적 위치
        if (targetObject != null)
        {
            sensor.AddObservation(targetObject.localPosition - transform.localPosition);
        }
        
        // 다른 에이전트와의 거리
        var otherAgents = FindObjectsOfType<CooperativeAgent>();
        foreach (var agent in otherAgents)
        {
            if (agent != this)
            {
                sensor.AddObservation(agent.transform.localPosition - transform.localPosition);
            }
        }
    }

    public override void OnActionReceived(ActionBuffers actions)
    {
        // 연속 액션: 이동 및 회전
        var moveX = actions.ContinuousActions[0];
        var moveZ = actions.ContinuousActions[1];
        var rotate = actions.ContinuousActions[2];

        // 이동 적용
        var move = new Vector3(moveX, 0, moveZ) * 5f * Time.deltaTime;
        transform.Translate(move, Space.World);

        // 회전 적용
        transform.Rotate(0, rotate * 100f * Time.deltaTime, 0);

        // 단계별 소액 패널티 (시간 효율적 행동 유도)
        AddReward(-0.001f);
    }

    private void OnCollisionEnter(Collision collision)
    {
        if (collision.gameObject.CompareTag("Target"))
        {
            // 목표 달성 시 그룹 보상
            agentGroup.AddGroupReward(1.0f);
            agentGroup.EndGroupEpisode();
        }
        
        if (collision.gameObject.CompareTag("Obstacle"))
        {
            // 장애물 충돌 시 개인 패널티
            AddReward(-0.1f);
        }
    }

    private void OnDestroy()
    {
        if (agentGroup != null)
        {
            agentGroup.UnregisterAgent(this);
        }
    }
}
```

#### EnvironmentManager 클래스

```csharp
using UnityEngine;
using Unity.MLAgents;

public class EnvironmentManager : MonoBehaviour
{
    public SimpleMultiAgentGroup AgentGroup { get; private set; }

    void Start()
    {
        AgentGroup = new SimpleMultiAgentGroup();
    }

    public void ResetEnvironment()
    {
        // 환경 리셋 로직
        AgentGroup.EndGroupEpisode();
    }
}
```

### 4.8.2 Python (트레이너 측) 설정

```yaml
# config/poca/CooperativeTask.yaml
behaviors:
  CooperativeTask:
    trainer_type: poca
    hyperparameters:
      batch_size: 128
      buffer_size: 2048
      learning_rate: 3.0e-4
      beta: 5.0e-3
      epsilon: 0.2
      lambd: 0.95
      num_epoch: 3
      learning_rate_schedule: linear
    network_settings:
      normalize: true
      hidden_units: 256
      num_layers: 2
      vis_encode_type: simple
    reward_signals:
      extrinsic:
        gamma: 0.99
        strength: 1.0
    max_steps: 2.0e6
    time_horizon: 128
    summary_freq: 10000
    threaded: true
```

### 4.8.3 학습 실행

```bash
# MA-POCA 학습 실행
mlagents-learn config/poca/CooperativeTask.yaml --run-id=poca_coop_01 --num-envs=4

# TensorBoard 모니터링
tensorboard --logdir=results
```

### 4.8.4 학습 결과 확인

TensorBoard에서 확인할 주요 메트릭:
- **Environment/Cumulative Reward**: 그룹 누적 보상 추이
- **Policy/Learning Rate**: 학습률 변화
- **Policy/Entropy**: 정책 엔트로피 (탐험 정도)
- **Policy/Value Estimate**: 가치 추정치

---

## 4.9 메이즈 환경 만들기

### 4.9.1 개요

메이즈(미로) 환경은 강화학습 에이전트가 미로를 탐색하여 목표 지점에 도달하는 태스크입니다. ML-Agents를 사용하여 절차적 생성(Procedural Generation) 방식의 메이즈 환경을 만들 수 있습니다.

### 4.9.2 메이즈 생성 알고리즘

#### DFS (Depth-First Search) 기반 메이즈 생성

```csharp
using UnityEngine;
using System.Collections.Generic;

public class MazeGenerator : MonoBehaviour
{
    [SerializeField] private int width = 10;
    [SerializeField] private int height = 10;
    [SerializeField] private GameObject wallPrefab;
    [SerializeField] private GameObject floorPrefab;
    [SerializeField] private GameObject goalPrefab;

    private int[,] maze;  // 0: path, 1: wall
    private List<Vector2Int> visitedCells = new List<Vector2Int>();

    public void GenerateMaze()
    {
        // 메이즈 초기화 (모두 벽)
        maze = new int[width, height];
        for (int x = 0; x < width; x++)
            for (int y = 0; y < height; y++)
                maze[x, y] = 1;

        // DFS 기반 메이즈 생성
        var startCell = new Vector2Int(1, 1);
        DFS(startCell);
        
        // 씬에 메이즈 배치
        BuildMaze();
    }

    private void DFS(Vector2Int current)
    {
        visitedCells.Add(current);
        maze[current.x, current.y] = 0;  // 경로로 설정

        // 방향 섞기 (랜덤성)
        var directions = new List<Vector2Int>
        {
            new Vector2Int(0, 2),   // 상
            new Vector2Int(0, -2),  // 하
            new Vector2Int(2, 0),   // 우
            new Vector2Int(-2, 0)   // 좌
        };
        directions.Shuffle();

        foreach (var dir in directions)
        {
            var next = new Vector2Int(current.x + dir.x, current.y + dir.y);
            
            if (IsInBounds(next) && !visitedCells.Contains(next))
            {
                // 벽 제거 (현재와 다음 사이)
                var wallPos = new Vector2Int(current.x + dir.x / 2, current.y + dir.y / 2);
                maze[wallPos.x, wallPos.y] = 0;
                DFS(next);
            }
        }
    }

    private bool IsInBounds(Vector2Int cell)
    {
        return cell.x > 0 && cell.x < width - 1 && 
               cell.y > 0 && cell.y < height - 1;
    }

    private void BuildMaze()
    {
        // 기존 메이즈 제거
        foreach (Transform child in transform)
            DestroyImmediate(child.gameObject);

        // 바닥 생성
        var floor = Instantiate(floorPrefab, transform);
        floor.transform.localScale = new Vector3(width, 1, height);
        floor.transform.position = new Vector3(width / 2f, -0.5f, height / 2f);

        // 벽과 경로 배치
        for (int x = 0; x < width; x++)
        {
            for (int y = 0; y < height; y++)
            {
                if (maze[x, y] == 1)  // 벽
                {
                    var wall = Instantiate(wallPrefab, transform);
                    wall.transform.position = new Vector3(x, 0, y);
                }
            }
        }

        // 목표 지점 배치 (가장 먼 곳)
        var goalPos = FindFarthestCell(new Vector2Int(1, 1));
        var goal = Instantiate(goalPrefab, transform);
        goal.transform.position = new Vector3(goalPos.x, 0.5f, goalPos.y);
    }

    private Vector2Int FindFarthestCell(Vector2Int from)
    {
        Vector2Int farthest = from;
        float maxDist = 0;
        
        for (int x = 0; x < width; x++)
        {
            for (int y = 0; y < height; y++)
            {
                if (maze[x, y] == 0)
                {
                    float dist = Vector2.Distance(from, new Vector2Int(x, y));
                    if (dist > maxDist)
                    {
                        maxDist = dist;
                        farthest = new Vector2Int(x, y);
                    }
                }
            }
        }
        return farthest;
    }
}

// 리스트 셔플 유틸리티
public static class ListExtensions
{
    private static System.Random rng = new System.Random();
    
    public static void Shuffle<T>(this IList<T> list)
    {
        int n = list.Count;
        while (n > 1)
        {
            n--;
            int k = rng.Next(n + 1);
            T value = list[k];
            list[k] = list[n];
            list[n] = value;
        }
    }
}
```

### 4.9.3 Maze Agent 구현

```csharp
using Unity.MLAgents;
using Unity.MLAgents.Sensors;
using Unity.MLAgents.Actuators;
using UnityEngine;

public class MazeAgent : Agent
{
    private Rigidbody rb;
    private MazeGenerator mazeGenerator;
    private bool reachedGoal = false;

    public override void Initialize()
    {
        rb = GetComponent<Rigidbody>();
        mazeGenerator = GetComponentInParent<MazeGenerator>();
    }

    public override void OnEpisodeBegin()
    {
        // 새 에피소드마다 새로운 메이즈 생성
        mazeGenerator.GenerateMaze();
        
        // 에이전트를 시작 지점에 배치
        transform.localPosition = new Vector3(1, 0.5f, 1);
        rb.velocity = Vector3.zero;
        reachedGoal = false;
    }

    public override void CollectObservations(VectorSensor sensor)
    {
        // Ray Perception 센서 (12개 ray, 30도 간격)
        // 또는 직접 관측 수집:
        
        // 자신의 위치와 속도
        sensor.AddObservation(transform.localPosition);
        sensor.AddObservation(rb.velocity);
        sensor.AddObservation(rb.angularVelocity);
        
        // 전방 방향
        sensor.AddObservation(transform.forward);
    }

    public override void OnActionReceived(ActionBuffers actions)
    {
        var moveX = actions.ContinuousActions[0];
        var moveZ = actions.ContinuousActions[1];
        
        var move = new Vector3(moveX, 0, moveZ) * 3f * Time.deltaTime;
        transform.Translate(move, Space.World);
        
        // 회전
        var rotate = actions.ContinuousActions[2];
        transform.Rotate(0, rotate * 100f * Time.deltaTime, 0);
        
        // 단계별 패널티 (빠른 탐색 유도)
        AddReward(-0.001f);
    }

    private void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("Goal") && !reachedGoal)
        {
            reachedGoal = true;
            AddReward(1.0f);  // 목표 달성 보상
            EndEpisode();     // 에피소드 종료
        }

        if (other.CompareTag("Wall"))
        {
            AddReward(-0.1f);  // 벽 충돌 패널티
        }
    }

    private void OnCollisionEnter(Collision collision)
    {
        if (collision.gameObject.CompareTag("Wall"))
        {
            AddReward(-0.05f);
        }
    }
}
```

### 4.9.4 학습 설정

```yaml
behaviors:
  MazeNavigation:
    trainer_type: ppo
    hyperparameters:
      batch_size: 128
      buffer_size: 2048
      learning_rate: 3.0e-4
      beta: 5.0e-3
      epsilon: 0.2
      lambd: 0.95
      num_epoch: 3
    network_settings:
      normalize: true
      hidden_units: 256
      num_layers: 3
    reward_signals:
      extrinsic:
        gamma: 0.99
        strength: 1.0
    max_steps: 5.0e6
    time_horizon: 256
    summary_freq: 10000
```

### 4.9.5 메이즈 학습 팁

1. **절차적 생성**: 매 에피소드마다 새로운 메이즈 생성 → 일반화 능력 향상
2. **커리큘럼 학습**: 
   - 1단계: 작은 메이즈 (5x5) → 쉬운 시작
   - 2단계: 중간 메이즈 (10x10)
   - 3단계: 큰 메이즈 (15x15)
3. **탐험 보상**: 희소 보상 문제 해결을 위해 방문하지 않은 셀 탐험 시 추가 보상
4. **LSTM 사용**: 메모리가 필요한 환경에서는 LSTM 레이어 활성화
   ```yaml
   network_settings:
     memory:
       sequence_length: 64
       memory_size: 256
   ```

---

## 4.10 RND 알고리즘

### 4.10.1 개요

**RND (Random Network Distillation)** 는 희소 보상(Sparse Reward) 환경에서 탐험을 장려하는 방법입니다. Burda et al. (2019)이 ICLR 2019에서 발표했으며, OpenAI가 Montezuma's Revenge에서 인간 수준 성능을 달성하는 데 사용했습니다.

- **논문**: "Exploration by Random Network Distillation" (Burda et al., 2019)
- **핵심 아이디어**: 방문한 상태의 참신성(Novelty)을 예측 오차로 측정
- **장점**: Noisy-TV 문제 해결, 구현 단순, 확장성 우수

### 4.10.2 작동 원리

RND는 두 개의 네트워크를 사용합니다:

```
┌───────────────────┐     ┌────────────────────┐
│  Target Network   │     │  Predictor Network  │
│  (고정, 랜덤 가중치) │     │  (학습 가능)        │
│                   │     │                    │
│  f: 상태 → 특징    │     │  f̂: 상태 → 특징     │
└────────┬──────────┘     └────────┬───────────┘
         │                        │
         └──────────┬─────────────┘
                    │
                    ▼
          예측 오차 = ||f(s) - f̂(s)||²
                    │
                    ▼
           내재적 보상 (Intrinsic Reward)
```

**프로세스:**
1. Target Network `f`는 랜덤 초기화 후 고정
2. Predictor Network `f̂`는 `f`의 출력을 모방하도록 학습
3. 방문한 상태의 예측 오차 = 내재적 보상
4. 익숙한 상태는 예측 오차 ↓ → 내재적 보상 ↓
5. 새로운 상태는 예측 오차 ↑ → 내재적 보상 ↑

### 4.10.3 수학적 표현

**Predictor 손실 함수:**
```
L(θ) = E_x[ ||f̂(x; θ) - f(x)||² ]
```

**내재적 보상:**
```
i_t = ||f̂(s_{t+1}) - f(s_{t+1})||²
```

**총 보상:**
```
r_total = r_extrinsic + η · r_intrinsic
```

여기서 `η`는 내재적 보상의 강도를 조절하는 하이퍼파라미터입니다.

### 4.10.4 ML-Agents에서 RND 사용

ML-Agents는 RND를 내재적 보상 신호(Intrinsic Reward Signal)로 구현합니다:

```yaml
behaviors:
  ExplorationTask:
    trainer_type: ppo
    hyperparameters:
      batch_size: 128
      buffer_size: 2048
      learning_rate: 3.0e-4
      beta: 1.0e-2
      epsilon: 0.2
      lambd: 0.95
      num_epoch: 3
    network_settings:
      normalize: true
      hidden_units: 256
      num_layers: 2
    reward_signals:
      extrinsic:
        gamma: 0.99
        strength: 1.0
      rnd:  # RND 내재적 보상
        gamma: 0.99
        strength: 1.0
        encoding_size: 256
        learning_rate: 1.0e-3
    max_steps: 5.0e6
    time_horizon: 64
    summary_freq: 10000
```

### 4.10.5 RND 하이퍼파라미터

| 파라미터 | 설명 | 권장값 |
|----------|------|--------|
| `strength` | 내재적 보상 강도 (η) | 0.1 ~ 1.0 |
| `encoding_size` | 특징 벡터 크기 | 128 ~ 512 |
| `learning_rate` | RND 네트워크 학습률 | 1.0e-4 ~ 1.0e-3 |

### 4.10.6 RND 사용 모범 사례

1. **내재적 보상 스케일링**: 외재적 보상과 균형을 맞추기 위해 `strength` 조정
2. **네트워크 크기**: 복잡한 환경일수록 더 큰 `encoding_size` 필요
3. **탐험 vs 활용 균형**: 학습 초기에는 내재적 보상이 높고, 후기에는 낮아져야 함
4. **Noisy-TV 문제**: 랜덤 노이즈가 있는 환경에서도 RND는 효과적으로 탐험

### 4.10.7 RND vs Curiosity (ICM)

| 특징 | RND | ICM (Intrinsic Curiosity Module) |
|------|-----|----------------------------------|
| **예측 대상** | 랜덤 타겟 특징 | 다음 상태 (forward dynamics) |
| **Noisy-TV 문제** | 강건함 | 취약함 |
| **구현 복잡도** | 낮음 | 중간 |
| **계산 비용** | 낮음 | 중간 |
| **확장성** | 우수 (대규모 병렬 환경 지원) | 제한적 |

---

## 4.11 투 미션 환경 만들기

### 4.11.1 개요

"투 미션(Two Missions)" 환경은 에이전트가 두 가지 상이한 임무를 동시에 또는 순차적으로 수행해야 하는 환경입니다. 이는 전이 학습(Transfer Learning), 멀티태스크 학습(Multi-Task Learning), 계층적 강화학습(Hierarchical RL) 등을 테스트하는 데 유용합니다.

### 4.11.2 환경 설계

#### 시나리오 A: 순차적 미션

```
┌─────────────────────────────────────────┐
│           Game Arena                     │
│                                         │
│  ┌──────────┐    ┌──────────┐           │
│  │ Mission A │───►│ Mission B │           │
│  │ (탐색)     │    │ (조작)    │           │
│  └──────────┘    └──────────┘           │
│        │               │                 │
│        ▼               ▼                 │
│   +수집 보상      +퍼즐 해결 보상         │
└─────────────────────────────────────────┘
```

#### 시나리오 B: 동시 미션

```
┌─────────────────────────────────────────┐
│          Multi-Task Arena                │
│                                         │
│  ┌──────────┐                           │
│  │ Mission A │───┐                      │
│  │ (수집/회피) │   │  ┌──────────┐      │
│  └──────────┘   ├──►│ Main Task│      │
│  ┌──────────┐   │   │ (종합 점수)│      │
│  │ Mission B │───┘  └──────────┘      │
│  │ (퍼즐 해결) │                       │
│  └──────────┘                         │
└─────────────────────────────────────────┘
```

### 4.11.3 C# 코드 구현

```csharp
using Unity.MLAgents;
using Unity.MLAgents.Sensors;
using Unity.MLAgents.Actuators;
using UnityEngine;

public class DualMissionAgent : Agent
{
    public enum MissionType { Collect, Puzzle, Both }
    
    [SerializeField] private MissionType currentMission = MissionType.Collect;
    
    // 미션 A 관련
    private int coinsCollected = 0;
    [SerializeField] private int coinsToCollect = 5;
    
    // 미션 B 관련
    private bool puzzleSolved = false;
    [SerializeField] private GameObject puzzleObject;
    
    // 미션 상태
    private bool missionACompleted = false;
    private bool missionBCompleted = false;
    private Rigidbody rb;

    public override void Initialize()
    {
        rb = GetComponent<Rigidbody>();
    }

    public override void OnEpisodeBegin()
    {
        // 초기화
        coinsCollected = 0;
        puzzleSolved = false;
        missionACompleted = false;
        missionBCompleted = false;
        currentMission = MissionType.Collect;
        
        // 에이전트 위치 초기화
        transform.localPosition = Vector3.zero;
        rb.velocity = Vector3.zero;
        
        // 코인 생성
        SpawnCoins();
        
        // 퍼즐 초기화
        ResetPuzzle();
    }

    public override void CollectObservations(VectorSensor sensor)
    {
        // 공통 관측
        sensor.AddObservation(transform.localPosition);
        sensor.AddObservation(rb.velocity);
        
        // 현재 미션 정보
        sensor.AddObservation((int)currentMission);
        sensor.AddObservation(missionACompleted ? 1.0f : 0.0f);
        sensor.AddObservation(missionBCompleted ? 1.0f : 0.0f);
        
        // 미션 A: 남은 코인 수
        sensor.AddObservation(coinsToCollect - coinsCollected);
        
        // 미션 B: 퍼즐 해결 상태
        sensor.AddObservation(puzzleSolved ? 1.0f : 0.0f);
    }

    public override void OnActionReceived(ActionBuffers actions)
    {
        var moveX = actions.ContinuousActions[0];
        var moveZ = actions.ContinuousActions[1];
        
        var move = new Vector3(moveX, 0, moveZ) * 5f * Time.deltaTime;
        transform.Translate(move, Space.World);
        
        // 단계별 패널티
        AddReward(-0.001f);
        
        // 미션 전환 체크
        CheckMissionTransition();
    }

    private void CheckMissionTransition()
    {
        // 미션 A 완료 시 미션 B로 전환
        if (currentMission == MissionType.Collect && coinsCollected >= coinsToCollect)
        {
            missionACompleted = true;
            currentMission = MissionType.Puzzle;
            AddReward(0.5f);  // 미션 완료 보너스
        }
        
        // 두 미션 모두 완료
        if (missionACompleted && puzzleSolved)
        {
            missionBCompleted = true;
            AddReward(2.0f);  // 전체 완료 보너스
            EndEpisode();
        }
    }

    private void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("Coin") && currentMission == MissionType.Collect)
        {
            coinsCollected++;
            Destroy(other.gameObject);
            AddReward(0.2f);  // 코인 수집 보상
        }
        
        if (other.CompareTag("PuzzleKey") && currentMission == MissionType.Puzzle)
        {
            puzzleSolved = true;
            AddReward(0.5f);  // 퍼즐 해결 보상
        }
    }

    private void SpawnCoins()
    {
        // 코인 생성 로직 (랜덤 위치에 생성)
        for (int i = 0; i < coinsToCollect; i++)
        {
            Vector3 randomPos = new Vector3(
                Random.Range(-5f, 5f),
                0.5f,
                Random.Range(-5f, 5f)
            );
            // 코인 인스턴스화...
        }
    }

    private void ResetPuzzle()
    {
        // 퍼즐 초기화 로직
        puzzleObject.SetActive(true);
    }
}
```

### 4.11.4 학습 설정 (멀티태스크 PPO)

```yaml
behaviors:
  DualMission:
    trainer_type: ppo
    hyperparameters:
      batch_size: 256
      buffer_size: 4096
      learning_rate: 3.0e-4
      beta: 5.0e-3
      epsilon: 0.2
      lambd: 0.95
      num_epoch: 3
    network_settings:
      normalize: true
      hidden_units: 256
      num_layers: 3
    reward_signals:
      extrinsic:
        gamma: 0.99
        strength: 1.0
      curiosity:  # 호기심 기반 탐험
        gamma: 0.99
        strength: 0.1
        encoding_size: 128
        learning_rate: 1.0e-3
    max_steps: 1.0e7
    time_horizon: 128
    summary_freq: 10000
```

### 4.11.5 확장 아이디어

1. **커리큘럼 적용**: 미션 난이도를 점진적으로 증가
2. **랜덤 미션 순서**: 매 에피소드마다 미션 순서를 랜덤화하여 일반성 향상
3. **멀티 에이전트**: 각 에이전트가 서로 다른 미션을 담당
4. **부분 관측성**: 각 미션 공간을 분리하여 부분 관측 환경 구현
5. **계층적 학습**: 상위 정책이 어떤 미션을 수행할지 결정, 하위 정책이 실행

---

## 4.12 Hypernetworks

### 4.12.1 개요

**Hypernetwork**는 다른 신경망(주 네트워크)의 가중치를 생성하는 신경망입니다. Ha et al. (2017)이 제안했으며, 강화학습에서는 에이전트 간 파라미터 공유, 적응형 정책, 메타 학습 등에 활용됩니다.

- **논문**: "HyperNetworks" (Ha et al., 2017, ICLR 2017)
- **핵심 아이디어**: 작은 네트워크가 큰 네트워크의 가중치를 동적으로 생성
- **강화학습 응용**: 다중 에이전트 파라미터 생성, 적응적 행동 정책

### 4.12.2 Hypernetwork 구조

```
┌────────────────┐
│   Hypernetwork  │ (소규모 네트워크)
│   g(z; θ)      │
└───────┬────────┘
        │ 생성된 가중치
        ▼
┌────────────────┐
│   Main Network  │ (대규모 네트워크 = 정책)
│   f(x; W_gen)   │
└────────────────┘
```

**Hypernetwork 수식:**
```
W = g(z; θ)    // Hypernetwork가 주 네트워크의 가중치 W 생성
y = f(x; W)    // 주 네트워크가 입력 x를 처리하여 출력 y 생성
```

### 4.12.3 ML-Agents와 Hypernetwork 통합

ML-Agents는 Hypernetwork를 내장하고 있지 않지만, 커스텀 트레이너 플러그인으로 구현 가능합니다.

#### Python 구현 예시

```python
import torch
import torch.nn as nn
import torch.nn.functional as F

class HyperNetwork(nn.Module):
    """주 네트워크의 가중치를 생성하는 Hypernetwork"""
    
    def __init__(self, embedding_dim=32, main_hidden=128, main_output=4):
        super().__init__()
        self.embedding_dim = embedding_dim
        
        # Hypernetwork 자체 - 작은 규모
        self.hyper = nn.Sequential(
            nn.Linear(embedding_dim, 64),
            nn.ReLU(),
            nn.Linear(64, 128),
            nn.ReLU(),
        )
        
        # 가중치 생성 레이어
        self.weight_gen_w1 = nn.Linear(128, main_hidden * main_hidden)
        self.bias_gen_w1 = nn.Linear(128, main_hidden)
        self.weight_gen_w2 = nn.Linear(128, main_output * main_hidden)
        self.bias_gen_w2 = nn.Linear(128, main_output)
    
    def generate_weights(self, z):
        """임베딩 z로부터 주 네트워크 가중치 생성"""
        h = self.hyper(z)
        
        w1 = self.weight_gen_w1(h).view(-1, main_hidden, main_hidden)
        b1 = self.bias_gen_w1(h).view(-1, 1, main_hidden)
        w2 = self.weight_gen_w2(h).view(-1, main_output, main_hidden)
        b2 = self.bias_gen_w2(h).view(-1, 1, main_output)
        
        return (w1, b1), (w2, b2)


class HyperPolicyNetwork(nn.Module):
    """Hypernetwork이 생성한 가중치를 사용하는 정책 네트워크"""
    
    def __init__(self, input_size=8, main_hidden=128, action_size=4):
        super().__init__()
        self.input_size = input_size
        self.main_hidden = main_hidden
        self.action_size = action_size
        
        # Hypernetwork (작은 네트워크)
        self.hypernet = HyperNetwork(
            embedding_dim=32,
            main_hidden=main_hidden,
            main_output=action_size
        )
        
        # 에이전트별 임베딩
        self.agent_embedding = nn.Embedding(10, 32)  # 최대 10 에이전트
    
    def forward(self, x, agent_id):
        # 에이전트 ID를 임베딩으로 변환
        z = self.agent_embedding(agent_id)
        
        # Hypernetwork가 주 네트워크 가중치 생성
        (w1, b1), (w2, b2) = self.hypernet.generate_weights(z)
        
        # 경사도 추적을 위해 가중치 텐서를 평탄화하지 않고 사용
        # 실제로는 이렇게 weight를 동적 생성하는 것은 까다로움
        # 대신, Hypernetwork 출력을 입력과 결합하는 방식을 사용할 수 있음
        
        # 실제 적용: Hypernetwork 출력을 Feature로 사용
        h = self.hypernet.hyper(z)
        
        # Feature conditioning 방식
        x = F.linear(x, w1.squeeze(0), b1.squeeze(0))
        x = F.relu(x)
        action_logits = F.linear(x, w2.squeeze(0), b2.squeeze(0))
        
        return action_logits
```

### 4.12.4 Hypernetwork 변형: HyperMARL

HyperMARL (2024)은 Hypernetwork를 다중 에이전트 RL에 적용한 연구입니다:

- 에이전트-조건부 Hypernetwork가 에이전트별 파라미터 생성
- 관측-에이전트 결합 경사도 간섭 문제 해결
- 에이전트 ID와 관측 간 커플링 완화

### 4.12.5 Hypernetwork 활용 아이디어

1. **다중 에이전트 파라미터 공유**: 하나의 Hypernetwork가 여러 에이전트의 정책 파라미터 생성
2. **적응형 난이도**: 환경에 따라 Hypernetwork가 정책 복잡도 조절
3. **전이 학습**: 사전 학습된 Hypernetwork를 새로운 태스크에 적용
4. **메타 학습**: 다양한 태스크에서 Hypernetwork 학습 후 새로운 태스크에 빠르게 적응

> **참고**: Hypernetwork는 ML-Agerts 기본 기능이 아니므로, `커스텀 트레이너 플러그인` 시스템을 통해 직접 구현해야 합니다.

---

# 5. 프로젝트

## 5.1 자율주행 연구 환경 구축

### 5.1.1 개요

Unity ML-Agents를 사용한 자율주행 연구는 가상 환경에서 자율주행 에이전트를 훈련하는 것을 목표로 합니다. 현실 세계의 위험과 비용 없이 다양한 주행 시나리오를 시뮬레이션할 수 있습니다.

### 5.1.2 환경 구성 요소

```
┌─────────────────────────────────────────┐
│          자율주행 시뮬레이션 환경          │
│                                         │
│  ┌─────────────┐   ┌────────────────┐   │
│  │  도로 네트워크  │   │  차량 에이전트   │   │
│  │  (직선/곡선/    │   │  (센서+제어기)   │   │
│  │   교차로 등)   │   │                │   │
│  └─────────────┘   └────────────────┘   │
│                                         │
│  ┌─────────────┐   ┌────────────────┐   │
│  │  장애물/차량  │   │  교통 규칙/시뮬  │   │
│  │  (동적/정적)  │   │  (신호등/표지판) │   │
│  └─────────────┘   └────────────────┘   │
└─────────────────────────────────────────┘
```

### 5.1.3 실제 구현 사례

#### 사례 1: Autonomous Car Unity ML-Agents (GitHub: Amit-1216)

**특징:**
- PPO 기반 자율주행 자동차
- 5개 Ray Perception으로 장애물 감지
- 보상 시스템: 전진 +0.0015, 측면 이동 -0.002, 충돌 -2.0
- 실시간 HUD (속도, 조향각, 보상, 랩 카운트)

**관측 공간:**
| 인덱스 | 관측 | 설명 |
|--------|------|------|
| 1 | Speed | 속도 정규화 |
| 2 | Local Velocity X | 측면 속도 |
| 3 | Local Velocity Z | 전방 속도 |
| 4-8 | Ray distances | 5개 레이 거리 |

**액션 공간 (연속):**
| 인덱스 | 액션 | 범위 |
|--------|------|------|
| 0 | 조향 (좌/우) | -1 ~ 1 |
| 1 | 가속 | -1 ~ 1 |
| 2 | 브레이크 | 0 ~ 1 |

#### 사례 2: NeoRacer-RL (Neobotics Foundation)

- Jetson Orin Nano 기반 실제 자율주행 로봇 연계
- Unity 시뮬레이션 → 실제 로봇 전이 학습 (Sim-to-Real)
- PPO + 모방 학습 결합
- NVIDIA Inception Program 지원

### 5.1.4 환경 구축 단계

```csharp
// 자율주행 에이전트 기본 구조
public class CarAgent : Agent
{
    [SerializeField] private float maxSpeed = 10f;
    private Rigidbody rb;
    private float currentLapTime = 0f;

    public override void Initialize()
    {
        rb = GetComponent<Rigidbody>();
    }

    public override void CollectObservations(VectorSensor sensor)
    {
        // 속도 정보
        sensor.AddObservation(rb.velocity.magnitude / maxSpeed);
        sensor.AddObservation(rb.velocity.normalized);
        
        // 차량 방향
        sensor.AddObservation(transform.forward);
        sensor.AddObservation(transform.right);
        
        // Ray Perception은 컴포넌트로 처리
    }

    public override void OnActionReceived(ActionBuffers actions)
    {
        // 스티어링, 가속, 브레이크 처리
        float steer = Mathf.Clamp(actions.ContinuousActions[0], -1f, 1f);
        float throttle = Mathf.Clamp(actions.ContinuousActions[1], 0f, 1f);
        float brake = Mathf.Clamp(actions.ContinuousActions[2], 0f, 1f);
        
        // 차량 물리 적용
        // ...
        
        // 전진 보상
        float forwardSpeed = Vector3.Dot(rb.velocity, transform.forward);
        AddReward(forwardSpeed * 0.0015f);
        
        // 측면 이동 패널티
        float lateralSpeed = Vector3.Dot(rb.velocity, transform.right);
        AddReward(-Mathf.Abs(lateralSpeed) * 0.002f);
    }

    private void OnCollisionEnter(Collision collision)
    {
        if (collision.gameObject.CompareTag("Obstacle"))
        {
            AddReward(-2.0f);
            EndEpisode();
        }
    }
}
```

### 5.1.5 자율주행 학습 설정

```yaml
behaviors:
  AutonomousCar:
    trainer_type: ppo
    hyperparameters:
      batch_size: 1024
      buffer_size: 10240
      learning_rate: 3.0e-4
      beta: 0.01
      epsilon: 0.2
      lambd: 0.95
      num_epoch: 3
    network_settings:
      normalize: true
      hidden_units: 256
      num_layers: 3
    reward_signals:
      extrinsic:
        gamma: 0.99
        strength: 1.0
    max_steps: 2.0e7
    time_horizon: 1000
    summary_freq: 10000
```

---

## 5.2 ML-Agents를 이용한 유튜브 사례

### 5.2.1 주요 YouTube 채널 및 튜토리얼

#### 1. Immersive Limit (Adam Kelly)
- **채널**: https://www.youtube.com/@ImmersiveLimit
- **인기 시리즈**:
  - Unity ML-Agents Tutorial - Penguins (2시간 24분, 63K views)
  - Collaborative ML-Agents Devlog Series (5부작)
  - Camera Vision (22분) - 시각 관측 학습
  - ML-Agents Release 10 Walkthrough (초보자 가이드)
- **특징**: 가장 체계적인 ML-Agents 튜토리얼 제작자
- **커리큘럼**: 기초 설정부터 고급 멀티 에이전트까지

#### 2. Code Monkey
- **비디오**: "How to use Machine Learning AI in Unity! (ML-Agents)"
- **특징**: Unity 게임 개발에 ML-Agents를 실용적으로 적용
- **스타일**: 게임 개발자 관점에서의 접근

#### 3. Dilmer Valecillos
- **비디오**: "Get Started with ML-Agents in Unity" 시리즈
- **파트 1**: 설치 및 설정 (2022)
- **파트 2**: 기본 개념
- **특징**: 단계별 실습 중심

#### 4. 기타 흥미로운 프로젝트 영상
- **Angry AI v3 - Battle Robots** (mbaske): 로봇 전투 멀티 에이전트
- **Attack of the Clones - Motorcycle Racing**: 오토바이 경주
- **Deep Learning Dogfight**: 전투기 시뮬레이션
- **Deep Learning Hoverbike Race**: 호버바이크 경주
- **Robot Ants v3**: 군집 로봇 행동

### 5.2.2 학습 자료 추천 순서

| 단계 | YouTube 리소스 | 소요 시간 |
|------|---------------|-----------|
| 1 | Get Started with ML-Agents (Dilmer) | 30분 |
| 2 | Unity ML-Agents Release 10 Overview (Immersive Limit) | 1시간 |
| 3 | ML-Agents: Penguins Full Walkthrough (Immersive Limit) | 2.5시간 |
| 4 | Camera Vision (Immersive Limit) | 22분 |
| 5 | Collaborative ML-Agents Devlog (Immersive Limit) | 2시간 |

---

## 5.3 산업 문제에 ML-Agents 적용 사례

### 5.3.1 로보틱스 (Robotics)

**사례: Sim-to-Real 전이 학습**

Unity ML-Agents를 로봇 공학에 적용하는 가장 활발한 분야입니다.

| 프로젝트 | 설명 | 주요 기술 |
|----------|------|-----------|
| **Unity Robotics Hub** | Unity 공식 로봇공학 저장소 | ML-Agents + ROS |
| **Articulation Robot Demo** | 관절 로봇 팔 제어 | PPO, 연속 제어 |
| **UR5 Pick and Place** | 산업용 로봇 팔 훈련 | 시각 관측, 모방 학습 |

**참고 저장소**: https://github.com/Unity-Technologies/Unity-Robotics-Hub

### 5.3.2 물류 및 최적화 (Logistics & Optimization)

**사례: 창고 로봇 군집 제어**
- 여러 로봇이 협력하여 물품 분류 및 운반
- MA-POCA 알고리즘으로 팀 단위 학습
- 충돌 회피 및 경로 최적화

### 5.3.3 제조 공정 최적화

**사례: 조립 라인 최적화**
- 다중 에이전트가 협력하여 제품 조립
- 각 에이전트가 특정 작업 담당
- Curriculum Learning으로 단계별 난이도 증가

### 5.3.4 교통 및 물류 시뮬레이션

**사례: 다중 에이전트 교통 시뮬레이션**
- 각 차량이 개별 에이전트로 학습
- 신호등 최적화를 통한 교통 흐름 개선
- 긴급 차량 우선 통행 등 특수 상황 학습

### 5.3.5 의료 및 헬스케어

**사례: 수술 시뮬레이션**
- 가상 환경에서 수술 로봇 훈련
- 실제 환자 데이터 기반 시나리오
- 안전한 환경에서의 반복 학습

---

## 5.4 상용 게임에 ML-Agents 적용 사례

### 5.4.1 게임 AI 테스트 및 QA

**사례: 자동화된 게임 테스트**
- ML-Agents를 사용한 버그 탐지
- 플레이어 행동 모방을 통한 테스트 커버리지 확장
- 다양한 게임 시나리오 자동 탐색

### 5.4.2 NPC 행동 제어

**사례: 지능형 적 AI**
- PPO로 훈련된 적 캐릭터 (FPS, RPG)
- 플레이어 실력에 맞춰 동적 난이도 조절
- 팀워크를 갖춘 적 그룹 행동

### 5.4.3 게임 디자인 평가

**사례: 레벨 밸런싱**
- 에이전트가 레벨을 플레이하며 난이도 평가
- 데이터 기반 게임 디자인 의사 결정
- 다양한 레이아웃 자동 테스트

### 5.4.4 실제 상용 게임 사례

#### 사례 1: 좀비 서바이벌 게임
- ML-Agents로 좀비 AI 훈련
- 플레이어를 포위하고 협공하는 전략 학습
- 다양한 환경(도시, 숲, 건물 내부)에 대응

#### 사례 2: 전략 게임 유닛 제어
- 각 유닛이 독립적인 에이전트로 동작
- 팀 단위 전술 학습 (MA-POCA)
- 자원 관리와 전투 전략 동시 최적화

#### 사례 3: 스포츠 게임
- 축구/FPS 게임의 팀 AI
- Self-Play로 훈련된 상대 팀
- 실제 인간 플레이어와 유사한 전략 구사

### 5.4.5 상용 게임 적용 팁

1. **Inference Engine 사용**: ONNX로 모델 변환 후 Unity Inference Engine으로 실행
2. **Behavior Type 관리**: 
   - 개발 중: `Default` (Python 통신)
   - 출시: `Inference Only` (내장 모델)
3. **모델 최적화**: 
   - `hidden_units` 최소화 (성능 최적화)
   - 필요 없는 레이어 제거
   - ONNX 런타임 최적화 활용
4. **실시간 성능**: 게임 프레임 속도에 영향 주지 않도록 모델 크기 제한

### 5.4.6 커뮤니티 프로젝트

Unity Discussions의 "Post Your ML-Agents Project" 스레드에서 다양한 커뮤니티 프로젝트 확인 가능:
- **Angry AI v3 - Battle Robots**: 전투 로봇 멀티 에이전트
- **ML Motorcycles**: 오토바이 경주 AI
- **ML Dogfight**: 전투기 도그파이트
- **Robot Ants v3**: 군집 로봇 시뮬레이션
- **ML Hover Bike Race**: 호버바이크 경주

> **참고**: 위 프로젝트들은 GitHub에서 소스코드를 확인할 수 있습니다.

---

# 부록

## A. 유용한 명령어 모음

```bash
# ==========================================
# Conda 환경 관리
# ==========================================

# 환경 생성 및 활성화
conda create -n mlagents_env python=3.10 -y
conda activate mlagents_env

# environment.yml로 생성 (재현 가능)
conda env create -f environment_mlagents.yml
conda activate mlagents_env

# 환경 업데이트 (yml 변경 시)
conda env update -f environment_mlagents.yml --prune

# 환경 내보내기
conda env export -n mlagents_env > environment_backup.yml          # 전체 (플랫폼 종속)
conda env export -n mlagents_env --from-history > environment.yml  # 간소화

# 환경 복제
conda create -n mlagents_backup --clone mlagents_env

# 환경 목록
conda info --envs
conda env list

# 환경 제거
conda deactivate
conda env remove -n mlagents_env

# Conda 자체 관리
conda update conda -n base -c conda-forge
conda clean --all

# Mamba (빠른 대안)
conda install mamba -n base -c conda-forge
mamba env create -f environment_mlagents.yml

# ==========================================
# ML-Agents 학습 실행
# ==========================================
mlagents-learn <config> --run-id=<id> [--num-envs=N] [--resume] [--force]

# ==========================================
# TensorBoard 모니터링
# ==========================================
tensorboard --logdir=results

# ==========================================
# ONNX 모델 확인
# ==========================================
python -c "import onnx; model = onnx.load('model.onnx'); onnx.checker.check_model(model)"

# ==========================================
# 설치된 버전 확인
# ==========================================
pip show mlagents
pip show mlagents-envs
conda list -n mlagents_env | findstr -E "torch|cudatoolkit|mlagents"   # Windows
conda list -n mlagents_env | grep -E "torch|cudatoolkit|mlagents"      # Linux/macOS
python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}')"
```

## B. 참고 자료

| 자료 | 링크 |
|------|------|
| ML-Agents GitHub | https://github.com/Unity-Technologies/ml-agents |
| Release 23 소스 | https://github.com/Unity-Technologies/ml-agents/tree/release_23 |
| Unity 패키지 문서 | https://docs.unity3d.com/Packages/com.unity.ml-agents@4.0/manual/index.html |
| ML-Agents DodgeBall | https://github.com/Unity-Technologies/ml-agents-dodgeball-env |
| Unity Robotics Hub | https://github.com/Unity-Technologies/Unity-Robotics-Hub |
| Hugging Face ML-Agents | https://huggingface.co/unity |
| DeepWiki 코드 분석 | https://deepwiki.com/Unity-Technologies/ml-agents |

## C. PPO 하이퍼파라미터 퀵 레퍼런스

```
[간단한 환경]
batch_size: 1024 | buffer_size: 10240 | hidden_units: 128 | num_layers: 2

[중간 환경]
batch_size: 2048 | buffer_size: 20480 | hidden_units: 256 | num_layers: 2

[복잡한 환경]
batch_size: 4096 | buffer_size: 65536 | hidden_units: 512 | num_layers: 3
```

---

> **문서 작성일**: 2026년 6월 9일  
> **ML-Agents 최신 버전**: Release 23 (2025년 8월 28일)  
> **다음 업데이트 예정**: Release 24 이상의 변경사항이 있을 경우 문서 업데이트
