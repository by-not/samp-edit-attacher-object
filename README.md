<p align="center">
  <img width="512" height="384" alt="logo" src="https://github.com/user-attachments/assets/d6857b8a-373e-460c-a085-9a332ac4d432" />
</p>

<h1 align="center">EditAttacherObject</h1>

<p align="center">
  <a href="https://github.com/by-not/samp-edit-attacher-object/releases">
    <img src="https://img.shields.io/github/v/release/by-not/samp-edit-attacher-object?style=for-the-badge&color=blue" alt="Latest Release" />
  </a>
  <a href="https://github.com/by-not/samp-edit-attacher-object/releases">
    <img src="https://img.shields.io/github/downloads/by-not/samp-edit-attacher-object/total?style=for-the-badge&color=brightgreen" alt="Total Downloads" />
  </a>
  <img src="https://img.shields.io/badge/Language-Pawn-orange?style=for-the-badge" alt="Pawn Language" />
  <img src="https://img.shields.io/github/license/by-not/samp-edit-attacher-object?style=for-the-badge&color=gray" alt="License" />
</p>

<p align="center">
  <b>Filterscript para SA-MP (Pawn)</b> que permite crear, editar y guardar sets de objetos adjuntos al jugador (<code>SetPlayerAttachedObject</code>) directamente en el juego, sin necesidad de recompilar el gamemode para probar cada ajuste.
</p>

---

## Tabla de contenidos

