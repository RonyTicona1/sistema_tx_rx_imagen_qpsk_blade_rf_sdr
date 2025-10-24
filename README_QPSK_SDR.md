# Sistema de Transmisión y Recepción de Imágenes mediante Modulación QPSK en SDR BladeRF

Este proyecto implementa un sistema completo de comunicaciones digitales para la **transmisión y recepción de imágenes** utilizando **modulación QPSK (π/4, Gray)** sobre hardware **SDR BladeRF**.  
El desarrollo se realizó en **MATLAB**, con procesamiento de señal digital (DSP) tanto en el transmisor (TX) como en el receptor (RX).

---

## 📘 Descripción General

El objetivo principal es **enviar una imagen desde una computadora transmisora hacia otra receptora** mediante señales moduladas en cuadratura QPSK, empleando un entorno de radio definida por software (SDR).  
El sistema incluye las etapas esenciales de un enlace digital:

1. **Codificación y preparación de datos**
2. **Mapeo de bits a símbolos QPSK (Gray)**
3. **Inserción de cabecera con CRC16**
4. **Scrambling con LFSR de 7 bits**
5. **Filtrado RRC y conformación de pulso**
6. **Transmisión en banda base (BladeRF)**
7. **Recepción, sincronización y corrección CFO/fase**
8. **Demodulación y reconstrucción de la imagen original**

---

## 🧠 Arquitectura del Sistema

El sistema está dividido en dos módulos principales:

- **Transmisor (TX):**
  - Convierte una imagen a una secuencia binaria.
  - Aplica scrambling, cabecera y modulación QPSK.
  - Genera la señal filtrada y normalizada.
  - Exporta el archivo `.sc16q11` para transmisión con BladeRF.

- **Receptor (RX):**
  - Carga la señal recibida `.sc16q11`.
  - Sincroniza símbolos mediante correlación Barker y entrenamiento QPSK.
  - Corrige frecuencia y fase (CFO y PLL).
  - Extrae cabecera y decodifica bits.
  - Reconstruye y muestra la imagen original.

---

## ⚙️ Estructura del Repositorio

```
📂 sistema_tx_rx_imagen_qpsk_blade_rf_sdr
│
├── 📁 Prueba 1
│   ├── 📁 Archivos TX
│   ├── 📁 Archivos RX
│   └── 📄 BladeRF_P1.txt
│
├── 📁 Prueba 2
│   ├── 📁 Archivos TX
│   ├── 📁 Archivos RX
│   └── 📄 BladeRF_P2.txt
│
├── 📄 README.md
└── 📄 Informe_Practica3_IEEE.pdf
```

Cada carpeta de **Prueba 1** y **Prueba 2** contiene los códigos MATLAB (`.m`), archivos de señal (`.sc16q11`) y configuraciones CLI utilizadas para replicar los experimentos reales con el dispositivo SDR.

---

## 📂 Organización del Repositorio

El repositorio contiene dos carpetas principales correspondientes a las pruebas experimentales realizadas con el SDR BladeRF:

- **Prueba 1:** Incluye los códigos fuente MATLAB del transmisor (TX) y receptor (RX), así como los archivos generados (`.sc16q11`) y el script de configuración del BladeRF (`BladeRF_P1.txt`).
- **Prueba 2:** Contiene la segunda ejecución experimental con distintos parámetros de ganancia y condiciones de entorno, siguiendo la misma estructura de archivos que la Prueba 1.

Cada carpeta cuenta con las siguientes subcarpetas:

```
📁 Archivos TX   → scripts de transmisión y señales generadas  
📁 Archivos RX   → scripts de recepción y resultados obtenidos  
📄 BladeRF_P1.txt / BladeRF_P2.txt → comandos ejecutados en bladeRF-cli
```

Estas carpetas permiten replicar fácilmente las pruebas descritas en el informe, manteniendo la trazabilidad entre los códigos, configuraciones y resultados experimentales.

---

## 🧩 Requisitos

- MATLAB R2022b o superior  
- Communications Toolbox  
- SDR BladeRF con control mediante `bladeRF-cli`  
- Conexión USB 3.0 estable  
- Imagen de entrada en formato `.png` o `.jpg`

---

## ▶️ Ejecución

### Transmisión

1. Configurar el transmisor:
   ```bash
   set frequency tx1 920M
   set samplerate tx1 2M
   set bandwidth tx1 2M
   set gain tx1 50
   tx config file=P3PruebaFF1.sc16q11 format=bin repeat=1
   tx start; tx wait
   ```

2. Ejecutar en MATLAB:
   ```matlab
   tx_qpsk_final('nota20.png', 'P3PruebaFF1.sc16q11');
   ```

### Recepción

1. Configurar el receptor:
   ```bash
   set frequency rx1 920M
   set samplerate rx1 2M
   set bandwidth rx1 2M
   set gain rx1 15
   rx config file=P3PruebaFF1.sc16q11 format=bin n=0
   tx start
   tx stop
   ```

2. Ejecutar en MATLAB:
   ```matlab
   rx_qpsk_final('P3PruebaFF1.sc16q11');
   ```

---

## 📊 Resultados Experimentales

Se realizaron **dos pruebas reales** de transmisión y recepción, cuyos resultados incluyen:

- Gráficas de constelación antes y después de la corrección CFO/fase.
- Correlación con preámbulo Barker.
- Señal real en el tiempo.
- Imagen reconstruida correctamente en el receptor.

Todos los resultados y figuras están disponibles en el informe PDF y en el repositorio de Drive.

---

## 🔗 Recursos Complementarios

- **Informe completo (IEEE):** Disponible en el repositorio.  
- **Carpeta de respaldo en Drive:**  
  [Google Drive – Proyecto QPSK SDR](https://drive.google.com/drive/folders/1syCcmkbR46iKqC4l20rt-UAEfdUsrzyQ?usp=drive_link)

---

## 👨‍💻 Autor

**Rony Ticona**  
Proyecto académico — Práctica 3  
Escuela de Ingeniería Electrónica  
Universidad Nacional Mayor de San Marcos  
📧 ronyticona1@gmail.com  

---

## 📜 Licencia

Este proyecto se distribuye bajo la licencia **MIT**, lo que permite su uso, modificación y redistribución con fines educativos y de investigación.
