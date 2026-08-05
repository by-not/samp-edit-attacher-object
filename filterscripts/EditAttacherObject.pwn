/**
**      ______    _ _ _           _   _             _      ____  _     _           _        **
**     |  ____|  | (_) |     /\  | | | |           | |    / __ \| |   (_)         | |       **
**     | |__   __| |_| |_   /  \ | |_| |_ __ _  ___| |__ | |  | | |__  _  ___  ___| |_      **
**     |  __| / _` | | __| / /\ \| __| __/ _` |/ __| '_ \| |  | | '_ \| |/ _ \/ __| __|     **
**     | |___| (_| | | |_ / ____ \ |_| || (_| | (__| | | | |__| | |_) | |  __/ (__| |_      **
**     |______\__,_|_|\__/_/    \_\__|\__\__,_|\___|_| |_|\____/|_.__/| |\___|\___|\__|     **
**                                                                   _/ |                   **
**                                                                  |__/                    **
**                                                                                          **
**                                   Creado por not                                         **
**                                                                                          **
**                             Version: v1.0 (2026 release)                                 **
**                                                                                          **
**              Sistema de creación y edición de objetos adjuntos al jugador.               **
**                                                                                          **
**/

#define FILTERSCRIPT

#include <a_samp>

// Configuracion general
#define VERSION					"v1.0"	// Version del script
#define MAX_SLOTS               (10)    // Limite real de SetPlayerAttachedObject (indices 0-9)
#define MAX_SESSION_NAME        (32)    // Largo maximo del nombre de sesion
#define MAX_SESSION_FILES       (40)    // Maximo de sesiones listables
#define SCRIPTFILES_DIR         "attachobjecteditor"
#define INDEX_FILE              "attachobjecteditor/_index.txt"
#define OBJNAMES_FILE           "attachobjecteditor/objectnames.txt"
#define MAX_OBJECT_NAMES        (300)   // Cuantos modelos con nombre personalizado se pueden guardar
#define MAX_OBJECT_NAME_LEN     (32)

#define STATE_IDLE              (0)     // Sin sesion abierta / en menus
#define STATE_EDITING           (1)     // Sesion abierta, editando slots

// Campos numericos editables manualmente (offset/rotacion/escala)
#define MF_OFFX                 (0)
#define MF_OFFY                 (1)
#define MF_OFFZ                 (2)
#define MF_ROTX                 (3)
#define MF_ROTY                 (4)
#define MF_ROTZ                 (5)
#define MF_SCALEX               (6)
#define MF_SCALEY               (7)
#define MF_SCALEZ                (8)

// Dialogos (rango propio para evitar colisiones con otros scripts)
#define DIALOG_MAIN                    (18000) // Menu principal /xoa
#define DIALOG_NEW_NAME                (18001) // Nombre de la sesion nueva
#define DIALOG_LIST_SESSIONS           (18002) // Lista de sesiones guardadas
#define DIALOG_IMPORT_INPUT            (18003) // Nombre del archivo a importar
#define DIALOG_IMPORT_NAME             (18004) // Nombre de sesion para lo importado
#define DIALOG_HELP                    (18005) // Ayuda general
#define DIALOG_SLOT_LIST               (18006) // Lista de slots de la sesion abierta
#define DIALOG_SLOT_ACTIONS            (18007) // Acciones sobre un slot concreto
#define DIALOG_SLOT_MODEL_INPUT        (18008) // Input: ID de objeto (modelo)
#define DIALOG_SLOT_BONE_LIST          (18009) // Lista: seleccionar hueso
#define DIALOG_SLOT_MANUAL_MENU        (18010) // Lista: campos numericos del slot
#define DIALOG_SLOT_MANUAL_INPUT       (18011) // Input: nuevo valor de un campo
#define DIALOG_DUPLICATE_SLOT          (18012) // Lista: slot libre destino
#define DIALOG_SAVE_AS                 (18013) // Input: renombrar y guardar
#define DIALOG_CONFIRM_REMOVE_SLOT     (18014) // Confirmar: quitar objeto de un slot
#define DIALOG_CONFIRM_REMOVE_ALL      (18015) // Confirmar: vaciar todos los slots
#define DIALOG_CONFIRM_DELETE_SESSION  (18016) // Confirmar: eliminar sesion guardada
#define DIALOG_SLOT_NAME_INPUT         (18018) // Input: nombre personalizado del modelo

// Colores
#define COLOR_GREEN              "{8EFF8E}"
#define COLOR_RED                "{FF5555}"
#define COLOR_YELLOW             "{FFE040}"
#define COLOR_ORANGE             "{F58282}"
#define COLOR_RESET              "{FFFFFF}"
#define COLOR_GRAY               "{AAAAAA}"

// Estructuras de datos

enum E_SLOT
{
    bool:slot_used,
    slot_model,
    slot_bone,
    Float:slot_offx,   Float:slot_offy,   Float:slot_offz,
    Float:slot_rotx,   Float:slot_roty,   Float:slot_rotz,
    Float:slot_scalex, Float:slot_scaley, Float:slot_scalez,
    bool:slot_hidden   // true = el objeto sigue configurado pero no se muestra
}

enum E_SESSION
{
    ses_state,
    ses_edit_slot,
    ses_manual_field,
    bool:ses_creating,   // true mientras se esta creando un objeto nuevo (modelo -> hueso)
    bool:ses_dirty        // true si hay cambios sin guardar
}

// Variables globales

new g_slot[MAX_PLAYERS][MAX_SLOTS][E_SLOT];
new g_ses[MAX_PLAYERS][E_SESSION];
new g_sess_name[MAX_PLAYERS][MAX_SESSION_NAME];
new g_objName_id[MAX_OBJECT_NAMES];
new g_objName_str[MAX_OBJECT_NAMES][MAX_OBJECT_NAME_LEN];
new g_objName_count = 0;

new const g_boneNames[18][24] = {
    "Columna", "Cabeza", "Brazo sup. izquierdo", "Brazo sup. derecho",
    "Mano izquierda", "Mano derecha", "Muslo izquierdo", "Muslo derecho",
    "Pie izquierdo", "Pie derecho", "Pantorrilla derecha", "Pantorrilla izquierda",
    "Antebrazo izquierdo", "Antebrazo derecho", "Clavicula izquierda", "Clavicula derecha",
    "Cuello", "Mandibula"
};


// Utilidades generales

static SendMsg(playerid, const color[], const msg[])
{
    new buf[256];
    format(buf, sizeof(buf), "%s%s", color, msg);
    SendClientMessage(playerid, -1, buf);
}

stock Float:StrToFloat(const s[])
{
    new i = 0;
    new bool:neg = false;
    if(s[i] == '-') { neg = true; i++; }
    else if(s[i] == '+') i++;

    new Float:result = 0.0;
    while(s[i] >= '0' && s[i] <= '9')
    {
        result = result * 10.0 + (s[i] - '0');
        i++;
    }
    if(s[i] == '.')
    {
        i++;
        new Float:frac = 0.1;
        while(s[i] >= '0' && s[i] <= '9')
        {
            result += (s[i] - '0') * frac;
            frac *= 0.1;
            i++;
        }
    }
    return neg ? (-result) : result;
}

stock bool:IsNumeric(const s[])
{
    new i = 0, c;
    if(s[0] == '\0') return false;
    if(s[0] == '-') i = 1;
    if(s[i] == '\0') return false;
    while((c = s[i++]))
        if(c < '0' || c > '9') return false;
    return true;
}

