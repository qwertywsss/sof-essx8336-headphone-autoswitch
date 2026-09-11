# sof-essx8336 headphone auto-switch

Arregla el bug de audio en laptops con el códec ES8336 sobre el driver
`snd_soc_sof_es8336` (tarjeta ALSA `sof-essx8336`, común en varios modelos
Huawei MateBook y equivalentes) donde conectar/desconectar audífonos por
el jack de 3.5mm no cambia el destino del audio: sigue sonando (o
silencioso) por el altavoz hasta que se cambia el perfil manualmente.

## Síntoma

- Los audífonos no suenan al conectarlos; el audio se sigue escuchando
  (o no se escucha nada) por el altavoz de la laptop.
- Al desconectar los audífonos, el altavoz vuelve a sonar normal.
- `wpctl status` solo muestra un sink de audio a la vez (Speaker *o*
  Headphones, nunca ambos), y no cambia solo al conectar/desconectar.

## Causa raíz

En esta tarjeta, la configuración UCM de ALSA (`alsa-ucm-conf`) define
"Speaker" y "Headphones" como dos **perfiles** de tarjeta mutuamente
excluyentes (no como dos puertos de un mismo perfil, que es lo normal en
la mayoría de laptops). Por otro lado, WirePlumber desactiva por defecto
el cambio automático de perfil (`api.acp.auto-profile = false`,
`api.acp.auto-port = false`, ver
`/usr/share/wireplumber/scripts/monitors/alsa.lua`), delegando el
cambio dinámico a su propia lógica de "default nodes" — lógica que solo
cambia el **puerto activo dentro de un mismo perfil**, no el perfil
completo. Como resultado, el jack se detecta correctamente a nivel de
kernel (`amixer -c0 cget numid=27` cambia entre `on`/`off`), pero nada
en el sistema reacciona a ese cambio para alternar el perfil.

## Solución

Dos piezas:

1. **`wireplumber.conf.d/51-sof-essx8336-auto-profile.conf`**: reactiva
   `api.acp.auto-profile` y `api.acp.auto-port` solo para esta tarjeta
   (por si en algún momento ayuda con el cambio de puertos dentro de un
   perfil). Por sí sola no resuelve el problema porque, como se explicó
   arriba, esta tarjeta usa perfiles separados y no puertos.

2. **`headphone-jack-switch.sh`** + **`headphone-jack-switch.service`**:
   un servicio de usuario (systemd) que corre `alsactl monitor hw:0` en
   segundo plano, escucha los eventos del control `Headphone Jack`, y
   llama a `pactl set-card-profile` para alternar entre el perfil
   "Headphones" y el perfil "Speaker" según el estado real del sensor.
   Esta es la pieza que realmente resuelve el cambio automático.

## Instalación

```sh
./install.sh
```

Esto copia los archivos a `~/.local/bin`, `~/.config/systemd/user` y
`~/.config/wireplumber/wireplumber.conf.d`, habilita el servicio, y te
recuerda reiniciar PipeWire/WirePlumber una vez para aplicar la regla.

## Verificar

```sh
systemctl --user status headphone-jack-switch.service
amixer -c0 cget numid=27                 # estado del jack
pactl list cards | grep 'Active Profile' # perfil activo
```

Conecta/desconecta los audífonos y el perfil (y el audio) debería
cambiar solo, en un par de segundos.

## Notas

- Los nombres de perfil (`CARD_NAME`, `HP_PROFILE`, `SPK_PROFILE` en
  `headphone-jack-switch.sh`) están hardcodeados para esta tarjeta en
  particular. Si tu `pactl list cards` muestra nombres distintos,
  ajústalos ahí.
- El sensor del jack tiene cierto debounce (uno o dos segundos) antes
  de reportar el nuevo estado; es normal que el cambio no sea
  instantáneo.