- [Características](#características)
- [Requisitos e instalación](#requisitos-e-instalación)
- [Conceptos básicos](#conceptos-básicos)
- [Comandos](#comandos)
- [Flujo de trabajo típico](#flujo-de-trabajo-típico)
- [Menú principal (comando `/attobjedit`)](#menú-principal-attobjedit)
- [Acciones de un slot](#acciones-de-un-slot)
- [Nombres personalizados de modelos](#nombres-personalizados-de-modelos)
- [Exportación e importación](#exportación-e-importación)
- [Formato de los archivos guardados](#formato-de-los-archivos-guardados)
- [Estructura interna del script](#estructura-interna-del-script)
- [Límites y configuración](#límites-y-configuración)
- [Preguntas frecuentes / notas](#preguntas-frecuentes--notas)

---

## Características

- Edición de hasta **10 slots** de objetos adjuntos por jugador (el límite real de `SetPlayerAttachedObject`, índices 0-9).
- Dos formas de editar cada objeto:
  - **Gizmo nativo 3D** (`EditAttachedObject`): mover, rotar y escalar con el mouse en tiempo real.
  - **Edición manual por valores**: offset, rotación y escala (X/Y/Z) escritos a mano con precisión de 4 decimales.
- **Ocultar/mostrar** un objeto sin perder su configuración de slot (útil para probar combinaciones sin borrar nada).
- **Nombres personalizados** para IDs de modelo (por ejemplo, poner "Casco SWAT" al modelo `#18646`), compartidos entre todos los jugadores y guardados en disco.
- **Duplicar** la configuración de un slot a otro slot libre.
- **Sesiones guardables** en disco, listables y cargables desde el menú.
- **Exportación a código Pawn** listo para pegar en tu gamemode (por ejemplo en `OnPlayerSpawn` o en un comando propio).
- **Importación** de un archivo ya exportado (`.txt` con líneas `SetPlayerAttachedObject(...)`) o de otra sesión `.eobj`.
- Comando adicional `/skin <id>` para probar rápidamente los objetos sobre distintas skins.

## Requisitos e instalación

1. Copia `EditAttacherObject.pwn` a la carpeta `filterscripts/` de tu servidor SA-MP.
2. Compílalo con el compilador Pawn de tu servidor (usa `#include <a_samp>`, no requiere includes externos ni streamer).
3. Agrega el filterscript a tu `server.cfg`:

   ```
   filterscripts EditAttacherObject
   ```

4. Reinicia el servidor. En la consola aparecerá el banner del script y se creará automáticamente la carpeta `scriptfiles/attachobjecteditor/` junto con el índice de sesiones (`_index.txt`) y el archivo de nombres de objetos (`objectnames.txt`) si no existen.

No se requieren plugins ni includes de terceros; todo el código usa exclusivamente funciones nativas de `a_samp`.

## Conceptos básicos

| Concepto | Descripción |
|---|---|
| **Sesión** | Un archivo guardado (`.eobj`) identificado por un nombre único, que contiene la configuración de hasta 10 slots. |
| **Slot** | Una posición (0-9) del sistema de objetos adjuntos de SA-MP. Puede estar vacío o tener un objeto configurado. |
| **Hueso (bone)** | El punto del esqueleto del jugador (18 disponibles: columna, cabeza, manos, pies, etc.) al que se ancla el objeto. |
| **Nombre de objeto** | Alias amigable opcional asignado a un ID de modelo, para reconocerlo fácilmente en los menús. |

Cada jugador tiene su **propia sesión** en edición; los datos se autoguardan al desconectarse si hay cambios sin guardar (`dirty`) y al menos un slot ocupado.

---

## Comandos

| Comando | Descripción |
|---|---|
| `/attobjedit` | Abre el editor. Si ya tienes una sesión en edición, va directo a la lista de slots; si no, abre el menú principal. |
| `/skin <id>` | Cambia tu skin (0–311) y vuelve a aplicar los objetos adjuntos configurados (por si el cambio de skin reinicia los huesos). Ejemplo: `/skin 105`. |

---

## Flujo de trabajo típico

1. `/attobjedit` → **Nueva sesión** → escribe un nombre (letras, números, `-` o `_`, máx. 31 caracteres).
2. En la lista de slots, elige un slot **(vacío)** → escribe el **ID del objeto** (modelo) → elige el **hueso** al que se adjunta. El objeto se aplica de inmediato.
3. Entra a ese slot de nuevo para:
   - **Editar en 3D (gizmo)**: usa el editor nativo de SA-MP con el mouse para mover/rotar/escalar.
   - **Editar valores manualmente**: ajusta offset/rotación/escala campo por campo.
   - **Nombrar objeto**: ponle un alias al modelo para reconocerlo después.
   - **Ocultar/Mostrar**: alterna visibilidad sin perder la configuración.
   - **Duplicar a otro slot**: copia toda la configuración a un slot libre.
   - **Quitar objeto**: vacía el slot (con confirmación).
4. Desde la lista de slots: **Guardar**, **Guardar como...** (renombra y guarda), **Exportar** (genera código Pawn) o **Vaciar todos los slots** / **Eliminar esta sesión**.
5. Cierra el diálogo o desconéctate: si hay cambios sin guardar, se autoguardan.

---

## Menú principal (`/attobjedit`)

Solo aparece si **no** tienes una sesión en edición actualmente (de lo contrario, `/attobjedit` te lleva directo a tu lista de slots):

| Opción | Acción |
|---|---|
| Nueva sesión | Pide un nombre y crea una sesión vacía con los 10 slots disponibles. |
| Mis sesiones | Lista las sesiones `.eobj` guardadas (hasta 40) para cargarlas. |
| Importar exportación | Permite leer un `.txt` (u otra sesión `.eobj`) ya colocado en `scriptfiles/attachobjecteditor/` y convertirlo en una sesión nueva. |
| Ayuda | Explica cada función del editor y recuerda el comando `/skin`. |

## Acciones de un slot

Al entrar a un slot **ocupado** desde la lista, se muestra:

| Acción | Detalle |
|---|---|
| Cambiar objeto | Pide un nuevo ID de modelo (numérico). |
| Cambiar hueso | Lista los 18 huesos disponibles. |
| Nombrar objeto | Asigna/actualiza el nombre amigable del modelo actual. |
| Ocultar objeto / Mostrar objeto | Alterna `slot_hidden`: el objeto se mantiene configurado pero no se aplica al jugador mientras esté oculto. |
| Editar en 3D (gizmo) | Llama a `EditAttachedObject` (editor nativo con mouse). |
| Editar valores manualmente | Abre el menú de los 9 campos numéricos (offset/rotación/escala X/Y/Z). |
| Duplicar a otro slot | Copia toda la configuración del slot actual a un slot libre elegido. |
| Quitar objeto | Vacía el slot (con confirmación). |

### Huesos disponibles

Columna, Cabeza, Brazo superior izquierdo, Brazo superior derecho, Mano izquierda, Mano derecha, Muslo izquierdo, Muslo derecho, Pie izquierdo, Pie derecho, Pantorrilla derecha, Pantorrilla izquierda, Antebrazo izquierdo, Antebrazo derecho, Clavícula izquierda, Clavícula derecha, Cuello, Mandíbula (18 en total, numerados 1–18 igual que en `SetPlayerAttachedObject`).

---

## Nombres personalizados de modelos

Puedes asignar un alias a cualquier ID de modelo desde **Nombrar objeto**. Estos nombres:

- Se guardan de inmediato en `scriptfiles/attachobjecteditor/objectnames.txt`.
- Son **globales**: se comparten entre todos los jugadores y sesiones (útil para mantener una nomenclatura consistente en el equipo).
- Se muestran en los menús como `NombrePersonalizado (#ID)`; si un modelo no tiene alias, se muestra como `Modelo #ID`.
- Están limitados a 300 modelos distintos (`MAX_OBJECT_NAMES`), 31 caracteres cada uno, sin comas ni saltos de línea.

---

## Exportación e importación

### Exportar

**Exportar** desde la lista de slots genera `scriptfiles/attachobjecteditor/<sesion>_export.txt` con una función lista para pegar en tu gamemode:

```pawn
// Edit Attacher Object - Exportacion de la sesion: <nombre>
// Pega este codigo donde quieras adjuntar los objetos al jugador (OnPlayerSpawn, un comando, etc.)

stock ApplyAttachedObjects_<nombre>(playerid)
{
    SetPlayerAttachedObject(playerid, <slot>, <modelo>, <hueso>, OFFX, OFFY, OFFZ, ROTX, ROTY, ROTZ, SCALEX, SCALEY, SCALEZ);
    // ... una linea por cada slot ocupado y visible ...
}
```

> Los slots **ocultos** no se incluyen en la exportación (solo se exportan los objetos visibles).

### Importar

Desde **Importar exportación** en el menú principal, escribes el nombre del archivo (sin extensión) que ya colocaste en `scriptfiles/attachobjecteditor/`. El script busca, en este orden:

1. `<nombre>_export.txt`
2. `<nombre>.txt`
3. `<nombre>.eobj`

- Si es un **`.eobj`**, se carga como una sesión normal (`LoadSession`).
- Si es un **`.txt`**, se parsean todas las líneas que contengan `SetPlayerAttachedObject(...)` (sin importar el resto del código alrededor) y se reconstruyen los slots a partir de sus parámetros.

Tras importar, se te pide un nombre para la nueva sesión y los objetos se aplican de inmediato (recuerda guardar).

---

## Formato de los archivos guardados

Todos los archivos se guardan como texto plano dentro de `scriptfiles/attachobjecteditor/` (carpeta definida por `SCRIPTFILES_DIR`).

### Índice de sesiones — `_index.txt`

Una línea por sesión, solo el nombre:

```
nombre_sesion
```

Se actualiza automáticamente al guardar (`AddToIndex`) o eliminar (`RemoveFromIndex`) una sesión, y se usa para poblar la lista de "Mis sesiones" (máx. 40, `MAX_SESSION_FILES`).

### Nombres de objetos — `objectnames.txt`

Una línea por modelo con nombre asignado:

```
modelid,nombre
```

### Sesión — `<nombre>.eobj`

```
#VERSION=2
#NAME=<nombre>
SLOT,<idx>,<modelid>,<boneid>,<offx>,<offy>,<offz>,<rotx>,<roty>,<rotz>,<scalex>,<scaley>,<scalez>,<hidden>
...
```

- Una línea `SLOT,...` por cada slot ocupado (los vacíos no se escriben).
- `hidden` es `1` si el objeto está oculto, `0` si es visible.
- Todos los valores flotantes se guardan con 4 decimales.

---

## Estructura interna del script

Referencia rápida de los *callbacks* y bloques principales, útil para quien quiera modificar o extender el script:

| Callback / bloque | Responsabilidad |
|---|---|
| `OnFilterScriptInit` / `OnFilterScriptExit` | Banner de consola, creación de índice/carpeta si no existen, carga de nombres de objetos (`LoadObjectNames`), inicialización/autoguardado de todos los jugadores conectados. |
| `OnPlayerConnect` / `OnPlayerDisconnect` | Inicializa/limpia la sesión del jugador; autoguarda al desconectar si hay cambios pendientes. |
| `OnPlayerCommandText` | Enrutamiento de `/attobjedit` y `/skin`. |
| `OnDialogResponse` | Maneja **todos** los diálogos (menú principal, listas, creación/edición de slots, huesos, valores manuales, duplicado, guardar como, importación, confirmaciones) mediante los IDs `DIALOG_*` definidos al inicio del archivo. |
| `OnPlayerEditAttachedObject` | Confirma o cancela el arrastre del gizmo nativo 3D y persiste los cambios de hueso/offset/rotación/escala en el slot correspondiente. |

### Funciones clave

- `RefreshAttachedObjects` — vuelve a aplicar todos los slots del jugador (quita y reasigna cada `SetPlayerAttachedObject`), respetando los que están ocultos.
- `ClearSlot` / `CopySlot` / `CountUsedSlots` / `GetFreeSlotsList` — utilidades de gestión de slots.
- `GetManualFieldValue` / `SetManualFieldValue` / `GetManualFieldName` — abstracción de los 9 campos numéricos editables (offset/rotación/escala X/Y/Z) usada por el menú de edición manual.
- `SaveSession` / `LoadSession` / `DeleteSession` — persistencia de sesiones en `.eobj`.
- `AddToIndex` / `RemoveFromIndex` / `ReadIndex` — mantenimiento del índice de sesiones guardadas.
- `ExportSession` / `ImportFromFile` — generación e ingestión del código Pawn exportado.
- `SetObjectName` / `GetObjectDisplayName` / `FindObjectNameIndex` — sistema de alias de modelos.

### Enumeraciones de datos

- `E_SLOT` — datos completos de un slot: si está usado, modelo, hueso, offset, rotación, escala y si está oculto.
- `E_SESSION` — estado de sesión por jugador: estado actual, slot en edición, campo manual en edición, si se está creando un objeto nuevo (flujo modelo→hueso) y si hay cambios sin guardar.

Todos los arreglos están indexados por `playerid`, así que cada jugador mantiene su propia sesión en edición de forma completamente aislada. Los nombres de objetos (`g_objName_*`), en cambio, son **globales** y compartidos por todos.

---

## Límites y configuración

Todos ajustables al principio de `EditAttacherObject.pwn`:

| Constante | Valor por defecto | Significado |
|---|---|---|
| `MAX_SLOTS` | 10 | Límite real de `SetPlayerAttachedObject` (índices 0-9). |
| `MAX_SESSION_NAME` | 32 | Longitud máxima del nombre de una sesión. |
| `MAX_SESSION_FILES` | 40 | Sesiones listables en el menú "Mis sesiones". |
| `SCRIPTFILES_DIR` | `"attachobjecteditor"` | Carpeta de guardado dentro de `scriptfiles/`. |
| `MAX_OBJECT_NAMES` | 300 | Cuántos modelos con nombre personalizado se pueden guardar. |
| `MAX_OBJECT_NAME_LEN` | 32 | Longitud máxima de un alias de modelo. |

Otros rangos validados en el propio manejo de los diálogos: nombres de sesión y de objeto solo aceptan letras, números, `-`/`_` (sesión) o cualquier carácter salvo coma/salto de línea (nombre de objeto); `/skin` acepta valores entre 0 y 311.

---

## Preguntas frecuentes / notas

- **¿Puedo tener más de una sesión abierta a la vez?** No; cada jugador edita una sola sesión a la vez. Cargar o crear otra sustituye la actual (los objetos adjuntos se quitan y se vuelven a aplicar según la nueva sesión).
- **¿Qué pasa si cierro el diálogo de la lista de slots sin elegir "Guardar"?** Los objetos siguen aplicados sobre tu personaje; simplemente vuelve a ejecutar `/attobjedit` para continuar donde lo dejaste. El autoguardado ocurre al desconectarte si hay cambios pendientes.
- **¿El editor 3D requiere el plugin Streamer?** No, usa `EditAttachedObject`/`OnPlayerEditAttachedObject`, ambas funciones nativas de SA-MP.
- **¿Puedo editar el archivo `.eobj` a mano?** Sí, es texto plano con el formato documentado arriba, pero cuida los índices de slot (`idx`, 0-9) para que no haya inconsistencias.
- **Colisión de IDs de diálogo:** todos los diálogos usan el rango `18000–18018`, distinto al usado por CamEditor (`17000–17036`), para poder tener ambos filterscripts activos en el mismo servidor sin conflictos.
- **¿Qué pasa con el cambio de skin?** Algunos huesos pueden reposicionarse al cambiar de skin; por eso `/skin <id>` vuelve a llamar `RefreshAttachedObjects` automáticamente tras el cambio.
