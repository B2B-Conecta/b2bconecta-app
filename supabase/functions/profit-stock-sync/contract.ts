export const schemaVersion = 2;
export const maxBodyBytes = 65536;
export const expectedProjectRef = "kdrccmqcrruixuworlmz";
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const object = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === "object" && !Array.isArray(value);
function keys(value: Record<string, unknown>, required: string[]): boolean {
  return Object.keys(value).length === required.length && required.every((key) => Object.hasOwn(value, key));
}
export interface StockRow {
  co_art: string;
  unidad: "UNI";
  stock_actual: number;
  stock_comprometido: number;
}
export interface StockBatch {
  schema_version: 2;
  mode: "stock_only";
  installation_id: string;
  batch_id: string;
  source_sequence: number;
  observed_at: string;
  source: { erp: "Profit"; database: "MOTO"; warehouse: "GM" };
  rows: StockRow[];
}
export function validateBatch(value: unknown): value is StockBatch {
  if (!object(value) || !keys(value, ["schema_version", "mode", "installation_id", "batch_id", "source_sequence", "observed_at", "source", "rows"])) return false;
  if (value.schema_version !== schemaVersion || value.mode !== "stock_only" ||
    typeof value.installation_id !== "string" || !uuid.test(value.installation_id) ||
    typeof value.batch_id !== "string" || !uuid.test(value.batch_id) ||
    !Number.isSafeInteger(value.source_sequence) || (value.source_sequence as number) < 1 ||
    typeof value.observed_at !== "string" ||
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:Z|[+-]\d{2}:\d{2})$/.test(value.observed_at) ||
    !Number.isFinite(Date.parse(value.observed_at))) return false;
  if (!object(value.source) || !keys(value.source, ["erp", "database", "warehouse"]) ||
    value.source.erp !== "Profit" || value.source.database !== "MOTO" || value.source.warehouse !== "GM") return false;
  if (!Array.isArray(value.rows) || value.rows.length < 1 || value.rows.length > 20) return false;
  const codes = new Set<string>();
  for (const row of value.rows) {
    if (!object(row) || !keys(row, ["co_art", "unidad", "stock_actual", "stock_comprometido"]) ||
      typeof row.co_art !== "string" || row.co_art.length < 1 || row.co_art.length > 128 ||
      row.co_art.includes("\u0000") || row.unidad !== "UNI" || codes.has(row.co_art)) return false;
    if (![row.stock_actual, row.stock_comprometido].every((n) => Number.isInteger(n) && (n as number) >= 0 && (n as number) <= 2147483647)) return false;
    codes.add(row.co_art); // Claves exactas: sin trim/cambio de mayúsculas.
  }
  return true;
}
