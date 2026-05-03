# Shelly EM/3EM Meter para Victron Venus OS

Integración universal de **Shelly EM** (monofásico) y **Shelly 3EM** (trifásico) como medidores de energía en Victron Venus OS mediante D-Bus.

## Responsabiliad
Este complementeo para Venus OS no está soportado oficialemente ni por Victron, ni por Shelly.
Úsalo bajo tu responsabilidad. Sólo tu eres responsable de los efectos que pueda tener en tu instalación y el comportamiento de la misma.
Si no sabes qué estás haciendo o necesitas una integración Oficial, este complemento no es el recomendado para ti.


## 🎯 Características

### Shelly EM (Monofásico)
- ✅ Lee cualquiera de las 2 pinzas independientemente
- ✅ Perfecto para sistemas monofásicos
- ✅ Ideal para medir Grid + PV con un solo dispositivo

### Shelly 3EM (Trifásico)
- ✅ Lee las 3 fases simultáneamente
- ✅ Perfecto para sistemas trifásicos
- ✅ Medición completa por fase (L1, L2, L3)
- ✅ Totales automáticos

### Funcionalidades Comunes
- 📊 Potencia, voltaje, corriente por fase
- ⚡ Factor de potencia
- 🔄 Energía consumida y retornada (kWh)
- 🔐 Soporte para autenticación HTTP
- 🔄 Inversión de signo configurable
- 📍 Configuración de posición (AC Input/Output)

## 📋 Requisitos

- Victron Venus OS (Cerbo GX, Venus GX, Raspberry Pi con Venus OS)
- Shelly EM o Shelly 3EM conectado a la red local
- Python 3 (incluido en Venus OS)

## 🚀 Instalación Rápida

### 1. Conectar al Venus OS por SSH

```bash
ssh root@venus-ip
```

### 2. Descargar los archivos

```bash
mkdir -p /data/shelly-meter
cd /data/shelly-meter

# Descargar o copiar aquí:
# - shelly_meter.py
# - config.json
# - install.sh
```

### 3. Configurar según tu dispositivo

#### Para Shelly EM (Monofásico):

```json
{
  "device_type": "em",
  "ip": "192.168.55.231",
  "clamp": 0,
  "poll_interval": 2000,
  "servicename": "com.victronenergy.grid",
  "deviceinstance": 40,
  "customname": "Grid Meter",
  "invert_power": false,
  "position": 0,
  "role": "grid"
}
```

#### Para Shelly 3EM (Trifásico):

```json
{
  "device_type": "3em",
  "ip": "192.168.55.240",
  "poll_interval": 2000,
  "servicename": "com.victronenergy.grid",
  "deviceinstance": 50,
  "customname": "Grid Meter 3-Phase",
  "invert_power": false,
  "position": 0,
  "role": "grid"
}
```

### 4. Instalar el servicio

```bash
chmod +x install.sh
./install.sh
```

### 5. Verificar funcionamiento

```bash
# Ver logs en tiempo real
tail -f /var/log/shelly-meter/current

# Ver en D-Bus
dbus -y | grep shelly
```

## 📖 Configuración Detallada

### Parámetros de configuración

| Parámetro | Valores | Descripción |
|-----------|---------|-------------|
| `device_type` | `"em"` o `"3em"` | Tipo de dispositivo Shelly |
| `ip` | Dirección IP | IP del Shelly en tu red |
| `clamp` | `0` o `1` | **Solo EM**: Pinza a leer |
| `username` | String o `null` | Usuario HTTP (opcional) |
| `password` | String o `null` | Contraseña HTTP (opcional) |
| `poll_interval` | Milisegundos | Intervalo de actualización (recomendado: 2000) |
| `servicename` | Ver tabla abajo | Tipo de servicio D-Bus |
| `deviceinstance` | 40-59 | ID único del dispositivo |
| `customname` | String | Nombre en Venus OS |
| `invert_power` | `true`/`false` | Invertir signo de potencia |
| `position` | `0`, `1` o `2` | Posición en el sistema |
| `role` | Ver tabla abajo | Rol del medidor |

### Tipos de servicio (`servicename`)

| Valor | Descripción | Uso típico |
|-------|-------------|------------|
| `com.victronenergy.grid` | Medidor de red | Punto de conexión a la red eléctrica |
| `com.victronenergy.pvinverter` | Inversor solar | Producción fotovoltaica |
| `com.victronenergy.genset` | Generador | Grupo electrógeno |
| `com.victronenergy.acload` | Carga AC | Consumos específicos |

### Posiciones (`position`)

| Valor | Descripción |
|-------|-------------|
| `0` | AC Input - Entrada de red |
| `1` | AC Output 1 - Salida crítica |
| `2` | AC Output 2 - Salida no crítica |

