# FF2_Fork

This was created for my personal TF2 server.

Unfortunately, I don't have time and knowledge enough, To write something in English.

PR or issues are always welcome. Thank you.

-------
POTRY 서버에서 사용 중인 Freak Fortress 2의 포크 버전입니다.

------
#### Codespace 사용

0. [SourceMod 익스텐션](https://marketplace.visualstudio.com/items?itemName=Sarrus.sourcepawn-vscode)을 설치해주세요.
ㄴ 모든 설정은 본 저장소의 `.vscode` 폴더 안에 있습니다. 개인적인 설정은 저기서 수정하실 수 있답니다.

1. VSCode의 터미널을 켜고 배치 스크립트 실행 권한을 바꿔주세요.

  `$ sudo chmod +x /workspaces/FF2_Fork/batch/*.sh`

2. 소스모드, 기타 include를 설치해주세요.
  
  `$ /workspaces/FF2_Fork/batch/update-all.sh`

3. FF2도 설치해주세요. 
ㄴ 이후에 저장소 (`/addons/sourcemod/scripting`) 내의 `/ff2_module', '/include' 폴더 안에서 변경사항이 있었을 경우, 빌드 전에 미리 업데이트 해야 합니다.

  `$ /workspaces/FF2_Fork/batch/update-ff2.sh`

4. 원하는 코드를 선택하고 SourceMod 익스텐션의 컴파일 기능으로 빌드해보세요. (우측 상단에 버튼이 있답니다.)
ㄴ 정상적으로 빌드되었다면 저장소 내의 `/bin` 폴더 내에 플러그인 파일이 생성됩니다.

