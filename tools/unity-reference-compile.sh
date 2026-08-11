#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
unity_version="${BASEBALL_UNITY_VERSION:-6000.3.19f1}"
unity_app="${BASEBALL_UNITY_APP:-/Applications/Unity/Hub/Editor/${unity_version}/Unity.app}"
managed_root="${unity_app}/Contents/Resources/Scripting/Managed/UnityEngine"
nunit_dll="${unity_app}/Contents/Resources/PackageManager/BuiltInPackages/com.unity.ext.nunit/net40/unity-custom/nunit.framework.dll"
template_root="${unity_app}/Contents/Resources/PackageManager/ProjectTemplates"
project="${repo_root}/tools/unity-reference-compile/Baseball.UnityReferenceCompile.csproj"
core_project="${repo_root}/tools/unity-reference-compile/Baseball.Core.ReferenceCompile.csproj"
platform_project="${repo_root}/tools/unity-reference-compile/Baseball.Platform.ReferenceCompile.csproj"
platform_tests_project="${repo_root}/tools/unity-reference-compile/Baseball.Platform.Tests.ReferenceCompile.csproj"
presentation_tests_project="${repo_root}/tools/unity-reference-compile/Baseball.Presentation.Tests.ReferenceCompile.csproj"
editor_project="${repo_root}/tools/unity-reference-compile/Baseball.UnityEditorReferenceCompile.csproj"
android_editor_dll="${unity_app%/Unity.app}/PlaybackEngines/AndroidPlayer/UnityEditor.Android.Extensions.dll"

if [[ ! -x "${unity_app}/Contents/MacOS/Unity" ]]; then
  echo "Unity ${unity_version} editor was not found at ${unity_app}." >&2
  exit 2
fi
if [[ ! -f "${managed_root}/UnityEngine.CoreModule.dll" ]]; then
  echo "Unity ${unity_version} managed reference assemblies are unavailable." >&2
  exit 2
fi
if [[ ! -f "${nunit_dll}" ]]; then
  echo "Unity ${unity_version} NUnit reference is unavailable." >&2
  exit 2
fi
if [[ ! -f "${android_editor_dll}" ]]; then
  echo "Unity ${unity_version} Android Editor extension is unavailable." >&2
  exit 2
fi

resolve_template_dll() {
  local name="$1"
  local resolved
  resolved="$(find "${template_root}" -type f -path "*/ScriptAssemblies/${name}" -print -quit 2>/dev/null || true)"
  if [[ -z "${resolved}" || ! -f "${resolved}" ]]; then
    echo "Unity template reference ${name} is unavailable under ${template_root}." >&2
    exit 2
  fi
  printf '%s' "${resolved}"
}

input_system_dll="$(resolve_template_dll Unity.InputSystem.dll)"
render_core_dll="$(resolve_template_dll Unity.RenderPipelines.Core.Runtime.dll)"
urp_dll="$(resolve_template_dll Unity.RenderPipelines.Universal.Runtime.dll)"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/baseball-unity-reference.XXXXXX")"
trap 'rm -rf "${scratch}"' EXIT

build_runtime_closure() {
  local label="$1"
  local internal_qa="$2"
  echo "Unity 6000.3 ${label} reference compile"
  dotnet build "${project}" \
    --configuration Release \
    --nologo \
    -p:BaseballRepositoryRoot="${repo_root}" \
    -p:UnityManaged="${managed_root}" \
    -p:UnityNUnitDll="${nunit_dll}" \
    -p:UnityInputSystemDll="${input_system_dll}" \
    -p:UnityRenderCoreDll="${render_core_dll}" \
    -p:UnityUrpDll="${urp_dll}" \
    -p:BaseballInternalQa="${internal_qa}" \
    -p:BaseIntermediateOutputPath="${scratch}/${label}/obj/" \
    -p:OutputPath="${scratch}/${label}/bin/"
}

build_runtime_closure production false
build_runtime_closure internal-qa true

# The closure builds catch cross-layer source errors. These separate builds also preserve the
# Platform asmdef boundary so its internal test seam must be granted to Baseball.Platform.Tests.
dotnet build "${core_project}" \
  --configuration Release \
  --nologo \
  -p:BaseballRepositoryRoot="${repo_root}" \
  -p:BaseIntermediateOutputPath="${scratch}/core-obj/" \
  -p:OutputPath="${scratch}/core-bin/"

dotnet build "${platform_project}" \
  --configuration Release \
  --nologo \
  -p:BaseballRepositoryRoot="${repo_root}" \
  -p:UnityManaged="${managed_root}" \
  -p:BaseballCoreDll="${scratch}/core-bin/Baseball.Core.dll" \
  -p:BaseIntermediateOutputPath="${scratch}/platform-obj/" \
  -p:OutputPath="${scratch}/platform-bin/"

dotnet build "${platform_tests_project}" \
  --configuration Release \
  --nologo \
  -p:BaseballRepositoryRoot="${repo_root}" \
  -p:UnityManaged="${managed_root}" \
  -p:UnityNUnitDll="${nunit_dll}" \
  -p:BaseballCoreDll="${scratch}/core-bin/Baseball.Core.dll" \
  -p:BaseballPlatformDll="${scratch}/platform-bin/Baseball.Platform.dll" \
  -p:BaseIntermediateOutputPath="${scratch}/platform-tests-obj/" \
  -p:OutputPath="${scratch}/platform-tests-bin/"

echo "Unity 6000.3 Presentation EditMode tests reference compile"
dotnet build "${presentation_tests_project}" \
  --configuration Release \
  --nologo \
  -p:BaseballRepositoryRoot="${repo_root}" \
  -p:UnityManaged="${managed_root}" \
  -p:UnityNUnitDll="${nunit_dll}" \
  -p:UnityInputSystemDll="${input_system_dll}" \
  -p:UnityRenderCoreDll="${render_core_dll}" \
  -p:UnityUrpDll="${urp_dll}" \
  -p:BaseIntermediateOutputPath="${scratch}/presentation-tests-obj/" \
  -p:OutputPath="${scratch}/presentation-tests-bin/"

echo "Unity 6000.3 Android Editor reference compile"
dotnet build "${editor_project}" \
  --configuration Release \
  --nologo \
  -p:BaseballRepositoryRoot="${repo_root}" \
  -p:UnityManaged="${managed_root}" \
  -p:UnityAndroidEditorDll="${android_editor_dll}" \
  -p:UnityRenderCoreDll="${render_core_dll}" \
  -p:UnityUrpDll="${urp_dll}" \
  -p:BaseIntermediateOutputPath="${scratch}/editor/obj/" \
  -p:OutputPath="${scratch}/editor/bin/"