### Roles (`role`)

| Valor | Descripción |
|-------|-------------|
| `grid` | Medidor de red eléctrica |
| `pvinverter` | Inversor fotovoltaico |
| `genset` | Generador |
| `acload` | Carga AC |

## 🔧 Casos de Uso Comunes

### 1️⃣ Sistema Monofásico: Grid + PV con un Shelly EM

Usa las 2 pinzas del Shelly EM:

**Servicio 1 - Grid (Pinza 0):**
```bash
# /data/shelly-meter/config_grid.json
{
  "device_type": "em",
  "ip": "192.168.55.231",
  "clamp": 0,
  "servicename": "com.victronenergy.grid",
  "deviceinstance": 40,
  "customname": "Grid",
  "position": 0,
  "role": "grid"
}
```

**Servicio 2 - PV (Pinza 1):**
```bash
# /data/shelly-meter/config_pv.json
{
  "device_type": "em",
  "ip": "192.168.55.231",
  "clamp": 1,
  "servicename": "com.victronenergy.pvinverter",
  "deviceinstance": 41,
  "customname": "Solar",
  "position": 1,
  "role": "pvinverter"
}
```

Crear dos servicios separados siguiendo las instrucciones del README.

### 2️⃣ Sistema Trifásico: Grid con Shelly 3EM

**Configuración:**
```bash
# /data/shelly-meter/config.json
{
  "device_type": "3em",
  "ip": "192.168.55.240",
  "servicename": "com.victronenergy.grid",
  "deviceinstance": 50,
  "customname": "Grid 3-Phase",
  "position": 0,
  "role": "grid"
}
```

Venus OS mostrará:
- Potencia total
- Potencia por fase (L1, L2, L3)
- Voltaje por fase
- Corriente por fase
- Balance de fases

### 3️⃣ Sistema Trifásico: Grid + PV con dos Shelly 3EM

