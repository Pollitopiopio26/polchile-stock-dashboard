// ═══════════════════════════════════════════════════════════════════════════
//   FASE 2 · SINCRONIZACIÓN SHEETS → SUPABASE · POLCHILE
//   Agrega este archivo como un .gs más dentro del MISMO proyecto de Apps
//   Script que ya tiene Code.gs (comparten el mismo SS_ID).
// ═══════════════════════════════════════════════════════════════════════════

/**
 * CONFIGURACIÓN REQUERIDA (una sola vez):
 * 1. En el editor de Apps Script → ⚙️ Configuración del proyecto
 *    → Propiedades de secuencia de comandos → Agregar propiedad:
 *      SUPABASE_URL          = https://ffxopvzxyeacpbtxuagu.supabase.co
 *      SUPABASE_SERVICE_KEY  = tu service_role key CLÁSICA (pestaña "Legacy
 *                               API Keys" en Supabase, formato JWT que
 *                               empieza con "eyJ..."). NO uses la nueva
 *                               "sb_secret_...", esa bloquea las llamadas
 *                               de Apps Script (error 401 "browser").
 *                               NUNCA subas este valor a GitHub.
 * 2. Corre una vez manualmente la función sincronizarTodo() para probar.
 * 3. Corre crearTriggerSincronizacion() UNA VEZ para dejar la sincronización
 *    automática cada 30 minutos.
 */

function getSupabaseConfig_() {
  const props = PropertiesService.getScriptProperties();
  const url = props.getProperty('SUPABASE_URL');
  const key = props.getProperty('SUPABASE_SERVICE_KEY');
  if (!url || !key) {
    throw new Error('Faltan las Propiedades de secuencia de comandos SUPABASE_URL / SUPABASE_SERVICE_KEY.');
  }
  return { url: url.replace(/\/$/, ''), key: key };
}

/**
 * Hace upsert de un array de objetos a una tabla de Supabase vía PostgREST.
 */
function upsertSupabase_(tabla, filas) {
  if (!filas.length) return;
  const cfg = getSupabaseConfig_();

  const LOTE = 500;
  for (let i = 0; i < filas.length; i += LOTE) {
    const lote = filas.slice(i, i + LOTE);
    const response = UrlFetchApp.fetch(cfg.url + '/rest/v1/' + tabla, {
      method: 'post',
      contentType: 'application/json',
      headers: {
        apikey: cfg.key,
        Authorization: 'Bearer ' + cfg.key,
        Prefer: 'resolution=merge-duplicates,return=minimal'
      },
      payload: JSON.stringify(lote),
      muteHttpExceptions: true
    });

    const codigo = response.getResponseCode();
    if (codigo >= 300) {
      throw new Error("Error subiendo a '" + tabla + "' (HTTP " + codigo + "): " + response.getContentText());
    }
  }
}

/**
 * Lee una hoja completa como array de objetos, usando la fila 1 como headers
 * (en minúscula, tal como ya se usa en Code.gs).
 */
function leerHojaComoObjetos_(hoja) {
  const data = hoja.getDataRange().getValues();
  const headers = data[0].map(h => h.toString().trim().toLowerCase());
  const filas = [];
  for (let i = 1; i < data.length; i++) {
    const fila = data[i];
    const obj = {};
    headers.forEach((h, idx) => { obj[h] = fila[idx]; });
    filas.push(obj);
  }
  return filas;
}

function sincronizarCatalogo_(ss) {
  const hoja = ss.getSheetByName('Catalogo');
  if (!hoja) { Logger.log("No se encontró 'Catalogo', se omite."); return; }

  const filas = leerHojaComoObjetos_(hoja)
    .filter(function(r){ return r.codigo; })
    .map(function(r){
      return {
        codigo: String(r.codigo).trim(),
        producto: String(r.producto || '').trim(),
        familia: String(r.familia || 'Sin familia').trim(),
        tipo: String(r.tipo || '').trim(),
        precio: parseFloat(r.precio) || 0,
        stock_total: parseFloat(r.stock_total) || 0
      };
    });

  upsertSupabase_('catalogo', filas);
  Logger.log('Catalogo: ' + filas.length + ' filas sincronizadas.');
}

function sincronizarStock_(ss) {
  const hoja = ss.getSheetByName('Stock');
  if (!hoja) { Logger.log("No se encontró 'Stock', se omite."); return; }

  const filas = leerHojaComoObjetos_(hoja)
    .filter(function(r){ return r.codigo; })
    .map(function(r){
      return {
        codigo: String(r.codigo).trim().toUpperCase(),
        bodega_nombre: String(r.bodega_nombre || 'Sin bodega').trim(),
        nombre: String(r.nombre || '').trim(),
        unidmed: String(r.unidmed || '').trim(),
        stk_fisico: parseFloat(r.stk_fisico) || 0
      };
    });

  upsertSupabase_('stock', filas);
  Logger.log('Stock: ' + filas.length + ' filas sincronizadas.');
}