stock bool:IsValidName(const s[])
{
    new len = strlen(s);
    if(len == 0 || len >= MAX_SESSION_NAME) return false;
    for(new i = 0; i < len; i++)
    {
        new c = s[i];
        if(!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-')) return false;
    }
    return true;
}

static GetBoneNameStr(bone, out[], size)
{
	out[0] = EOS;
    if(bone < 1 || bone > 18) { format(out, size, "-"); return; }
    format(out, size, "%s", g_boneNames[bone - 1]);
}

// Nombres de objeto configurables

static FindObjectNameIndex(modelid)
{
    for(new i = 0; i < g_objName_count; i++)
        if(g_objName_id[i] == modelid) return i;
    return -1;
}

stock bool:IsValidObjectName(const s[])
{
    new len = strlen(s);
    if(len == 0 || len >= MAX_OBJECT_NAME_LEN) return false;
    for(new i = 0; i < len; i++)
        if(s[i] == ',' || s[i] == '\r' || s[i] == '\n') return false;
    return true;
}

static SaveObjectNames()
{
    new File:f = fopen(OBJNAMES_FILE, io_write);
    if(!f) return;
    new line[48 + MAX_OBJECT_NAME_LEN];
    for(new i = 0; i < g_objName_count; i++)
    {
        format(line, sizeof(line), "%i,%s\r\n", g_objName_id[i], g_objName_str[i]);
        fwrite(f, line);
    }
    fclose(f);
}

static LoadObjectNames()
{
    g_objName_count = 0;
    new File:f = fopen(OBJNAMES_FILE, io_read);
    if(!f) return;

    new line[64];
    while(fread(f, line, sizeof(line)) && g_objName_count < MAX_OBJECT_NAMES)
    {
        new len = strlen(line);
        while(len > 0 && (line[len-1] == '\r' || line[len-1] == '\n')) line[--len] = '\0';
        if(len == 0) continue;

        new sep = strfind(line, ",");
        if(sep <= 0) continue;

        new idstr[16];
        strmid(idstr, line, 0, sep, sizeof(idstr));
        if(!IsNumeric(idstr)) continue;

        g_objName_id[g_objName_count] = strval(idstr);
        strmid(g_objName_str[g_objName_count], line, sep + 1, len, MAX_OBJECT_NAME_LEN);
        g_objName_count++;
    }
    fclose(f);
}

// Crea o actualiza el nombre asociado a un modelo. Se guarda al instante.
static bool:SetObjectName(modelid, const name[])
{
    new idx = FindObjectNameIndex(modelid);
    if(idx == -1)
    {
        if(g_objName_count >= MAX_OBJECT_NAMES) return false;
        idx = g_objName_count++;
        g_objName_id[idx] = modelid;
    }
    strmid(g_objName_str[idx], name, 0, strlen(name), MAX_OBJECT_NAME_LEN);
    SaveObjectNames();
    return true;
}

// Devuelve "NombrePersonalizado (#1234)" si existe, o "Modelo #1234"/"Model #1234"
// si no se le ha puesto nombre todavia.
static GetObjectDisplayName(modelid, out[], size)
{
	out[0] = EOS;
    new idx = FindObjectNameIndex(modelid);
    if(idx != -1)
    {
        format(out, size, "%s (#%i)", g_objName_str[idx], modelid);
        return;
    }
    format(out, size, ("Modelo #%i"), modelid);
}

// Prototipos
static ShowMainMenu(playerid);
static ShowSlotList(playerid);
static ShowSlotActions(playerid, id);
static ShowSlotManualMenu(playerid, id);
static ShowBoneList(playerid);
static ShowDuplicateMenu(playerid, id);
static ShowSessionListDialog(playerid);
static ShowHelp(playerid);
static ShowObjectNameInputDialog(playerid, id);
static ClearSession(playerid);
static SaveSession(playerid);
static AutoSaveCurrentSession(playerid);

// Aplicacion en vivo de los objetos adjuntos

static RefreshAttachedObjects(playerid)
{
    for(new i = 0; i < MAX_SLOTS; i++) RemovePlayerAttachedObject(playerid, i);
    for(new i = 0; i < MAX_SLOTS; i++)
    {
        if(!g_slot[playerid][i][slot_used]) continue;
        if(g_slot[playerid][i][slot_hidden]) continue; // oculto: no se aplica al jugador
        SetPlayerAttachedObject(playerid, i,
            g_slot[playerid][i][slot_model], g_slot[playerid][i][slot_bone],
            g_slot[playerid][i][slot_offx], g_slot[playerid][i][slot_offy], g_slot[playerid][i][slot_offz],
            g_slot[playerid][i][slot_rotx], g_slot[playerid][i][slot_roty], g_slot[playerid][i][slot_rotz],
            g_slot[playerid][i][slot_scalex], g_slot[playerid][i][slot_scaley], g_slot[playerid][i][slot_scalez]);
    }
}

static ClearSlot(playerid, id)
{
    g_slot[playerid][id][slot_used]   = false;
    g_slot[playerid][id][slot_model]  = 0;
    g_slot[playerid][id][slot_bone]   = 0;
    g_slot[playerid][id][slot_offx]   = 0.0;
    g_slot[playerid][id][slot_offy]   = 0.0;
    g_slot[playerid][id][slot_offz]   = 0.0;
    g_slot[playerid][id][slot_rotx]   = 0.0;
    g_slot[playerid][id][slot_roty]   = 0.0;
    g_slot[playerid][id][slot_rotz]   = 0.0;
    g_slot[playerid][id][slot_scalex] = 1.0;
    g_slot[playerid][id][slot_scaley] = 1.0;
    g_slot[playerid][id][slot_scalez] = 1.0;
    g_slot[playerid][id][slot_hidden] = false;
}

static CopySlot(playerid, from, to)
{
    g_slot[playerid][to][slot_used]   = g_slot[playerid][from][slot_used];
    g_slot[playerid][to][slot_model]  = g_slot[playerid][from][slot_model];
    g_slot[playerid][to][slot_bone]   = g_slot[playerid][from][slot_bone];
    g_slot[playerid][to][slot_offx]   = g_slot[playerid][from][slot_offx];
    g_slot[playerid][to][slot_offy]   = g_slot[playerid][from][slot_offy];
    g_slot[playerid][to][slot_offz]   = g_slot[playerid][from][slot_offz];
    g_slot[playerid][to][slot_rotx]   = g_slot[playerid][from][slot_rotx];
    g_slot[playerid][to][slot_roty]   = g_slot[playerid][from][slot_roty];
    g_slot[playerid][to][slot_rotz]   = g_slot[playerid][from][slot_rotz];
    g_slot[playerid][to][slot_scalex] = g_slot[playerid][from][slot_scalex];
    g_slot[playerid][to][slot_scaley] = g_slot[playerid][from][slot_scaley];
    g_slot[playerid][to][slot_scalez] = g_slot[playerid][from][slot_scalez];
    g_slot[playerid][to][slot_hidden] = g_slot[playerid][from][slot_hidden];
}

static CountUsedSlots(playerid)
{
    new c = 0;
    for(new i = 0; i < MAX_SLOTS; i++) if(g_slot[playerid][i][slot_used]) c++;
    return c;
}

static GetFreeSlotsList(playerid, out[], maxout)
{
    new c = 0;
    for(new i = 0; i < MAX_SLOTS && c < maxout; i++)
        if(!g_slot[playerid][i][slot_used]) out[c++] = i;
    return c;
}

static Float:GetManualFieldValue(playerid, id, field)
{
    switch(field)
    {
        case MF_OFFX: return g_slot[playerid][id][slot_offx];
        case MF_OFFY: return g_slot[playerid][id][slot_offy];
        case MF_OFFZ: return g_slot[playerid][id][slot_offz];
        case MF_ROTX: return g_slot[playerid][id][slot_rotx];
        case MF_ROTY: return g_slot[playerid][id][slot_roty];
        case MF_ROTZ: return g_slot[playerid][id][slot_rotz];
        case MF_SCALEX: return g_slot[playerid][id][slot_scalex];
        case MF_SCALEY: return g_slot[playerid][id][slot_scaley];
        case MF_SCALEZ: return g_slot[playerid][id][slot_scalez];
    }
    return 0.0;
}

static SetManualFieldValue(playerid, id, field, Float:val)
{
    switch(field)
    {
        case MF_OFFX: g_slot[playerid][id][slot_offx] = val;
        case MF_OFFY: g_slot[playerid][id][slot_offy] = val;
        case MF_OFFZ: g_slot[playerid][id][slot_offz] = val;
        case MF_ROTX: g_slot[playerid][id][slot_rotx] = val;
        case MF_ROTY: g_slot[playerid][id][slot_roty] = val;
        case MF_ROTZ: g_slot[playerid][id][slot_rotz] = val;
        case MF_SCALEX: g_slot[playerid][id][slot_scalex] = val;
        case MF_SCALEY: g_slot[playerid][id][slot_scaley] = val;
        case MF_SCALEZ: g_slot[playerid][id][slot_scalez] = val;
    }
}

static GetManualFieldName(field, out[], size)
{
	out[0] = EOS;
    switch(field)
    {
        case MF_OFFX: format(out, size, "Offset X");
        case MF_OFFY: format(out, size, "Offset Y");
        case MF_OFFZ: format(out, size, "Offset Z");
        case MF_ROTX: format(out, size, ("Rotacion X"));
        case MF_ROTY: format(out, size, ("Rotacion Y"));
        case MF_ROTZ: format(out, size, ("Rotacion Z"));
        case MF_SCALEX: format(out, size, ("Escala X"));
        case MF_SCALEY: format(out, size, ("Escala Y"));
        case MF_SCALEZ: format(out, size, ("Escala Z"));
        default: format(out, size, "?");
    }
}

// Guardado / Carga / Eliminacion de sesiones
// #VERSION=1 #NAME=
// SLOT,idx,modelid,boneid,offx,offy,offz,rotx,roty,rotz,scalex,scaley,scalez

static GetSessionFilename(playerid, out[], size)
{
	out[0] = EOS;
    format(out, size, "%s/%s.eobj", SCRIPTFILES_DIR, g_sess_name[playerid]);
}

static SaveSession(playerid)
{
    new filename[80];
    GetSessionFilename(playerid, filename, sizeof(filename));

    new File:f = fopen(filename, io_write);
    if(!f) { SendMsg(playerid, COLOR_RED, "> Error al guardar la sesion."); return; }

    new line[256];
    fwrite(f, "#VERSION=2\r\n");
    format(line, sizeof(line), "#NAME=%s\r\n", g_sess_name[playerid]);
    fwrite(f, line);

    for(new i = 0; i < MAX_SLOTS; i++)
    {
        if(!g_slot[playerid][i][slot_used]) continue;
        format(line, sizeof(line), "SLOT,%i,%i,%i,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%i\r\n",
            i, g_slot[playerid][i][slot_model], g_slot[playerid][i][slot_bone],
            g_slot[playerid][i][slot_offx], g_slot[playerid][i][slot_offy], g_slot[playerid][i][slot_offz],
            g_slot[playerid][i][slot_rotx], g_slot[playerid][i][slot_roty], g_slot[playerid][i][slot_rotz],
            g_slot[playerid][i][slot_scalex], g_slot[playerid][i][slot_scaley], g_slot[playerid][i][slot_scalez],
            g_slot[playerid][i][slot_hidden] ? 1 : 0);
        fwrite(f, line);
    }
    fclose(f);

    AddToIndex(g_sess_name[playerid]);
    g_ses[playerid][ses_dirty] = false;

    new msg[160];
    format(msg, sizeof(msg), ("> Sesion '%s' guardada."), g_sess_name[playerid]);
    SendMsg(playerid, COLOR_GREEN, msg);
}

static bool:LoadSession(playerid, const name[])
{
    new filename[80];
    format(filename, sizeof(filename), "%s/%s.eobj", SCRIPTFILES_DIR, name);

    new File:f = fopen(filename, io_read);
    if(!f) return false;

    new line[256];
    while(fread(f, line, sizeof(line)))
    {
        new len = strlen(line);
        while(len > 0 && (line[len-1] == '\r' || line[len-1] == '\n')) line[--len] = '\0';
        if(len == 0) continue;

        if(!strcmp(line, "#NAME=", .length = 6))
        {
            // El nombre real de la sesion lo controla quien llama a LoadSession.
        }
        else if(!strcmp(line, "SLOT,", .length = 5))
        {
            new parts[13][24], pc = 0, cur = 0;
            for(new ci = 5; line[ci] != '\0' && pc < 13; ci++)
            {
                if(line[ci] == ',') { parts[pc][cur] = '\0'; pc++; cur = 0; }
                else                  parts[pc][cur++] = line[ci];
            }
            parts[pc][cur] = '\0';

            new idx = strval(parts[0]);
            if(idx >= 0 && idx < MAX_SLOTS)
            {
                g_slot[playerid][idx][slot_used]   = true;
                g_slot[playerid][idx][slot_model]  = strval(parts[1]);
                g_slot[playerid][idx][slot_bone]   = strval(parts[2]);
                g_slot[playerid][idx][slot_offx]   = StrToFloat(parts[3]);
                g_slot[playerid][idx][slot_offy]   = StrToFloat(parts[4]);
                g_slot[playerid][idx][slot_offz]   = StrToFloat(parts[5]);
                g_slot[playerid][idx][slot_rotx]   = StrToFloat(parts[6]);
                g_slot[playerid][idx][slot_roty]   = StrToFloat(parts[7]);
                g_slot[playerid][idx][slot_rotz]   = StrToFloat(parts[8]);
                g_slot[playerid][idx][slot_scalex] = StrToFloat(parts[9]);
                g_slot[playerid][idx][slot_scaley] = StrToFloat(parts[10]);
                g_slot[playerid][idx][slot_scalez] = StrToFloat(parts[11]);
                g_slot[playerid][idx][slot_hidden] = (strval(parts[12]) == 1);
            }
        }
    }
    fclose(f);
    return true;
}

static DeleteSession(const name[])
{
    new filename[80];
    format(filename, sizeof(filename), "%s/%s.eobj", SCRIPTFILES_DIR, name);
    fremove(filename);
    RemoveFromIndex(name);
}

// Indice de sesiones guardadas

static AddToIndex(const name[])
{
    new File:f = fopen(INDEX_FILE, io_read);
    new names[MAX_SESSION_FILES][MAX_SESSION_NAME], count = 0;
    if(f)
    {
        new line[64];
        while(fread(f, line, sizeof(line)) && count < MAX_SESSION_FILES)
        {
            new len = strlen(line);
            while(len > 0 && (line[len-1] == '\r' || line[len-1] == '\n')) line[--len] = '\0';
            if(len > 0)
            {
                new dup = false;
                for(new i = 0; i < count; i++) if(!strcmp(names[i], line, true)) { dup = true; break; }
                if(!dup) { strmid(names[count], line, 0, len, MAX_SESSION_NAME); count++; }
            }
        }
        fclose(f);
    }

    new dup = false;
    for(new i = 0; i < count; i++) if(!strcmp(names[i], name, true)) { dup = true; break; }
    if(!dup && count < MAX_SESSION_FILES) { strmid(names[count], name, 0, strlen(name), MAX_SESSION_NAME); count++; }

    f = fopen(INDEX_FILE, io_write);
    if(!f) return;
    new line[48];
    for(new i = 0; i < count; i++)
    {
        format(line, sizeof(line), "%s\r\n", names[i]);
        fwrite(f, line);
    }
    fclose(f);
}

static RemoveFromIndex(const name[])
{
    new File:f = fopen(INDEX_FILE, io_read);
    if(!f) return;
    new names[MAX_SESSION_FILES][MAX_SESSION_NAME], count = 0;
    new line[64];
    while(fread(f, line, sizeof(line)) && count < MAX_SESSION_FILES)
    {
        new len = strlen(line);
        while(len > 0 && (line[len-1] == '\r' || line[len-1] == '\n')) line[--len] = '\0';
        if(len > 0 && strcmp(line, name, true) != 0)
        {
            strmid(names[count], line, 0, len, MAX_SESSION_NAME);
            count++;
        }
    }
    fclose(f);

    f = fopen(INDEX_FILE, io_write);
    if(!f) return;
    new outline[48];
    for(new i = 0; i < count; i++)
    {
        format(outline, sizeof(outline), "%s\r\n", names[i]);
        fwrite(f, outline);
    }
    fclose(f);
}

static ReadIndex(names[][MAX_SESSION_NAME], maxItems)
{
    new File:f = fopen(INDEX_FILE, io_read);
    if(!f) return 0;
    new count = 0, line[64];
    while(fread(f, line, sizeof(line)) && count < maxItems)
    {
        new len = strlen(line);
        while(len > 0 && (line[len-1] == '\r' || line[len-1] == '\n')) line[--len] = '\0';
        if(len > 0) strmid(names[count++], line, 0, len, MAX_SESSION_NAME);
    }
    fclose(f);
    return count;
}

// Exportacion a codigo PAWN / Importacion desde un archivo ya exportado

static ExportSession(playerid)
{
    if(CountUsedSlots(playerid) == 0) { SendMsg(playerid, COLOR_RED, "> No hay objetos para exportar."); return; }

    new filename[90];
    format(filename, sizeof(filename), "%s/%s_export.txt", SCRIPTFILES_DIR, g_sess_name[playerid]);

    new File:f = fopen(filename, io_write);
    if(!f) { SendMsg(playerid, COLOR_RED, "> Error al crear el archivo de exportacion."); return; }

    new line[256];
    format(line, sizeof(line), ("// Edit Attacher Object - Exportacion de la sesion: %s\r\n"), g_sess_name[playerid]);
    fwrite(f, line);
    fwrite(f, ("// Pega este codigo donde quieras adjuntar los objetos al jugador (OnPlayerSpawn, un comando, etc.)\r\n\r\n"));
    format(line, sizeof(line), "stock ApplyAttachedObjects_%s(playerid)\r\n{\r\n", g_sess_name[playerid]);
    fwrite(f, line);

    for(new i = 0; i < MAX_SLOTS; i++)
    {
        if(!g_slot[playerid][i][slot_used]) continue;
        if(g_slot[playerid][i][slot_hidden]) continue;
        format(line, sizeof(line), "    SetPlayerAttachedObject(playerid, %i, %i, %i, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f);\r\n",
            i, g_slot[playerid][i][slot_model], g_slot[playerid][i][slot_bone],
            g_slot[playerid][i][slot_offx], g_slot[playerid][i][slot_offy], g_slot[playerid][i][slot_offz],
            g_slot[playerid][i][slot_rotx], g_slot[playerid][i][slot_roty], g_slot[playerid][i][slot_rotz],
            g_slot[playerid][i][slot_scalex], g_slot[playerid][i][slot_scaley], g_slot[playerid][i][slot_scalez]);
        fwrite(f, line);
    }
    fwrite(f, "}\r\n");
    fclose(f);

    new msg[160];
    format(msg, sizeof(msg), ("> Exportado en scriptfiles/%s"), filename);
    SendMsg(playerid, COLOR_GREEN, msg);
}

static bool:ImportFromFile(playerid, const name[])
{
    new filename[90];
    new bool:found = false;
    new exts[3][16] = {"_export.txt", ".txt", ".eobj"};

    for(new e = 0; e < 3; e++)
    {
        format(filename, sizeof(filename), "%s/%s%s", SCRIPTFILES_DIR, name, exts[e]);
        if(fexist(filename)) { found = true; break; }
    }
    if(!found) return false;

    if(strfind(filename, ".eobj") != -1)
    {
        ClearSession(playerid);
        return LoadSession(playerid, name);
    }

    new File:fh = fopen(filename, io_read);
    if(!fh) return false;

    ClearSession(playerid);

    new line[256], imported = 0;
    while(fread(fh, line, sizeof(line)))
    {
        new pos = strfind(line, "SetPlayerAttachedObject(");
        if(pos == -1) continue;
        pos += strlen("SetPlayerAttachedObject(");

        new content[220], ci = 0;
        while(line[pos] != ')' && line[pos] != '\0' && ci < 219) { content[ci++] = line[pos++]; }
        content[ci] = '\0';

        new parts[13][24], pc = 0, cur = 0;
        for(new k = 0; content[k] != '\0' && pc < 13; k++)
        {
            if(content[k] == ',') { parts[pc][cur] = '\0'; pc++; cur = 0; }
            else if(content[k] != ' ') parts[pc][cur++] = content[k];
        }
        parts[pc][cur] = '\0';
        if(pc < 12) continue; // linea incompleta, se ignora

        new idx = strval(parts[1]);
        if(idx < 0 || idx >= MAX_SLOTS) continue;

        g_slot[playerid][idx][slot_used]   = true;
        g_slot[playerid][idx][slot_model]  = strval(parts[2]);
        g_slot[playerid][idx][slot_bone]   = strval(parts[3]);
        g_slot[playerid][idx][slot_offx]   = StrToFloat(parts[4]);
        g_slot[playerid][idx][slot_offy]   = StrToFloat(parts[5]);
        g_slot[playerid][idx][slot_offz]   = StrToFloat(parts[6]);
        g_slot[playerid][idx][slot_rotx]   = StrToFloat(parts[7]);
        g_slot[playerid][idx][slot_roty]   = StrToFloat(parts[8]);
        g_slot[playerid][idx][slot_rotz]   = StrToFloat(parts[9]);
        g_slot[playerid][idx][slot_scalex] = StrToFloat(parts[10]);
        g_slot[playerid][idx][slot_scaley] = StrToFloat(parts[11]);
        g_slot[playerid][idx][slot_scalez] = StrToFloat(parts[12]);
        imported++;
    }
    fclose(fh);
    return (imported > 0);
}

// Inicializacion / limpieza de sesion

static ClearSession(playerid)
{
    for(new i = 0; i < MAX_SLOTS; i++) RemovePlayerAttachedObject(playerid, i);
    for(new i = 0; i < MAX_SLOTS; i++) ClearSlot(playerid, i);
    g_sess_name[playerid][0]          = '\0';
    g_ses[playerid][ses_dirty]        = false;
    g_ses[playerid][ses_edit_slot]    = 0;
    g_ses[playerid][ses_manual_field] = 0;
    g_ses[playerid][ses_creating]     = false;
}

static InitPlayerData(playerid)
{
    g_ses[playerid][ses_state] = STATE_IDLE;
    ClearSession(playerid);
}

static AutoSaveCurrentSession(playerid)
{
    if(g_ses[playerid][ses_state] == STATE_EDITING
        && strlen(g_sess_name[playerid]) > 0
        && CountUsedSlots(playerid) > 0
        && g_ses[playerid][ses_dirty])
    {
        SaveSession(playerid);
    }
}

// DIALOGOS

static ShowMainMenu(playerid)
{
    new names[MAX_SESSION_FILES][MAX_SESSION_NAME];
    new count = ReadIndex(names, MAX_SESSION_FILES);

    new body[400];
    format(body, sizeof(body),
        ("Accion\tDetalle\nNueva sesion\t"COLOR_GRAY"Adjuntar objetos nuevos\n"COLOR_RESET"Mis sesiones\t"COLOR_YELLOW"%i guardada(s)\n"COLOR_RESET"Importar exportacion\t"COLOR_GRAY"Leer un .txt ya exportado\n"COLOR_RESET"Ayuda\t"COLOR_GRAY"Como funciona el editor"),
        count);

    ShowPlayerDialog(playerid, DIALOG_MAIN, DIALOG_STYLE_TABLIST_HEADERS,
        (COLOR_GREEN "Edit Attacher Object"),
        body,
        ("Seleccionar"),
        ("Cerrar"));
}

static ShowSessionListDialog(playerid)
{
    new names[MAX_SESSION_FILES][MAX_SESSION_NAME];
    new count = ReadIndex(names, MAX_SESSION_FILES);

    new body[MAX_SESSION_FILES * (MAX_SESSION_NAME + 16) + 32];
    format(body, sizeof(body), ("Nombre\tAccion\n"));

    if(count == 0)
    {
        strcat(body, (COLOR_GRAY "(sin sesiones guardadas)\t \n"), sizeof(body));
    }
    else
    {
        new tmp[64];
        for(new i = 0; i < count; i++)
        {
            format(tmp, sizeof(tmp), ("%s\t"COLOR_GRAY"Cargar\n"), names[i]);
            strcat(body, tmp, sizeof(body));
        }
    }

    ShowPlayerDialog(playerid, DIALOG_LIST_SESSIONS, DIALOG_STYLE_TABLIST_HEADERS,
        (COLOR_GREEN "Mis sesiones"),
        body,
        ("Abrir"),
        ("Volver"));
}

static ShowHelp(playerid)
{
    new body[900];
    format(body, sizeof(body),
        (COLOR_YELLOW"Como funciona\n\n"COLOR_RESET"- "COLOR_GREEN"Nueva sesion"COLOR_RESET": crea un set de hasta %i objetos adjuntos.\n- "COLOR_GREEN"Mis sesiones"COLOR_RESET": carga una sesion guardada antes.\n- "COLOR_GREEN"Guardar / Guardar como"COLOR_RESET": guarda en scriptfiles/%s/.\n- "COLOR_GREEN"Exportar"COLOR_RESET": genera codigo PAWN listo para pegar en tu gamemode.\n- "COLOR_GREEN"Importar exportacion"COLOR_RESET": lee un .txt con lineas SetPlayerAttachedObject(...) ya colocado en scriptfiles/%s/.\n- "COLOR_GREEN"Nombrar objeto"COLOR_RESET": ponle un nombre amigable a un ID de modelo para reconocerlo despues.\n- "COLOR_GREEN"Ocultar/Mostrar objeto"COLOR_RESET": oculta un objeto temporalmente sin perder su configuracion del slot.\n- "COLOR_GREEN"Editar en 3D"COLOR_RESET": usa el gizmo nativo del juego (mouse) para mover, rotar y escalar el objeto.\n- "COLOR_GREEN"/skin <id>"COLOR_RESET": cambia tu skin, ej: /skin 105."),
        MAX_SLOTS, SCRIPTFILES_DIR, SCRIPTFILES_DIR);

    ShowPlayerDialog(playerid, DIALOG_HELP, DIALOG_STYLE_MSGBOX,
        (COLOR_GREEN "Ayuda - Edit Attacher Object"),
        body,
        ("Entendido"), "");
}

static ShowSlotList(playerid)
{
    new body[1500];
    format(body, sizeof(body), ("Slot\tObjeto\n"));

    new tmp[112], objname[48];
    for(new i = 0; i < MAX_SLOTS; i++)
    {
        if(g_slot[playerid][i][slot_used])
        {
            GetObjectDisplayName(g_slot[playerid][i][slot_model], objname, sizeof(objname));
            if(g_slot[playerid][i][slot_hidden])
                format(tmp, sizeof(tmp), (COLOR_RESET"Slot %i\t"COLOR_GRAY"%s (hueso %i) [oculto]\n"),
                    i + 1, objname, g_slot[playerid][i][slot_bone]);
            else
                format(tmp, sizeof(tmp), (COLOR_RESET"Slot %i\t"COLOR_YELLOW"%s "COLOR_GRAY"(hueso %i)\n"),
                    i + 1, objname, g_slot[playerid][i][slot_bone]);
        }
        else
            format(tmp, sizeof(tmp), (COLOR_RESET"Slot %i\t"COLOR_GRAY"(vacio)\n"), i + 1);
        strcat(body, tmp, sizeof(body));
    }

    format(tmp, sizeof(tmp), (COLOR_GREEN"Guardar\t"COLOR_GRAY"%s\n"), g_sess_name[playerid]);
    strcat(body, tmp, sizeof(body));
    strcat(body, (COLOR_RESET"Guardar como...\t"COLOR_GRAY"Renombrar y guardar\n"), sizeof(body));
    strcat(body, (COLOR_RESET"Exportar\t"COLOR_GRAY"Generar codigo PAWN\n"), sizeof(body));
    strcat(body, (COLOR_RED"Vaciar todos los slots\t"COLOR_GRAY"Accion reversible\n"), sizeof(body));
    strcat(body, (COLOR_RED"Eliminar esta sesion\t"COLOR_GRAY"Accion permanente"), sizeof(body));

    new title[64];
    format(title, sizeof(title), (COLOR_GREEN"Sesion: "COLOR_YELLOW"%s"), g_sess_name[playerid]);

    ShowPlayerDialog(playerid, DIALOG_SLOT_LIST, DIALOG_STYLE_TABLIST_HEADERS, title, body,
        ("Seleccionar"), ("Cerrar"));
}

static ShowSlotActions(playerid, id)
{
    g_ses[playerid][ses_edit_slot] = id;

    new title[48];
    format(title, sizeof(title), (COLOR_GREEN"Slot %i"), id + 1);

    new bn[24], objname[48];
    GetBoneNameStr(g_slot[playerid][id][slot_bone], bn, sizeof(bn));
    GetObjectDisplayName(g_slot[playerid][id][slot_model], objname, sizeof(objname));

    new bool:hidden = g_slot[playerid][id][slot_hidden];
    new visRow[64];
    if(hidden)
        format(visRow, sizeof(visRow), "Mostrar objeto\t"COLOR_GRAY"Se mantiene configurado pero invisible\n");
    else
        format(visRow, sizeof(visRow), "Ocultar objeto\t"COLOR_GRAY"Se mantiene configurado pero invisible\n");

    new body[700];
    format(body, sizeof(body),
        ("Accion\tValor actual\nCambiar objeto\t"COLOR_YELLOW"%s\n"COLOR_RESET"Cambiar hueso\t"COLOR_YELLOW"%s\n"COLOR_RESET"Nombrar objeto\t"COLOR_GRAY"Ponle un nombre amigable a este modelo\n"COLOR_RESET"%s"COLOR_RESET"Editar en 3D (gizmo)\t"COLOR_GRAY"Mover/rotar con el mouse\n"COLOR_RESET"Editar valores manualmente\t"COLOR_GRAY"Offset/Rotacion/Escala\n"COLOR_RESET"Duplicar a otro slot\t"COLOR_GRAY"Copiar esta configuracion\n"COLOR_RED"Quitar objeto\t"COLOR_GRAY"Vacia este slot"),
        objname, bn, visRow);

    ShowPlayerDialog(playerid, DIALOG_SLOT_ACTIONS, DIALOG_STYLE_TABLIST_HEADERS, title, body,
        ("Seleccionar"), ("Volver"));
}

static ShowObjectNameInputDialog(playerid, id)
{
    new modelid = g_slot[playerid][id][slot_model];
    new idx = FindObjectNameIndex(modelid);

    new body[160];
    if(idx != -1)
        format(body, sizeof(body), ("Modelo #%i\n"COLOR_GRAY"Nombre actual: %s\n\n"COLOR_RESET"Escribe el nuevo nombre:"),
            modelid, g_objName_str[idx]);
    else
        format(body, sizeof(body), ("Modelo #%i\n"COLOR_GRAY"Aun sin nombre.\n\n"COLOR_RESET"Escribe un nombre para este modelo:"),
            modelid);

    ShowPlayerDialog(playerid, DIALOG_SLOT_NAME_INPUT, DIALOG_STYLE_INPUT,
        (COLOR_GREEN "Nombrar objeto"), body,
        ("Guardar"), ("Cancelar"));
}

static ShowBoneList(playerid)
{
    new body[600];
    body[0] = '\0';
    for(new i = 0; i < 18; i++)
    {
        strcat(body, (g_boneNames[i]), sizeof(body));
        if(i < 17) strcat(body, "\n", sizeof(body));
    }
    ShowPlayerDialog(playerid, DIALOG_SLOT_BONE_LIST, DIALOG_STYLE_LIST,
        (COLOR_GREEN "Selecciona el hueso"),
        body, ("Aceptar"), ("Cancelar"));
}

static ShowSlotManualMenu(playerid, id)
{
    g_ses[playerid][ses_edit_slot] = id;

    new body[512];
    format(body, sizeof(body),
        ("Campo\tValor\nOffset X\t"COLOR_YELLOW"%.4f\n"COLOR_RESET"Offset Y\t"COLOR_YELLOW"%.4f\n"COLOR_RESET"Offset Z\t"COLOR_YELLOW"%.4f\n"COLOR_RESET"Rotacion X\t"COLOR_YELLOW"%.4f\n"COLOR_RESET"Rotacion Y\t"COLOR_YELLOW"%.4f\n"COLOR_RESET"Rotacion Z\t"COLOR_YELLOW"%.4f\n"COLOR_RESET"Escala X\t"COLOR_YELLOW"%.4f\n"COLOR_RESET"Escala Y\t"COLOR_YELLOW"%.4f\n"COLOR_RESET"Escala Z\t"COLOR_YELLOW"%.4f"),
        g_slot[playerid][id][slot_offx], g_slot[playerid][id][slot_offy], g_slot[playerid][id][slot_offz],
        g_slot[playerid][id][slot_rotx], g_slot[playerid][id][slot_roty], g_slot[playerid][id][slot_rotz],
        g_slot[playerid][id][slot_scalex], g_slot[playerid][id][slot_scaley], g_slot[playerid][id][slot_scalez]);

    ShowPlayerDialog(playerid, DIALOG_SLOT_MANUAL_MENU, DIALOG_STYLE_TABLIST_HEADERS,
        (COLOR_GREEN "Editar valores"),
        body, ("Editar"), ("Volver"));
}

static ShowDuplicateMenu(playerid, id)
{
    new free[MAX_SLOTS];
    new fc = GetFreeSlotsList(playerid, free, MAX_SLOTS);
    if(fc == 0)
    {
        SendMsg(playerid, COLOR_RED, "> No hay slots libres para duplicar.");
        ShowSlotActions(playerid, id);
        return;
    }

    new body[256];
    body[0] = '\0';
    new tmp[24];
    for(new i = 0; i < fc; i++)
    {
        format(tmp, sizeof(tmp), ("Slot %i\n"), free[i] + 1);
        strcat(body, tmp, sizeof(body));
    }

    ShowPlayerDialog(playerid, DIALOG_DUPLICATE_SLOT, DIALOG_STYLE_LIST,
        (COLOR_GREEN "Duplicar a..."),
        body, ("Copiar"), ("Cancelar"));
}

// CALLBACKS DE FILTERSCRIPT

#if defined FILTERSCRIPT

public OnFilterScriptInit()
{
    print(" ");
	print("**      ______    _ _ _           _   _             _      ____  _     _           _        **");
	print("**     |  ____|  | (_) |     /\\  | | | |           | |    / __ \\| |   (_)         | |       **");
	print("**     | |__   __| |_| |_   /  \\ | |_| |_ __ _  ___| |__ | |  | | |__  _  ___  ___| |_      **");
	print("**     |  __| / _` | | __| / /\\ \\| __| __/ _` |/ __| '_ \\| |  | | '_ \\| |/ _ \\/ __| __|     **");
	print("**     | |___| (_| | | |_ / ____ \\ |_| || (_| | (__| | | | |__| | |_) | |  __/ (__| |_      **");
	print("**     |______\\__,_|_|\\__/_/    \\_\\__|\\__\\__,_|\\___|_| |_|\\____/|_.__/| |\\___|\\___|\\__|     **");
	print("**                                                                   _/ |                   **");
	print("**                                                                  |__/                    **");
	print("**                                                                                          **");
	print("**                                   Creado por not                                         **");
	print("**                                                                                          **");
	print("**                             Version: "VERSION" (2026 release)                                 **");
	print("**                                                                                          **");
	print("**              Sistema de creación y edición de objetos adjuntos al jugador.               **");
	print("**                                                                                          **");
    print(" ");

    if(!fexist(INDEX_FILE))
    {
        new File:f = fopen(INDEX_FILE, io_write);
        if(f) fclose(f);
    }

    LoadObjectNames();

    for(new i = 0; i < MAX_PLAYERS; i++) InitPlayerData(i);
    return 1;
}

public OnFilterScriptExit()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i)) AutoSaveCurrentSession(i);
    }
    return 1;
}

