# Guía completa del proyecto

Este proyecto genera vídeos verticales de paisajes desde imágenes de ComfyUI, añade una pista de audio local y los pone en la cola de TikTok mediante Cloudinary y Buffer.

## Requisitos locales

- Windows 10, Node.js 24 o superior y n8n instalado localmente.
- GPU NVIDIA y ComfyUI Portable instalado por separado. El modelo probado fue SD 1.5 (`v1-5-pruned-emaonly-fp16.safetensors`), con 512 × 768 y batch size 1 para una GPU de 6 GB.
- Ollama con `gemma3:4b`, disponible en `http://127.0.0.1:11434`.
- FFmpeg con codificador H.264 (`libx264`). Si no se detecta automáticamente, configura `FFMPEG_EXE` en `.env`.
- Cuenta de Cloudinary y cuenta/canal de TikTok conectado a Buffer.

ComfyUI, modelos, n8n, Ollama y las credenciales son instalaciones/datos locales y no se incluyen en el repositorio.

## Estructura

```text
assets/audio/       pista de audio local (ignorada por Git)
assets/prompts/     prompts de referencia
scripts/            creación de MP4 y arranque local
videos/             resultados generados (ignorados por Git)
workflows/          workflow de ejemplo sanitizado para importar en n8n
.env.example        plantilla de configuración local
```

La carpeta de ComfyUI puede estar fuera del repositorio. `.env` permite configurar rutas sin escribirlas en scripts o documentación:

| Variable | Uso |
| --- | --- |
| `COMFYUI_DIR` | Raíz de ComfyUI Portable |
| `COMFYUI_OUTPUT_DIR` | Carpeta `ComfyUI/output` que contiene los PNG |
| `VIDEO_OUTPUT_DIR` | Destino de los MP4 |
| `AUDIO_FILE` | Pista local para el MP4 |
| `FFMPEG_EXE` | Ruta opcional al `ffmpeg.exe` completo |
| `NODES_EXCLUDE` | Ajuste de n8n para mantener habilitado Execute Command |

Al clonar el proyecto, copia `.env.example` a `.env`, revisa `COMFYUI_DIR` y añade el audio local a `assets/audio/`. No subas `.env`, audio, vídeos, logs, bases de datos ni archivos `pass*`.

## Arranque

1. Abre Ollama y asegúrate de que el modelo está descargado:

   ```powershell
   Invoke-RestMethod http://127.0.0.1:11434/api/tags
   ```

2. Desde la raíz del repositorio, inicia ComfyUI:

   ```powershell
   .\scripts\start-comfyui.ps1
   ```

   Abre [http://127.0.0.1:8188](http://127.0.0.1:8188), carga el workflow de SD 1.5 y guarda un PNG en la carpeta output indicada por `COMFYUI_OUTPUT_DIR`.

3. En otra ventana de PowerShell inicia n8n:

   ```powershell
   .\scripts\start-n8n.ps1
   ```

   Abre [http://localhost:5678](http://localhost:5678). El script prepara las variables de entorno de n8n para permitir `Execute Command` y permitir que el nodo de archivos lea `VIDEO_OUTPUT_DIR`.

4. Importa `workflows/n8n-video-tiktok.json` en n8n y revisa los marcadores de configuración antes de ejecutar.

## Configurar las integraciones al importar el workflow

- En el nodo de Cloudinary, sustituye `TU_CLOUD_NAME` por el cloud name de tu cuenta y `TU_UPLOAD_PRESET_UNSIGNED` por el nombre del preset unsigned. El preset permite subir archivos sin firma; conserva su valor en tu workflow local y no lo publiques.
- En el nodo de Buffer, sustituye `TU_TIKTOK_CHANNEL_ID` por el ID de tu canal y asigna la credencial Header Auth de Buffer desde **Credentials** en n8n. El valor de autenticación debe ser `Authorization: Bearer <API key>` y mantenerse en las credenciales internas de n8n.
- No exportes ni publiques credenciales de n8n. La exportación de ejemplo no incluye referencias a las credenciales privadas.
- En el nodo Execute Command, la ruta usa la variable `PROJECT_DIR` que configura `scripts/start-n8n.ps1`.

## Qué hace el workflow

1. Llama a Ollama para generar una idea/caption.
2. Ejecuta `scripts/crear-video.ps1`, que toma el PNG más reciente del output de ComfyUI.
3. Convierte la imagen en un MP4 H.264 vertical 1080 × 1920, 30 fps, 15 segundos, con zoom suave y los primeros 15 segundos de la pista local.
4. Lee el MP4, lo sube a Cloudinary y usa `secure_url` para crear un post con modo `addToQueue` en Buffer.

Cada ejecución completa añade una publicación real a la cola. Comprueba Buffer antes de repetir la ejecución. El MP4 debe permanecer accesible en Cloudinary hasta que Buffer lo publique. La pista se incorpora al archivo; TikTok no agrega la canción desde su biblioteca en este flujo. Publica solo audio que tengas derecho a usar.

## Crear el vídeo manualmente

Con Ollama y ComfyUI iniciados y un PNG disponible, desde PowerShell en la raíz:

```powershell
.\scripts\crear-video.ps1
```

El script imprime `VIDEO_CREADO=<ruta>` y guarda el MP4 bajo `VIDEO_OUTPUT_DIR`. Puedes indicar archivos explícitos:

```powershell
.\scripts\crear-video.ps1 -InputImage 'C:\ruta\a\imagen.png' -AudioFile 'C:\ruta\a\audio.mp3'
```

## Diagnóstico

- **Ollama no responde:** abre la aplicación y comprueba `/api/tags` en el puerto 11434.
- **ComfyUI no inicia:** revisa `COMFYUI_DIR` en `.env` y que exista `run_nvidia_gpu.bat`.
- **No aparece Execute Command:** detén n8n con Ctrl+C y vuelve a iniciarlo mediante `scripts/start-n8n.ps1`.
- **No encuentra imagen:** genera primero un PNG y comprueba `COMFYUI_OUTPUT_DIR`.
- **No encuentra FFmpeg/libx264:** instala una build completa de FFmpeg y define `FFMPEG_EXE` con la ruta a `ffmpeg.exe`.
- **n8n no puede leer el MP4:** confirma que arrancó con el script y que `VIDEO_OUTPUT_DIR` resuelve a la carpeta correcta.
- **Buffer dice que no pudo leer el vídeo:** abre `secure_url` en una ventana privada y revisa que el valor de `video.url` sea la URL completa. Cloudinary debe permitir acceso público al recurso.
- **Buffer devuelve un error de mutación:** revisa el ID del canal, las credenciales Header Auth y el error mostrado por la API; confirma el estado en Buffer antes de reintentar.

## Seguridad y archivos publicados

`.gitignore` excluye `.env`, archivos `pass*`, el audio, los MP4, logs, bases de datos locales y la exportación original de n8n. Revisa siempre `git status` antes de publicar. Si un token, contraseña o clave llegó a exponerse, revócalo y crea uno nuevo.