function sincronizarProductosSegunda_(ss) {
  const hoja = ss.getSheetByName('Productos Segunda');
  if (!hoja) { Logger.log("No se encontró 'Productos Segunda', se omite."); return; }

  const filas = leerHojaComoObjetos_(hoja)
    .filter(function(r){ return r.codigo; })
    .map(function(r){
      return {
        codigo: String(r.codigo).trim().toUpperCase(),
        bodega_nombre: String(r.bodega_nombre || 'Bodega de segunda').trim(),
        nombre: String(r.nombre || '').trim(),
        unidmed: String(r.unidmed || '').trim(),
        stk_fisico: parseFloat(r.stk_fisico) || 0
      };
    });

  upsertSupabase_('productos_segunda', filas);
  Logger.log('Productos Segunda: ' + filas.length + ' filas sincronizadas.');
}

function sincronizarVentas_(ss) {
  const hoja = ss.getSheetByName('Stock Vendido');
  if (!hoja) { Logger.log("No se encontró 'Stock Vendido', se omite."); return; }

  const data = hoja.getDataRange().getValues();
  const headers = data[0].map(function(h){ return h.toString().trim().toLowerCase(); });

  const idx = {
    nota: headers.indexOf('nota_de_venta'),
    bodegaId: headers.indexOf('bodega_id'),
    bodegaNombre: headers.indexOf('bodega_nombre'),
    codigo: headers.indexOf('codigo_de_producto'),
    descripcion: headers.indexOf('descripcion'),
    unidmed: headers.indexOf('unidmed'),
    cantidad: headers.indexOf('q_solicitado'),
    valor: headers.indexOf('valor_total'),
    fecha: headers.indexOf('fecha_nv')
  };

  const filas = [];
  for (let i = 1; i < data.length; i++) {
    const fila = data[i];
    const codigo = idx.codigo > -1 ? String(fila[idx.codigo] || '').trim() : '';
    const nota = idx.nota > -1 ? fila[idx.nota] : null;
    if (!codigo || !nota) continue;

    let fechaStr = null;
    if (idx.fecha > -1 && fila[idx.fecha]) {
      const f = fila[idx.fecha];
      fechaStr = (f instanceof Date)
        ? Utilities.formatDate(f, Session.getScriptTimeZone(), 'yyyy-MM-dd')
        : String(f);
    }

    filas.push({
      nota_de_venta: Number(nota),
      bodega_id: idx.bodegaId > -1 ? String(fila[idx.bodegaId] || '').trim() : '',
      bodega_nombre: idx.bodegaNombre > -1 ? String(fila[idx.bodegaNombre] || '').trim() : '',
      codigo: codigo.toUpperCase(),
      descripcion: idx.descripcion > -1 ? String(fila[idx.descripcion] || '').trim() : '',
      unidmed: idx.unidmed > -1 ? String(fila[idx.unidmed] || '').trim() : '',
      cantidad: parseFloat(fila[idx.cantidad]) || 0,
      valor_total: parseFloat(fila[idx.valor]) || 0,
      fecha: fechaStr
    });
  }

  upsertSupabase_('ventas', filas);
  Logger.log('Ventas: ' + filas.length + ' filas sincronizadas.');
}

/**
 * Función principal: corre las 4 sincronizaciones.
 * Puedes ejecutarla manualmente desde el editor para probar.
 */
function sincronizarTodo() {
  const ss = SpreadsheetApp.openById(SS_ID); // usa el mismo SS_ID de Code.gs
  sincronizarCatalogo_(ss);
  sincronizarStock_(ss);
  sincronizarProductosSegunda_(ss);
  sincronizarVentas_(ss);
  Logger.log('Sincronización completa.');
}


/**
 * Corre esto UNA SOLA VEZ para dejar la sincronización automática
 * cada 30 minutos. Si ya existe un trigger de esta función, no crea otro.
 */
function crearTriggerSincronizacion() {
  const yaExiste = ScriptApp.getProjectTriggers()
    .some(function(t){ return t.getHandlerFunction() === 'sincronizarTodo'; });

  if (yaExiste) {
    Logger.log('Ya existe un trigger para sincronizarTodo(). No se creó otro.');
    return;
  }

  ScriptApp.newTrigger('sincronizarTodo')
    .timeBased()
    .everyMinutes(30)
    .create();

  Logger.log('Trigger creado: sincronizarTodo() correrá cada 30 minutos.');
}
