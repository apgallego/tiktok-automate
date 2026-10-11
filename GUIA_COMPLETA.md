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
| `COMFYUI_URL` | Dirección local de la API de ComfyUI (por defecto `http://127.0.0.1:8188`) |
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

   Abre [http://127.0.0.1:8188](http://127.0.0.1:8188) y comprueba que puedes ejecutar el workflow de SD 1.5. El workflow exportado como API está en `workflows/workdlow-dfantasy.json`; n8n lo usa para enviar el prompt dinámico al nodo positivo y recoger el PNG generado.

3. En otra ventana de PowerShell inicia n8n:

   ```powershell
   .\scripts\start-n8n.ps1
   ```

   Abre [http://localhost:5678](http://localhost:5678). El script prepara las variables de entorno de n8n para permitir `Execute Command` y permitir que el nodo de archivos lea `VIDEO_OUTPUT_DIR`.

4. Importa `workflows/n8n-video-tiktok.json` en n8n y revisa los marcadores de configuración antes de ejecutar. Los cambios hechos al JSON local no aparecen en una copia del workflow ya abierta en n8n hasta que importes la versión actualizada.

`assets/prompts/prompt1.txt` conserva ejemplos para generar imágenes manualmente. En el workflow automático, Ollama propone un prompt y n8n se lo envía a ComfyUI usando `workflows/workdlow-dfantasy.json`. La dirección visual prioriza un paisaje Dark Fantasy amplio: el entorno debe llenar aproximadamente el 85–90 % del encuadre. Se incluye solo un detalle narrativo discreto (un caballero o hechicero pequeño, a media o larga distancia, o un artefacto integrado en el lugar); se evitan retratos y primeros planos. Ollama limita `video_prompt` a menos de 90 palabras y `scene` a menos de 25, y la llamada restringe la respuesta para reducir el riesgo de JSON truncado. Ollama no conserva memoria de ejecuciones anteriores, así que puede proponer una escena parecida ocasionalmente; el seed de ComfyUI sí cambia en cada ejecución.

## Configurar las integraciones al importar el workflow

- En el nodo de Cloudinary, sustituye `TU_CLOUD_NAME` por el cloud name de tu cuenta y `TU_UPLOAD_PRESET_UNSIGNED` por el nombre del preset unsigned. El preset permite subir archivos sin firma; conserva su valor en tu workflow local y no lo publiques.
- En el nodo de Buffer, sustituye `TU_TIKTOK_CHANNEL_ID` por el ID de tu canal y asigna la credencial Header Auth de Buffer desde **Credentials** en n8n. El valor de autenticación debe ser `Authorization: Bearer <API key>` y mantenerse en las credenciales internas de n8n.
- No exportes ni publiques credenciales de n8n. La exportación de ejemplo no incluye referencias a las credenciales privadas.
- En el nodo Execute Command, la ruta usa la variable `PROJECT_DIR` que configura `scripts/start-n8n.ps1`.

El nodo Execute Command del workflow actualizado recibe el prompt codificado del nodo `Preparar prompt para ComfyUI` y ejecuta `scripts/generar-comfy-video.ps1`. Si aparece un error de ruta, confirma que n8n se inició con `scripts/start-n8n.ps1` y que `%PROJECT_DIR%` apunta a la raíz del proyecto.

## Qué hace el workflow

1. Llama a Ollama para crear un prompt visual Dark Fantasy.
2. `Preparar prompt para ComfyUI` valida la respuesta JSON y la pasa al script local.
3. `scripts/generar-comfy-video.ps1` actualiza el nodo positivo 73 del workflow API, cambia el seed, envía la generación a ComfyUI y espera al PNG del nodo Save Image 78.
4. Ejecuta `scripts/crear-video.ps1` con ese PNG concreto y crea el MP4 H.264 vertical 1080 × 1920, 30 fps, 8 segundos, con un zoom de hasta el 36 %, paneo diagonal con deriva suave y fade out visual y de audio durante el último segundo. Usa los primeros 8 segundos de la pista local.
5. Lee el MP4, lo sube a Cloudinary y usa `secure_url` para crear un post con modo `addToQueue` en Buffer. El pie de foto configurado actualmente es fijo: `#darkfantasy #fantasiaoscura #misterio #mistery #fyp`.

Cada ejecución completa añade una publicación real a la cola. Comprueba Buffer antes de repetir la ejecución. El MP4 debe permanecer accesible en Cloudinary hasta que Buffer lo publique. La pista se incorpora al archivo; TikTok no agrega la canción desde su biblioteca en este flujo. Publica solo audio que tengas derecho a usar.

El clip usa una sola imagen y movimiento de cámara (zoom y paneo) para mantener bajo el coste de procesamiento. Ese movimiento no anima las nubes ni el agua por separado; el prompt busca que esos elementos estén presentes y que la composición funcione bien con la cámara.

## Crear el vídeo manualmente

Con ComfyUI iniciado y un PNG nuevo disponible, desde PowerShell en la raíz:

```powershell
.\scripts\crear-video.ps1
```

El script imprime `VIDEO_CREADO=<ruta>` y guarda el MP4 bajo `VIDEO_OUTPUT_DIR`. En la ejecución normal sin `-InputImage`, genera una imagen nueva en ComfyUI entre vídeos. Puedes indicar archivos explícitos con `-InputImage` si realmente quieres reutilizar una imagen:

```powershell
.\scripts\crear-video.ps1 -InputImage 'C:\ruta\a\imagen.png' -AudioFile 'C:\ruta\a\audio.mp3'
```

## Diagnóstico

- **Ollama no responde:** abre la aplicación y comprueba `/api/tags` en el puerto 11434.
- **ComfyUI no inicia:** revisa `COMFYUI_DIR` en `.env` y que exista `run_nvidia_gpu.bat`.
- **No aparece Execute Command:** detén n8n con Ctrl+C y vuelve a iniciarlo mediante `scripts/start-n8n.ps1`.
- **ComfyUI no responde:** comprueba que está iniciado y que `COMFYUI_URL` apunta a su dirección local.
- **ComfyUI devuelve HTTP 500 con `UnicodeDecodeError` UTF-8:** usa la versión actual de `scripts/generar-comfy-video.ps1`, que codifica el cuerpo JSON como bytes UTF-8 antes de enviarlo. Reinicia el workflow con el script actualizado; caracteres acentuados del prompt no deberían convertirse a la codificación local de Windows.
- **No encuentra la imagen generada:** revisa que el nodo Save Image del workflow API siga siendo el nodo 78 y que el directorio corresponda a `COMFYUI_OUTPUT_DIR`.
- **Indica que el PNG ya se usó:** en ComfyUI cambia el texto del CLIP positivo por otra escena de `assets/prompts/prompt1.txt`, pulsa **Queue Prompt**, espera a que acabe y vuelve a ejecutar. Comprueba que aparece un PNG nuevo en `COMFYUI_OUTPUT_DIR`.
- **No encuentra FFmpeg/libx264:** instala una build completa de FFmpeg y define `FFMPEG_EXE` con la ruta a `ffmpeg.exe`.
- **n8n no puede leer el MP4:** confirma que arrancó con el script y que `VIDEO_OUTPUT_DIR` resuelve a la carpeta correcta.
- **Buffer dice que no pudo leer el vídeo:** abre `secure_url` en una ventana privada y revisa que el valor de `video.url` sea la URL completa. Cloudinary debe permitir acceso público al recurso.
- **Buffer devuelve un error de mutación:** revisa el ID del canal, las credenciales Header Auth y el error mostrado por la API; confirma el estado en Buffer antes de reintentar.

## Seguridad y archivos publicados

`.gitignore` excluye `.env`, archivos `pass*`, el audio, los MP4, logs, bases de datos locales y la exportación original de n8n. Revisa siempre `git status` antes de publicar. Si un token, contraseña o clave llegó a exponerse, revócalo y crea uno nuevo.