#endif

public OnPlayerConnect(playerid)
{
    InitPlayerData(playerid);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    AutoSaveCurrentSession(playerid);
    return 1;
}

// COMANDOS

public OnPlayerCommandText(playerid, const cmdtext[])
{
    if(!strcmp(cmdtext, "/attobjedit", true))
    {
        if(g_ses[playerid][ses_state] == STATE_EDITING) ShowSlotList(playerid);
        else ShowMainMenu(playerid);
        return 1;
    }

    if(!strcmp(cmdtext, "/skin", true, 5) && (cmdtext[5] == '\0' || cmdtext[5] == ' '))
    {

        new p = 5;
        while(cmdtext[p] == ' ') p++;

        new params[16], i = 0;
        while(cmdtext[p] != '\0' && i < 15) params[i++] = cmdtext[p++];
        params[i] = '\0';

        if(!strlen(params) || !IsNumeric(params))
        {
            SendMsg(playerid, COLOR_RED, "> Uso: /skin <id> (ej: /skin 105).");
            return 1;
        }

        new skinid = strval(params);
        if(skinid < 0 || skinid > 311)
        {
            SendMsg(playerid, COLOR_RED, "> ID de skin invalido (usa un numero entre 0 y 311).");
            return 1;
        }

        SetPlayerSkin(playerid, skinid);
        RefreshAttachedObjects(playerid); // por si el cambio de skin reinicia los huesos

        new msg[96];
        format(msg, sizeof(msg), ("* Skin cambiada a #%i."), skinid);
        SendMsg(playerid, COLOR_GREEN, msg);
        return 1;
    }

    return 0;
}

