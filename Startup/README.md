# Startup 예제 가이드

## 1. 개요

Startup은 ML-Agents 환경 실행 시 초기 씬 로딩을 담당하는 유틸리티입니다.
이것은 학습 환경이 아니라, 명령줄 인수나 환경 변수를 통해 실행할 씬을
지정하는 간단한 스크립트입니다. ML-Agents 예제들 중 유일하게
Agent를 상속받지 않는 코드입니다.

**목적**: 실행할 씬 이름을 환경 변수 또는 CLI 인수로부터 읽어와 로드

---

## 2. 코드 분석

### 2.1 Startup.cs

```csharp
namespace Unity.MLAgentsExamples
{
    internal class Startup : MonoBehaviour
    {
        const string k_SceneVariableName = "SCENE_NAME";
        const string k_SceneCommandLineFlag = "--mlagents-scene-name";

        void Awake()
        {
            var sceneName = "";
            var args = Environment.GetCommandLineArgs();
            Console.WriteLine("Command line arguments passed: " + String.Join(" ", args));

            // 1. 명령줄 인수 확인
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == k_SceneCommandLineFlag && i < args.Length - 1)
                {
                    sceneName = args[i + 1];
                }
            }

            // 2. 환경 변수 확인 (CLI 인수보다 우선)
            var sceneEnvironmentVariable = Environment.GetEnvironmentVariable(k_SceneVariableName);
            if (!string.IsNullOrEmpty(sceneEnvironmentVariable))
            {
                sceneName = sceneEnvironmentVariable;
            }

            SwitchScene(sceneName);
        }

        static void SwitchScene(string sceneName)
        {
            if (sceneName == null)
            {
                Console.WriteLine($"You didn't specify the {k_SceneVariableName} environment variable or the {k_SceneCommandLineFlag} command line argument.");
                Application.Quit(22);
                return;
            }
            if (SceneUtility.GetBuildIndexByScenePath(sceneName) < 0)
            {
                Console.WriteLine($"The scene {sceneName} doesn't exist within your build.");
                Application.Quit(22);
                return;
            }
            SceneManager.LoadSceneAsync(sceneName);
        }
    }
}
```

### 2.2 동작 흐름

```
애플리케이션 실행
      │
      ▼
  Awake() 호출
      │
      ├─── 명령줄 인수 확인 (--mlagents-scene-name)
      │         │
      │         ▼
      │    sceneName = args[i+1]
      │
      ├─── 환경 변수 확인 (SCENE_NAME)
      │         │
      │         ▼
      │    sceneName = envVar (CLI보다 우선)
      │
      ▼
  SwitchScene(sceneName)
      │
      ├─── sceneName == null → 종료 (exit code 22)
      ├─── 씬이 빌드에 없음 → 종료 (exit code 22)
      └─── 정상 → SceneManager.LoadSceneAsync()
```

### 2.3 사용 방법

**CLI 인수 사용**:
```bash
MyApp.exe --mlagents-scene-name Assets/ML-Agents/Examples/3DBall/Scenes/3DBall.unity
```

**환경 변수 사용**:
```bash
# PowerShell
$env:SCENE_NAME = "Assets/ML-Agents/Examples/3DBall/Scenes/3DBall.unity"
MyApp.exe

# CMD
set SCENE_NAME=Assets/ML-Agents/Examples/3DBall/Scenes/3DBall.unity
MyApp.exe
```

**우선순위**: 환경 변수 > CLI 인수

---

## 3. 학습 실행

Startup 예제는 학습 환경이 아닌 인프라 코드이므로 별도의 학습 명령어는 없습니다.
대신 ML-Agents 예제 실행 시 다음과 같이 활용됩니다:

```bash
mlagents-learn --env=MyApp --run-id=Test1
```

위 명령어는 내부적으로 `--mlagents-scene-name` 인수를 전달하여
Startup 스크립트가 원하는 씬을 로드하도록 합니다.

---

## 4. 실습 과제

### 과제 1: SCENE_NAME 환경 변수 테스트
- 환경 변수 없이 실행 → Application.Quit(22) 확인
- 환경 변수 설정 후 실행 → 올바른 씬 로드 확인

### 과제 2: 오류 처리 강화
- 잘못된 씬 이름에 대한 더 자세한 오류 메시지 추가
- 사용 가능한 씬 목록을 로그로 출력하는 기능 추가

### 과제 3: 기본 씬 추가
- 씬 이름이 제공되지 않았을 때 로드할 기본 씬 설정
- `--help` 또는 `-h` 플래그 처리 추가

### 과제 4: 멀티 씬 지원
- 여러 씬을 순차적으로 로드하는 기능 추가
- 씬 리스트를 JSON 파일에서 읽어오는 방식

---

## 5. 전체 파일 구조와 각 파일의 의미

```
Startup/
├── Scenes/
│   └── Startup.unity                            # (1) 유일한 씬
│
├── Scripts/
│   └── Startup.cs                               # (2) 씬 로더 유틸리티
│
└── Prefabs/
    └── Startup.prefab                           # (3) 프리팹
```

---

### (1) `Scenes/Startup.unity` — 유일한 씬

**씬 계층 구조**:
```
Startup.unity
├── Main Camera
├── Startup
│   └── Startup (Startup.cs)
└── EventSystem
```

가장 단순한 씬입니다. 씬에는 Startup 스크립트가 붙은 오브젝트 하나만 존재하며,
이 스크립트가 `Awake()`에서 실행할 씬을 결정합니다.

**모든 ML-Agents 예제가 이 씬을 첫 번째 빌드 인덱스로 사용**합니다.
빌드된 실행 파일이 실행되면 Startup 씬이 가장 먼저 로드되고,
즉시 설정된 타겟 씬으로 전환됩니다.

### (2) `Scripts/Startup.cs` — 씬 로더 유틸리티

ML-Agents 예제 중 **유일하게 Agent를 상속받지 않는** 스크립트입니다.

```csharp
internal class Startup : MonoBehaviour
{
    const string k_SceneVariableName = "SCENE_NAME";
    const string k_SceneCommandLineFlag = "--mlagents-scene-name";

    void Awake()
    {
        sceneName = GetSceneName();
        SwitchScene(sceneName);
    }
}
```

**동작 흐름**:
```
1. 명령줄 인수 확인 (--mlagents-scene-name)
2. 환경 변수 확인 (SCENE_NAME) ← CLI보다 우선
3. sceneName이 null → Application.Quit(22)
4. 씬이 빌드에 없음 → Application.Quit(22)  
5. 정상 → SceneManager.LoadSceneAsync(sceneName)
```

| 우선순위 | 출처 | 예시 |
|----------|------|------|
| 1위 (높음) | 환경 변수 `SCENE_NAME` | `$env:SCENE_NAME = "..."` |
| 2위 (낮음) | CLI 인수 `--mlagents-scene-name` | `MyApp.exe --mlagents-scene-name "..."` |

### (3) `Prefabs/Startup.prefab` — 프리팹

Startup 스크립트를 포함한 간단한 프리팹입니다.
ML-Agents 빌드 시 자동으로 포함됩니다.

---

## 6. 핵심 포인트

- ML-Agents 예제 중 **유일하게 Agent를 상속받지 않는** 스크립트
- 명령줄 인수(`--mlagents-scene-name`)와 환경 변수(`SCENE_NAME`) 지원
- 환경 변수가 CLI 인수보다 우선순위가 높음
- 잘못된 씬 이름이나 누락 시 exit code 22로 종료
- `SceneManager.LoadSceneAsync()`로 비동기 씬 로드
- ML-Agents 학습 실행 시 자동으로 활용되는 인프라 코드
