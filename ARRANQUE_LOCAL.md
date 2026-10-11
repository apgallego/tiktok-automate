# Arranque local rápido

Guía para iniciar el proyecto en Windows 10 desde la carpeta del repositorio.

## Primera configuración

1. Copia `.env.example` como `.env` y ajusta `COMFYUI_DIR` si ComfyUI Portable está en otra ubicación.
2. Coloca la pista con licencia para publicar en `assets/audio/Dorian_concept.mp3` (o cambia `AUDIO_FILE` en `.env`). Este archivo es local y no se sube a GitHub.
3. En n8n, importa `workflows/n8n-video-tiktok.json`. Completa el nombre de Cloudinary y el upload preset unsigned en el nodo de subida, el ID de canal de Buffer y asigna tu credencial Header Auth de Buffer en n8n. El archivo de ejemplo usa marcadores `TU_...` deliberadamente.

## Iniciar servicios

Desde la raíz del proyecto, ejecuta en PowerShell:

```powershell
.\scripts\start-services.ps1
```

El script inicia Ollama, ComfyUI y n8n en segundo plano, en ese orden. Si alguno ya responde, lo deja funcionando y no crea otra instancia. Abre [n8n](http://localhost:5678) cuando el script indique que los servicios están listos. La salida se guarda en `logs/`.

Para depurar o iniciar un servicio por separado, siguen disponibles `scripts/start-comfyui.ps1` y `scripts/start-n8n.ps1`; Ollama también puede iniciarse desde su aplicación local.

## Publicar un vídeo

En n8n, abre el workflow y pulsa **Execute workflow**. Ollama propone una escena Dark Fantasy y un prompt visual; ComfyUI genera una imagen nueva con ese prompt y el script la convierte en un MP4 vertical de 8 segundos con audio, zoom y paneo. El paisaje debe dominar la imagen (aproximadamente el 85–90 % del encuadre), con un caballero o hechicero pequeño y distante, o un artefacto discreto integrado en el entorno. El vídeo se sube a Cloudinary y Buffer lo añade a la cola de TikTok con el pie de foto fijo `#darkfantasy #fantasiaoscura #misterio #mistery #fyp`. Confirma en Buffer que el post quedó en cola antes de volver a ejecutar.

Las rutas configurables están en `.env`: `COMFYUI_DIR`, `COMFYUI_OUTPUT_DIR`, `VIDEO_OUTPUT_DIR`, `AUDIO_FILE` y `FFMPEG_EXE`. Las rutas relativas se resuelven desde la raíz del proyecto. Los MP4 locales quedan en `videos/`; tanto esa carpeta como el audio están excluidos de Git.

## Comprobaciones

```powershell
(Invoke-WebRequest 'http://127.0.0.1:5678/healthz').StatusCode
(Invoke-WebRequest 'http://127.0.0.1:8188/system_stats').StatusCode
Invoke-RestMethod 'http://127.0.0.1:11434/api/tags'
```

Si no aparece `Execute Command`, cierra n8n con Ctrl+C y vuelve a iniciarlo con `scripts/start-n8n.ps1`. Si el nodo de archivos indica que no puede acceder a una ruta, confirma que usaste ese script y que `VIDEO_OUTPUT_DIR` apunta a la carpeta local del proyecto.

## Detener servicios

Desde la raíz del proyecto, ejecuta:

```powershell
.\scripts\stop-services.ps1
```

El script detiene n8n (puerto 5678), ComfyUI (el puerto configurado en `COMFYUI_URL`) y Ollama (puerto 11434). Antes de detener un proceso comprueba su nombre y línea de comandos; si un programa ajeno ocupa uno de esos puertos, lo deja activo y muestra un aviso. Para dejar Ollama abierto, ejecuta `.\scripts\stop-services.ps1 -KeepOllama`.

Para más detalles consulta [GUIA_COMPLETA.md](GUIA_COMPLETA.md) y [README.md](README.md).