// MANEJO DE DIALOGOS

public OnDialogResponse(playerid, dialogid, response, listitem, const inputtext[])
{
    switch(dialogid)
    {
        // ------------------------------------------------------------------
        case DIALOG_MAIN:
        {
            if(!response) return 1;
            switch(listitem)
            {
                case 0: ShowPlayerDialog(playerid, DIALOG_NEW_NAME, DIALOG_STYLE_INPUT,
                    COLOR_GREEN "Nueva sesion",
                    "Nombre de la sesion:\n" COLOR_GRAY "(letras, numeros, - o _, max 31)",
                    "Crear", "Cancelar");
                case 1: ShowSessionListDialog(playerid);
                case 2: ShowPlayerDialog(playerid, DIALOG_IMPORT_INPUT, DIALOG_STYLE_INPUT,
                    COLOR_GREEN "Importar exportacion",
                    "Nombre del archivo (sin extension) ya\ncolocado en scriptfiles/" SCRIPTFILES_DIR "/:",
                    "Importar", "Cancelar");
                case 3: ShowHelp(playerid);
            }
            return 1;
        }

        // ------------------------------------------------------------------
        case DIALOG_NEW_NAME:
        {
            if(!response) return 1;
            if(!IsValidName(inputtext))
            {
                SendMsg(playerid, COLOR_RED, "> Nombre invalido (usa letras, numeros, - o _, max 31).");
                ShowPlayerDialog(playerid, DIALOG_NEW_NAME, DIALOG_STYLE_INPUT,
                    COLOR_GREEN "Nueva sesion",
                    "Nombre de la sesion:\n" COLOR_GRAY "(letras, numeros, - o _, max 31)",
                    "Crear", "Cancelar");
                return 1;
            }
            ClearSession(playerid);
            strmid(g_sess_name[playerid], inputtext, 0, strlen(inputtext), MAX_SESSION_NAME);
            g_ses[playerid][ses_state] = STATE_EDITING;
            SendMsg(playerid, COLOR_GREEN, "* Sesion creada. Elige un slot para adjuntar tu primer objeto.");
            ShowSlotList(playerid);
            return 1;
        }

        // ------------------------------------------------------------------
        case DIALOG_LIST_SESSIONS:
        {
            if(!response) { ShowMainMenu(playerid); return 1; }

            new names[MAX_SESSION_FILES][MAX_SESSION_NAME];
            new count = ReadIndex(names, MAX_SESSION_FILES);
            if(listitem < 0 || listitem >= count) { ShowMainMenu(playerid); return 1; }

            ClearSession(playerid);
            if(LoadSession(playerid, names[listitem]))
            {
                strmid(g_sess_name[playerid], names[listitem], 0, strlen(names[listitem]), MAX_SESSION_NAME);
                g_ses[playerid][ses_state] = STATE_EDITING;
                RefreshAttachedObjects(playerid);
                SendMsg(playerid, COLOR_GREEN, "* Sesion cargada.");
                ShowSlotList(playerid);
            }
            else
            {
                SendMsg(playerid, COLOR_RED, "> No se pudo cargar esa sesion (archivo no encontrado).");
                RemoveFromIndex(names[listitem]);
                ShowMainMenu(playerid);
            }
            return 1;
        }

        // ------------------------------------------------------------------
        case DIALOG_IMPORT_INPUT:
        {
            if(!response) { ShowMainMenu(playerid); return 1; }
            if(!strlen(inputtext)) { SendMsg(playerid, COLOR_RED, "> Escribe un nombre de archivo."); ShowMainMenu(playerid); return 1; }

            if(ImportFromFile(playerid, inputtext))
            {
                SendMsg(playerid, COLOR_GREEN, "* Archivo leido correctamente. Ahora ponle nombre a esta sesion:");
                ShowPlayerDialog(playerid, DIALOG_IMPORT_NAME, DIALOG_STYLE_INPUT,
                    COLOR_GREEN "Nombre de sesion",
                    "¿Como quieres llamar a esta sesion importada?",
                    "Continuar", "Cancelar");
            }
            else
            {
                SendMsg(playerid, COLOR_RED, "> No se encontro ese archivo en scriptfiles/" SCRIPTFILES_DIR "/.");
                ShowMainMenu(playerid);
            }
            return 1;
        }

        // ------------------------------------------------------------------
        case DIALOG_IMPORT_NAME:
        {
            if(!response) { ClearSession(playerid); ShowMainMenu(playerid); return 1; }
            if(!IsValidName(inputtext))
            {
                SendMsg(playerid, COLOR_RED, "> Nombre invalido.");
                ShowPlayerDialog(playerid, DIALOG_IMPORT_NAME, DIALOG_STYLE_INPUT,
                    COLOR_GREEN "Nombre de sesion",
                    "¿Como quieres llamar a esta sesion importada?",
                    "Continuar", "Cancelar");
                return 1;
            }
            strmid(g_sess_name[playerid], inputtext, 0, strlen(inputtext), MAX_SESSION_NAME);
            g_ses[playerid][ses_state] = STATE_EDITING;
            g_ses[playerid][ses_dirty] = true;
            RefreshAttachedObjects(playerid);
            SendMsg(playerid, COLOR_GREEN, "* ¡Objetos importados y aplicados! No olvides guardar la sesion.");
            ShowSlotList(playerid);
            return 1;
        }

        // ------------------------------------------------------------------
        case DIALOG_HELP:
        {
            ShowMainMenu(playerid);
            return 1;
        }

        // ------------------------------------------------------------------
        case DIALOG_SLOT_LIST:
        {
            if(!response) return 1; // Cerrar: los objetos siguen puestos, /attobjedit vuelve a abrir este menu


            if(listitem < MAX_SLOTS)
            {
                new id = listitem;
                g_ses[playerid][ses_edit_slot] = id;
                if(g_slot[playerid][id][slot_used])
                {
                    ShowSlotActions(playerid, id);
                }
                else
                {
                    g_ses[playerid][ses_creating] = true;
                    ShowPlayerDialog(playerid, DIALOG_SLOT_MODEL_INPUT, DIALOG_STYLE_INPUT,
                        COLOR_GREEN "Nuevo objeto",
                        "Escribe el ID del objeto (modelo) a adjuntar:",
                        "Siguiente", "Cancelar");
                }
                return 1;
            }

            switch(listitem - MAX_SLOTS)
            {
                case 0: { SaveSession(playerid); ShowSlotList(playerid); }
                case 1: ShowPlayerDialog(playerid, DIALOG_SAVE_AS, DIALOG_STYLE_INPUT,
                    COLOR_GREEN "Guardar como",
                    "Nuevo nombre para esta sesion:",
                    "Guardar", "Cancelar");
                case 2: { ExportSession(playerid); ShowSlotList(playerid); }
                case 3: ShowPlayerDialog(playerid, DIALOG_CONFIRM_REMOVE_ALL, DIALOG_STYLE_MSGBOX,
                    COLOR_RED "Confirmar",
                    "¿Quitar todos los objetos adjuntos de esta sesion?",
                    "Si", "Cancelar");
                case 4: ShowPlayerDialog(playerid, DIALOG_CONFIRM_DELETE_SESSION, DIALOG_STYLE_MSGBOX,
                    COLOR_RED "Confirmar",
                    "¿Eliminar esta sesion guardada de forma permanente?",
                    "Si", "Cancelar");
            }
            return 1;
        }

        // ------------------------------------------------------------------
        case DIALOG_SLOT_ACTIONS:
        {
            new id = g_ses[playerid][ses_edit_slot];
            if(!response) { ShowSlotList(playerid); return 1; }

            switch(listitem)
            {
                case 0:
                {
                    g_ses[playerid][ses_creating] = false;
                    ShowPlayerDialog(playerid, DIALOG_SLOT_MODEL_INPUT, DIALOG_STYLE_INPUT,
                        COLOR_GREEN "Cambiar objeto",
                        "Nuevo ID de objeto (modelo):",
                        "Aceptar", "Cancelar");
                }
                case 1:
                {
                    g_ses[playerid][ses_creating] = false;
                    ShowBoneList(playerid);
                }
                case 2: ShowObjectNameInputDialog(playerid, id);
                case 3:
                {
                    g_slot[playerid][id][slot_hidden] = !g_slot[playerid][id][slot_hidden];
                    g_ses[playerid][ses_dirty] = true;
                    RefreshAttachedObjects(playerid);
                    if(g_slot[playerid][id][slot_hidden])
                        SendMsg(playerid, COLOR_ORANGE, "> Objeto oculto (sigue configurado en el slot).");
                    else
                        SendMsg(playerid, COLOR_GREEN, "> Objeto visible de nuevo.");
                    ShowSlotActions(playerid, id);
                }
                case 4: EditAttachedObject(playerid, id);
                case 5: ShowSlotManualMenu(playerid, id);
                case 6: ShowDuplicateMenu(playerid, id);
                case 7: ShowPlayerDialog(playerid, DIALOG_CONFIRM_REMOVE_SLOT, DIALOG_STYLE_MSGBOX,
                    COLOR_RED "Confirmar",
                    "¿Quitar el objeto de este slot?",
                    "Si", "Cancelar");
            }
            return 1;
        }

        // ------------------------------------------------------------------
        case DIALOG_SLOT_NAME_INPUT:
        {
            new id = g_ses[playerid][ses_edit_slot];
            if(!response) { ShowSlotActions(playerid, id); return 1; }
            if(!strlen(inputtext) || !IsValidObjectName(inputtext))
            {
                SendMsg(playerid, COLOR_RED, "> Nombre invalido (sin comas, max 31 caracteres).");
                ShowObjectNameInputDialog(playerid, id);
                return 1;
            }
            SetObjectName(g_slot[playerid][id][slot_model], inputtext);
            SendMsg(playerid, COLOR_GREEN, "* Nombre de objeto guardado.");
            ShowSlotActions(playerid, id);
            return 1;
        }

        // ------------------------------------------------------------------
        case DIALOG_SLOT_MODEL_INPUT:
        {
            new id = g_ses[playerid][ses_edit_slot];
            if(!response)
            {
                if(g_slot[playerid][id][slot_used]) ShowSlotActions(playerid, id); else ShowSlotList(playerid);
                return 1;
            }
            if(!strlen(inputtext) || !IsNumeric(inputtext))
            {
                SendMsg(playerid, COLOR_RED, "> Escribe solo numeros para el ID del objeto.");
                ShowPlayerDialog(playerid, DIALOG_SLOT_MODEL_INPUT, DIALOG_STYLE_INPUT,
                    COLOR_GREEN "ID de objeto",
                    "Escribe el ID del objeto (modelo):",
                    "Aceptar", "Cancelar");
                return 1;
            }

            g_slot[playerid][id][slot_model] = strval(inputtext);

            if(g_ses[playerid][ses_creating])
            {
                ShowBoneList(playerid);
            }
            else
            {
                g_ses[playerid][ses_dirty] = true;
                RefreshAttachedObjects(playerid);
                SendMsg(playerid, COLOR_GREEN, "* Objeto actualizado.");
                ShowSlotActions(playerid, id);
            }
            return 1;
        }

        // ------------------------------------------------------------------
        case DIALOG_SLOT_BONE_LIST:
        {
            new id = g_ses[playerid][ses_edit_slot];
            if(!response)
            {
                if(g_ses[playerid][ses_creating]) ShowSlotList(playerid); else ShowSlotActions(playerid, id);
                return 1;
            }

            g_slot[playerid][id][slot_bone] = listitem + 1;

            if(g_ses[playerid][ses_creating])
            {
                g_slot[playerid][id][slot_used]   = true;
                g_slot[playerid][id][slot_offx]   = 0.0;
                g_slot[playerid][id][slot_offy]   = 0.0;
                g_slot[playerid][id][slot_offz]   = 0.0;
                g_slot[playerid][id][slot_rotx]   = 0.0;
                g_slot[playerid][id][slot_roty]   = 0.0;
                g_slot[playerid][id][slot_rotz]   = 0.0;
                g_slot[playerid][id][slot_scalex] = 1.0;
                g_slot[playerid][id][slot_scaley] = 1.0;
                g_slot[playerid][id][slot_scalez] = 1.0;
                SendMsg(playerid, COLOR_GREEN, "* ¡Objeto adjuntado!");
            }
            else
            {
                SendMsg(playerid, COLOR_GREEN, "* Hueso actualizado.");
            }

            g_ses[playerid][ses_dirty] = true;
            RefreshAttachedObjects(playerid);
            ShowSlotActions(playerid, id);
            return 1;
        }

        // ------------------------------------------------------------------
        case DIALOG_SLOT_MANUAL_MENU:
        {
            new id = g_ses[playerid][ses_edit_slot];
            if(!response) { ShowSlotActions(playerid, id); return 1; }

            g_ses[playerid][ses_manual_field] = listitem;

            new fname[24];
            GetManualFieldName(listitem, fname, sizeof(fname));
            new Float:cur = GetManualFieldValue(playerid, id, listitem);

            new body[160];
            format(body, sizeof(body), "%s\n"COLOR_GRAY"Valor actual: %.4f\n\n"COLOR_RESET"Escribe el nuevo valor:", fname, cur);

            ShowPlayerDialog(playerid, DIALOG_SLOT_MANUAL_INPUT, DIALOG_STYLE_INPUT,
                COLOR_GREEN "Editar valor", body,
                "Aceptar", "Cancelar");
            return 1;
        }

        // ------------------------------------------------------------------
        case DIALOG_SLOT_MANUAL_INPUT:
        {
            new id = g_ses[playerid][ses_edit_slot];
            if(!response) { ShowSlotManualMenu(playerid, id); return 1; }
            if(!strlen(inputtext)) { SendMsg(playerid, COLOR_RED, "> Escribe un valor."); ShowSlotManualMenu(playerid, id); return 1; }

            new Float:val = StrToFloat(inputtext);
            SetManualFieldValue(playerid, id, g_ses[playerid][ses_manual_field], val);
            g_ses[playerid][ses_dirty] = true;
            RefreshAttachedObjects(playerid);
            SendMsg(playerid, COLOR_GREEN, "* Valor actualizado.");
            ShowSlotManualMenu(playerid, id);
            return 1;
        }

        // ------------------------------------------------------------------
        case DIALOG_DUPLICATE_SLOT:
        {
            new id = g_ses[playerid][ses_edit_slot];
            if(!response) { ShowSlotActions(playerid, id); return 1; }

            new free[MAX_SLOTS];
            new fc = GetFreeSlotsList(playerid, free, MAX_SLOTS);
            if(listitem < 0 || listitem >= fc) { ShowSlotActions(playerid, id); return 1; }

            new dest = free[listitem];
            CopySlot(playerid, id, dest);
            g_ses[playerid][ses_dirty] = true;
            RefreshAttachedObjects(playerid);
            SendMsg(playerid, COLOR_GREEN, "* Objeto duplicado.");
            ShowSlotList(playerid);
            return 1;
        }

        // ------------------------------------------------------------------
        case DIALOG_SAVE_AS:
        {
            if(!response) { ShowSlotList(playerid); return 1; }
            if(!IsValidName(inputtext))
            {
                SendMsg(playerid, COLOR_RED, "> Nombre invalido (usa letras, numeros, - o _, max 31).");
                ShowPlayerDialog(playerid, DIALOG_SAVE_AS, DIALOG_STYLE_INPUT,
                    COLOR_GREEN "Guardar como",
                    "Nuevo nombre para esta sesion:",
                    "Guardar", "Cancelar");
                return 1;
            }
            strmid(g_sess_name[playerid], inputtext, 0, strlen(inputtext), MAX_SESSION_NAME);
            g_ses[playerid][ses_dirty] = true;
            SaveSession(playerid);
            ShowSlotList(playerid);
            return 1;
        }

        // ------------------------------------------------------------------
        case DIALOG_CONFIRM_REMOVE_SLOT:
        {
            new id = g_ses[playerid][ses_edit_slot];
            if(response)
            {
                ClearSlot(playerid, id);
                g_ses[playerid][ses_dirty] = true;
                RefreshAttachedObjects(playerid);
                SendMsg(playerid, COLOR_ORANGE, "> Objeto quitado del slot.");
            }
            ShowSlotList(playerid);
            return 1;
        }

        // ------------------------------------------------------------------
        case DIALOG_CONFIRM_REMOVE_ALL:
        {
            if(response)
            {
                for(new i = 0; i < MAX_SLOTS; i++) ClearSlot(playerid, i);
                g_ses[playerid][ses_dirty] = true;
                RefreshAttachedObjects(playerid);
                SendMsg(playerid, COLOR_ORANGE, "> Todos los objetos fueron quitados.");
            }
            ShowSlotList(playerid);
            return 1;
        }

        // ------------------------------------------------------------------
        case DIALOG_CONFIRM_DELETE_SESSION:
        {
            if(response)
            {
                DeleteSession(g_sess_name[playerid]);
                SendMsg(playerid, COLOR_ORANGE, "> Sesion eliminada.");
                ClearSession(playerid);
                g_ses[playerid][ses_state] = STATE_IDLE;
                ShowMainMenu(playerid);
            }
            else ShowSlotList(playerid);
            return 1;
        }
    }
    return 0;
}

