use tauri::AppHandle;
use tauri_plugin_shell::process::CommandEvent;
use tauri_plugin_shell::ShellExt;

async fn run_core_request(app: &AppHandle, request: &str) -> Result<String, String> {
    let command = app
        .shell()
        .sidecar("simulation-sidecar")
        .map_err(|error| format!("failed to prepare simulation core: {error}"))?;
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

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![execute_core])
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
