use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use tauri::{AppHandle, Manager};
use tauri_plugin_shell::process::{Command, CommandEvent};
use tauri_plugin_shell::ShellExt;

const CLOUD_STORAGE_FORMAT: &str = "DiamondSoulSteamCloudStorage";
const CLOUD_STORAGE_LIMIT: usize = 16 * 1024 * 1024;
const CLOUD_SAVE_PREFIXES: [&str; 3] = [
    "diamond-soul.pitcher-lab.autosave.",
    "diamond-soul.high-school-career.autosave.",
    "diamond-soul.pro-career.autosave.",
];

fn is_cloud_save_key(key: &str) -> bool {
    CLOUD_SAVE_PREFIXES
        .iter()
        .any(|prefix| key.starts_with(prefix))
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct CloudStoragePayload {
    format: String,
    schema_version: u32,
    values: BTreeMap<String, String>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct CloudStorageFile {
    format: String,
    schema_version: u32,
    revision: u64,
    values: BTreeMap<String, String>,
}

fn validate_payload(contents: &str) -> Result<CloudStoragePayload, String> {
    if contents.len() > CLOUD_STORAGE_LIMIT {
        return Err("save data exceeds the 16 MB limit".to_owned());
    }
    let payload: CloudStoragePayload = serde_json::from_str(contents)
        .map_err(|error| format!("save data is not valid JSON: {error}"))?;
    if payload.format != CLOUD_STORAGE_FORMAT || payload.schema_version != 1 {
        return Err("save data has an unsupported format".to_owned());
    }
    if payload.values.len() > 512
        || payload
            .values
            .iter()
            .any(|(key, _)| !is_cloud_save_key(key) || key.len() > 256)
    {
        return Err("save data contains an invalid key".to_owned());
    }
    Ok(payload)
}

fn read_slot(path: &Path) -> Option<CloudStorageFile> {
    let mut file = File::open(path).ok()?;
    let length = file.metadata().ok()?.len() as usize;
    if length > CLOUD_STORAGE_LIMIT {
        return None;
    }
    let mut contents = String::with_capacity(length);
    file.read_to_string(&mut contents).ok()?;
    let value: CloudStorageFile = serde_json::from_str(&contents).ok()?;
    if value.format != CLOUD_STORAGE_FORMAT
        || value.schema_version != 1
        || value
            .values
            .keys()
            .any(|key| !is_cloud_save_key(key) || key.len() > 256)
    {
        return None;
    }
    Some(value)
}

fn cloud_slots(directory: &Path) -> [PathBuf; 2] {
    [
        directory.join("steam-cloud-a.json"),
        directory.join("steam-cloud-b.json"),
    ]
}

fn load_cloud_storage_at(directory: &Path) -> Result<Option<String>, String> {
    let newest = cloud_slots(directory)
        .iter()
        .filter_map(|path| read_slot(path))
        .max_by_key(|value| value.revision);
    let Some(value) = newest else { return Ok(None) };
    serde_json::to_string(&CloudStoragePayload {
        format: value.format,
        schema_version: value.schema_version,
        values: value.values,
    })
    .map(Some)
    .map_err(|error| format!("failed to encode save data: {error}"))
}

fn write_cloud_storage_at(directory: &Path, contents: &str) -> Result<(), String> {
    let payload = validate_payload(contents)?;
    fs::create_dir_all(directory)
        .map_err(|error| format!("failed to create save directory: {error}"))?;
    let slots = cloud_slots(directory);
    let revisions = [
        read_slot(&slots[0]).map(|value| value.revision),
        read_slot(&slots[1]).map(|value| value.revision),
    ];
    let next_revision = revisions.iter().flatten().max().copied().unwrap_or(0) + 1;
    let target_index = match revisions {
        [None, _] => 0,
        [_, None] => 1,
        [Some(a), Some(b)] if a <= b => 0,
        _ => 1,
    };
    let value = CloudStorageFile {
        format: payload.format,
        schema_version: payload.schema_version,
        revision: next_revision,
        values: payload.values,
    };
    let encoded = serde_json::to_vec(&value)
        .map_err(|error| format!("failed to encode save data: {error}"))?;
    let temporary = directory.join(format!("steam-cloud-{}.tmp", target_index));
    if temporary.exists() {
        fs::remove_file(&temporary)
            .map_err(|error| format!("failed to remove stale temporary save: {error}"))?;
    }
    let mut file = File::create(&temporary)
        .map_err(|error| format!("failed to create temporary save: {error}"))?;
    file.write_all(&encoded)
        .and_then(|_| file.sync_all())
        .map_err(|error| format!("failed to write temporary save: {error}"))?;
    if slots[target_index].exists() {
        fs::remove_file(&slots[target_index])
            .map_err(|error| format!("failed to rotate old save: {error}"))?;
    }
    fs::rename(&temporary, &slots[target_index])
        .map_err(|error| format!("failed to commit save: {error}"))?;
    Ok(())
}

fn cloud_storage_directory(app: &AppHandle) -> Result<PathBuf, String> {
    app.path()
        .app_data_dir()
        .map(|path| path.join("steam-cloud"))
        .map_err(|error| format!("failed to locate the user data directory: {error}"))
}

fn core_command(app: &AppHandle) -> Result<Command, String> {
    let command = app
        .shell()
        .sidecar("simulation-sidecar")
        .map_err(|error| format!("failed to prepare simulation core: {error}"))?;

    #[cfg(windows)]
    {
        let runtime = app
            .path()
            .resource_dir()
            .map_err(|error| format!("failed to locate application resources: {error}"))?
            .join("swift-runtime");
        if !runtime.join("swiftCore.dll").is_file() {
            return Err(format!(
                "Swift runtime is missing from the application package: {}",
                runtime.display()
            ));
        }
        let mut paths = vec![runtime];
        if let Some(current) = std::env::var_os("PATH") {
            paths.extend(std::env::split_paths(&current));
        }
        let path = std::env::join_paths(paths)
            .map_err(|error| format!("failed to prepare Swift runtime path: {error}"))?;
        return Ok(command.env("PATH", path));
    }

    #[cfg(not(windows))]
    Ok(command)
}

async fn run_core_request(app: &AppHandle, request: &str) -> Result<String, String> {
    let command = core_command(app)?;
    let (mut events, mut child) = command
        .spawn()
        .map_err(|error| format!("failed to execute simulation core: {error}"))?;
    child
        .write(format!("{request}\n").as_bytes())
        .map_err(|error| format!("failed to write simulation request: {error}"))?;

    let mut stderr = String::new();
    while let Some(event) = events.recv().await {
        match event {
            CommandEvent::Stdout(bytes) => {
                child
                    .kill()
                    .map_err(|error| format!("failed to stop simulation core: {error}"))?;
                return String::from_utf8(bytes)
                    .map(|value| value.trim().to_owned())
                    .map_err(|error| format!("simulation core returned invalid UTF-8: {error}"));
            }
            CommandEvent::Stderr(bytes) => {
                stderr.push_str(&String::from_utf8_lossy(&bytes));
            }
            CommandEvent::Error(error) => {
                let _ = child.kill();
                return Err(format!("simulation core stream failed: {error}"));
            }
            CommandEvent::Terminated(status) => {
                let detail = stderr.trim();
                return Err(if detail.is_empty() {
                    format!(
                        "simulation core exited before responding: {:?}",
                        status.code
                    )
                } else {
                    detail.to_owned()
                });
            }
            _ => {}
        }
    }

    let _ = child.kill();
    Err("simulation core closed without a response".to_owned())
}

#[tauri::command]
async fn execute_core(app: AppHandle, request: String) -> Result<String, String> {
    run_core_request(&app, &request).await
}

#[tauri::command]
fn load_cloud_storage(app: AppHandle) -> Result<Option<String>, String> {
    load_cloud_storage_at(&cloud_storage_directory(&app)?)
}

#[tauri::command]
fn write_cloud_storage(app: AppHandle, contents: String) -> Result<(), String> {
    write_cloud_storage_at(&cloud_storage_directory(&app)?, &contents)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            execute_core,
            load_cloud_storage,
            write_cloud_storage
        ])
        .setup(|app| {
            let handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                let request = r#"{"jsonrpc":"2.0","id":"startup-health","method":"health"}"#;
                match run_core_request(&handle, request).await {
                    Ok(response) => println!("simulation core ready: {response}"),
                    Err(error) => eprintln!("simulation core unavailable: {error}"),
                }
            });
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running Project Diamond Soul");
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn temporary_directory(name: &str) -> PathBuf {
        let unique = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system clock")
            .as_nanos();
        std::env::temp_dir().join(format!(
            "diamond-soul-{name}-{}-{unique}",
            std::process::id()
        ))
    }

    fn payload(value: &str) -> String {
        serde_json::json!({
            "format": CLOUD_STORAGE_FORMAT,
            "schemaVersion": 1,
            "values": { "diamond-soul.pro-career.autosave.v1": value }
        })
        .to_string()
    }

    #[test]
    fn cloud_storage_rotates_two_valid_slots_and_loads_newest() {
        let directory = temporary_directory("rotation");
        write_cloud_storage_at(&directory, &payload("first")).expect("first write");
        write_cloud_storage_at(&directory, &payload("second")).expect("second write");

        let loaded = load_cloud_storage_at(&directory)
            .expect("load")
            .expect("stored payload");
        let value: CloudStoragePayload = serde_json::from_str(&loaded).expect("valid payload");
        assert_eq!(value.values["diamond-soul.pro-career.autosave.v1"], "second");
        assert!(cloud_slots(&directory).iter().all(|path| path.is_file()));

        fs::remove_dir_all(directory).expect("cleanup");
    }

    #[test]
    fn cloud_storage_recovers_the_other_slot_when_newest_is_corrupt() {
        let directory = temporary_directory("recovery");
        write_cloud_storage_at(&directory, &payload("first")).expect("first write");
        write_cloud_storage_at(&directory, &payload("second")).expect("second write");
        let slots = cloud_slots(&directory);
        let newest = slots
            .iter()
            .max_by_key(|path| read_slot(path).map(|value| value.revision).unwrap_or(0))
            .expect("newest slot");
        fs::write(newest, b"corrupt").expect("corrupt newest");

        let loaded = load_cloud_storage_at(&directory)
            .expect("load")
            .expect("backup payload");
        let value: CloudStoragePayload = serde_json::from_str(&loaded).expect("valid payload");
        assert_eq!(value.values["diamond-soul.pro-career.autosave.v1"], "first");

        fs::remove_dir_all(directory).expect("cleanup");
    }

    #[test]
    fn cloud_storage_rejects_unmanaged_keys() {
        let directory = temporary_directory("invalid-key");
        let invalid = serde_json::json!({
            "format": CLOUD_STORAGE_FORMAT,
            "schemaVersion": 1,
            "values": { "another-app.save": "value" }
        })
        .to_string();
        assert!(write_cloud_storage_at(&directory, &invalid).is_err());
        assert!(!directory.exists());
    }
}