// Gizmo nativo de edicion (EditAttachedObject)

public OnPlayerEditAttachedObject(playerid, response, index, modelid, boneid, Float:fOffsetX, Float:fOffsetY, Float:fOffsetZ, Float:fRotX, Float:fRotY, Float:fRotZ, Float:fScaleX, Float:fScaleY, Float:fScaleZ)
{
    #pragma unused modelid
    if(g_ses[playerid][ses_state] != STATE_EDITING) return 1;
    if(index < 0 || index >= MAX_SLOTS) return 1;

    if(response == EDIT_RESPONSE_CANCEL)
    {
        RefreshAttachedObjects(playerid); // restaura la posicion guardada
        SendMsg(playerid, COLOR_YELLOW, "> Edicion 3D cancelada.");
        ShowSlotActions(playerid, index);
        return 1;
    }

    if(response == EDIT_RESPONSE_FINAL)
    {
        g_slot[playerid][index][slot_bone]   = boneid;
        g_slot[playerid][index][slot_offx]   = fOffsetX;
        g_slot[playerid][index][slot_offy]   = fOffsetY;
        g_slot[playerid][index][slot_offz]   = fOffsetZ;
        g_slot[playerid][index][slot_rotx]   = fRotX;
        g_slot[playerid][index][slot_roty]   = fRotY;
        g_slot[playerid][index][slot_rotz]   = fRotZ;
        g_slot[playerid][index][slot_scalex] = fScaleX;
        g_slot[playerid][index][slot_scaley] = fScaleY;
        g_slot[playerid][index][slot_scalez] = fScaleZ;
        g_ses[playerid][ses_dirty] = true;
        SendMsg(playerid, COLOR_GREEN, "* Objeto actualizado.");
        ShowSlotActions(playerid, index);
    }
    return 1;
}