**Grid (Shelly 3EM #1):**
```json
{
  "device_type": "3em",
  "ip": "192.168.55.240",
  "servicename": "com.victronenergy.grid",
  "deviceinstance": 50,
  "customname": "Grid 3P",
  "position": 0,
  "role": "grid"
}
```

**PV (Shelly 3EM #2):**
```json
{
  "device_type": "3em",
  "ip": "192.168.55.241",
  "servicename": "com.victronenergy.pvinverter",
  "deviceinstance": 51,
  "customname": "PV 3P",
  "position": 1,
  "role": "pvinverter"
}
```

## 🔄 Crear Múltiples Servicios

Si necesitas varios medidores (por ejemplo, Grid + PV), crea servicios separados:

```bash
# Servicio 1: Grid
mkdir -p /data/shelly-grid-service
mkdir -p /data/shelly-grid-service/log

cat > /data/shelly-grid-service/run << 'EOF'
#!/bin/sh
exec 2>&1
exec python3 /data/shelly-meter/shelly_meter.py /data/shelly-meter/config_grid.json
EOF

cat > /data/shelly-grid-service/log/run << 'EOF'
#!/bin/sh
exec multilog t s25000 n4 /var/log/shelly-grid
EOF

chmod +x /data/shelly-grid-service/run
chmod +x /data/shelly-grid-service/log/run
ln -s /data/shelly-grid-service /service/shelly-grid

# Servicio 2: PV
mkdir -p /data/shelly-pv-service
mkdir -p /data/shelly-pv-service/log

cat > /data/shelly-pv-service/run << 'EOF'
#!/bin/sh
exec 2>&1
exec python3 /data/shelly-meter/shelly_meter.py /data/shelly-meter/config_pv.json
EOF

cat > /data/shelly-pv-service/log/run << 'EOF'
#!/bin/sh
exec multilog t s25000 n4 /var/log/shelly-pv
EOF

chmod +x /data/shelly-pv-service/run
chmod +x /data/shelly-pv-service/log/run
ln -s /data/shelly-pv-service /service/shelly-pv
```

## 🐛 Troubleshooting

### El servicio no aparece después de reiniciar

```bash
# Verificar que existe el servicio en /data
ls -la /data/shelly-meter-service/

# Recrear enlace simbólico
ln -s /data/shelly-meter-service /service/shelly-meter

# Verificar estado
svstat /service/shelly-meter
```

### Valores con signo incorrecto

Si al exportar energía aparece como positivo (debería ser negativo):

1. **Solución física**: Gira la pinza 180°
2. **Solución software**: Pon `"invert_power": true` en config.json

### No aparece en Venus OS

```bash
# Ver dispositivos D-Bus
dbus -y | grep victron

# Debería aparecer algo como:
# com.victronenergy.grid.http_40
# com.victronenergy.pvinverter.http_41
```

Verifica:
- `deviceinstance` sea único
- `servicename` sea correcto
- Servicio esté corriendo: `svstat /service/shelly-meter`

### Errores de conexión

```bash
# Verificar conectividad
ping 192.168.55.231

# Probar endpoint del Shelly
curl http://192.168.55.231/status

# Para Shelly 3EM, verifica que aparezcan 3 emeters
curl http://192.168.55.240/status | jq '.emeters | length'

# Debería devolver: 3
```

### Datos de una fase inválidos (solo 3EM)

Si una fase muestra datos inválidos:
- Verifica que las 3 pinzas estén correctamente instaladas
- Comprueba la instalación eléctrica
- Revisa en la app Shelly que las 3 fases funcionen

## 📊 Datos Publicados en D-Bus

### Shelly EM (Monofásico)

```
/Ac/Power                    # Potencia total (W)
/Ac/Current                  # Corriente total (A)
/Ac/Voltage                  # Voltaje (V)
/Ac/Energy/Forward           # Energía importada (kWh)
/Ac/Energy/Reverse           # Energía exportada (kWh)
/Ac/L1/Power                 # Potencia L1 (W)
/Ac/L1/Current               # Corriente L1 (A)
/Ac/L1/Voltage               # Voltaje L1 (V)
/Ac/L1/PowerFactor           # Factor de potencia L1
/Ac/L1/Energy/Forward        # Energía importada L1 (kWh)
/Ac/L1/Energy/Reverse        # Energía exportada L1 (kWh)
/Ac/L2/* y /Ac/L3/*          # En 0 (no usados)
```

### Shelly 3EM (Trifásico)

```
/Ac/Power                    # Potencia total 3 fases (W)
/Ac/Current                  # Corriente total (A)
/Ac/Voltage                  # Voltaje promedio (V)
/Ac/Energy/Forward           # Energía total importada (kWh)
/Ac/Energy/Reverse           # Energía total exportada (kWh)

/Ac/L1/Power                 # Potencia fase 1 (W)
/Ac/L1/Current               # Corriente fase 1 (A)
/Ac/L1/Voltage               # Voltaje fase 1 (V)
/Ac/L1/PowerFactor           # Factor de potencia fase 1
/Ac/L1/Energy/Forward        # Energía importada fase 1 (kWh)
/Ac/L1/Energy/Reverse        # Energía exportada fase 1 (kWh)

/Ac/L2/* y /Ac/L3/*          # Igual para fases 2 y 3
```

## 🛠️ Comandos Útiles

```bash
# Ver logs en tiempo real
tail -f /var/log/shelly-meter/current

# Estado del servicio
svstat /service/shelly-meter

# Reiniciar servicio
svc -t /service/shelly-meter

# Detener servicio
svc -d /service/shelly-meter

# Iniciar servicio
svc -u /service/shelly-meter

# Ver todos los servicios Victron
dbus -y | grep victron

# Inspeccionar un servicio específico
dbus -y com.victronenergy.grid.http_40

# Ver datos en tiempo real de un medidor
watch "dbus -y com.victronenergy.grid.http_40 | grep Ac"
```

## 📝 Notas Importantes

### Orientación de las Pinzas (Shelly EM)

La **flecha en la pinza** indica la dirección del flujo positivo:
- **Grid meter**: Flecha apuntando **HACIA la casa** → importación positiva ✅
- **PV meter**: Flecha apuntando **HACIA la casa** → producción positiva ✅

Si los signos están invertidos:
1. Gira físicamente la pinza 180°, O
2. Usa `"invert_power": true` en la config

### Instalación Trifásica (Shelly 3EM)

En sistemas trifásicos:
- Las 3 pinzas deben estar en las 3 fases (L1, L2, L3)
- Todas las pinzas con la misma orientación
- Venus OS sumará automáticamente las 3 fases

### Persistencia después de Reinicios

El servicio DEBE estar en `/data/` para persistir:
- ✅ `/data/shelly-meter-service/` → Persistente
- ❌ `/service/shelly-meter` → Es solo un enlace simbólico

Si el servicio desaparece tras reiniciar, recrea el enlace:
```bash
ln -s /data/shelly-meter-service /service/shelly-meter
```

### Asignación de IPs Estáticas

**Muy recomendado** asignar IP estática a los Shelly en el router para evitar que cambien de IP.

## 📄 Licencia

Este proyecto es de código abierto. Úsalo libremente para tu instalación solar.

## 🤝 Contribuciones

Si encuentras bugs o mejoras, compártelas con la comunidad.

---

**Versión:** 2.0
**Compatibilidad:** Venus OS v2.80+
**Dispositivos soportados:** Shelly EM, Shelly 3EM
**IA Ayuda:** Claude
