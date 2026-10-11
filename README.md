# Automatización local de vídeos ambientales para TikTok

Genera un vídeo vertical a partir de una imagen de ComfyUI, integra una pista local y lo añade a la cola de TikTok de Buffer. El flujo usa Ollama, ComfyUI, FFmpeg, n8n y Cloudinary.

## Configuración y arranque

Consulta [ARRANQUE_LOCAL.md](ARRANQUE_LOCAL.md) para los pasos rápidos y [GUIA_COMPLETA.md](GUIA_COMPLETA.md) para requisitos, configuración de servicios y diagnóstico.

1. Copia `.env.example` a `.env` y configura la ruta a tu instalación de ComfyUI.
2. Pon tu archivo de audio local en `assets/audio/` y configura `AUDIO_FILE`.
3. Ejecuta `scripts/start-services.ps1` para iniciar Ollama, ComfyUI y n8n.
4. Importa `workflows/n8n-video-tiktok.json` y rellena sus marcadores de Cloudinary y Buffer. Guarda la clave de Buffer en **Credentials** de n8n.

Cada ejecución genera una imagen nueva en ComfyUI y publica una entrada real en la cola de Buffer. Comprueba la cola y los valores de integración antes de ejecutarlo.

Para detener los servicios locales ejecuta `scripts/stop-services.ps1`. El lanzador y el script de parada registran su actividad en `logs/`; los servicios en la nube de Cloudinary y Buffer no necesitan arrancarse desde el equipo local.

El estilo automático es Dark Fantasy: el paisaje es el foco y debe ocupar aproximadamente el 85–90 % del encuadre. Ollama añade un solo detalle narrativo discreto —un caballero o hechicero pequeño a media o larga distancia, o un artefacto integrado en el lugar— y pide evitar primeros planos. Buffer usa el pie de foto fijo `#darkfantasy #fantasiaoscura #misterio #mistery #fyp`.

El render local parte de una sola imagen y crea un MP4 de 8 segundos con FFmpeg, un zoom de hasta el 36 %, paneo diagonal con deriva suave y fade out visual y de audio en el último segundo. No genera movimiento independiente de las nubes o el agua, así evita usar un modelo de generación de vídeo.

## Contenido local ignorado por Git

`.env`, credenciales, archivos `pass*`, audio, vídeos generados, logs, bases de datos locales y la exportación original de n8n están excluidos. El workflow que sí se incluye está sanitizado y usa marcadores, no tus identificadores locales.

## Estructura

- `scripts/`: creación de vídeo y scripts de arranque y parada.
- `assets/prompts/`: prompts de referencia.
- `assets/audio/`: ubicación local para la pista (ignorada por Git).
- `videos/`: salida local de MP4 (ignorada por Git).
- `workflows/`: exportación de ejemplo para importar en n8n.
