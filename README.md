# Automatización local de vídeos ambientales para TikTok

Genera un vídeo vertical a partir de una imagen de ComfyUI, integra una pista local y lo añade a la cola de TikTok de Buffer. El flujo usa Ollama, ComfyUI, FFmpeg, n8n y Cloudinary.

## Configuración y arranque

Consulta [ARRANQUE_LOCAL.md](ARRANQUE_LOCAL.md) para los pasos rápidos y [GUIA_COMPLETA.md](GUIA_COMPLETA.md) para requisitos, configuración de servicios y diagnóstico.

1. Copia `.env.example` a `.env` y configura la ruta a tu instalación de ComfyUI.
2. Pon tu archivo de audio local en `assets/audio/` y configura `AUDIO_FILE`.
3. Inicia ComfyUI con `scripts/start-comfyui.ps1` y Ollama como aplicación local.
4. Inicia n8n con `scripts/start-n8n.ps1`.
5. Importa `workflows/n8n-video-tiktok.json` y rellena sus marcadores de Cloudinary y Buffer. Guarda la clave de Buffer en **Credentials** de n8n.

La ejecución del workflow publica una entrada real en la cola de Buffer. Comprueba la cola y los valores de integración antes de ejecutarlo.

## Contenido local ignorado por Git

`.env`, credenciales, archivos `pass*`, audio, vídeos generados, logs, bases de datos locales y la exportación original de n8n están excluidos. El workflow que sí se incluye está sanitizado y usa marcadores, no tus identificadores locales.

## Estructura

- `scripts/`: creación de vídeo y scripts de arranque.
- `assets/prompts/`: prompts de referencia.
- `assets/audio/`: ubicación local para la pista (ignorada por Git).
- `videos/`: salida local de MP4 (ignorada por Git).
- `workflows/`: exportación de ejemplo para importar en n8n.
