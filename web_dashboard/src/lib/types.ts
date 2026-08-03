export interface ProductUnit {
  id?: number
  unit_name: string
  conversion_qty: number
  price_sell: number
}

export interface Product {
  id: number
  sku: string | null
  barcode: string | null
  name: string
  category_id: number | null
  category_name: string | null
  photo_path: string | null
  unit_base: string
  price_buy: number
  price_sell: number
  stock: number
  stock_alert_threshold: number
  is_favorite: boolean
  is_active: boolean
  units: ProductUnit[]
  created_at: string | null
}

export interface Category {
  id: number
  name: string
}

export interface ProductListResponse {
  items: Product[]
  page: number
  page_size: number
  total: number
}

export interface StockAlert {
  id: number
  name: string
  sku: string | null
  stock: number
  stock_alert_threshold: number
  status: 'habis' | 'menipis'
}

export interface StockLogItem {
  id: number
  product_id: number
  product_name: string
  change_qty: number
  reason: string
  reference_id: number | null
  created_at: string | null
}

export interface DebtEntry {
  id: number
  transaction_id: number | null
  amount: number
  amount_paid: number
  remaining: number
  status: string
  due_date: string | null
  created_at: string | null
}

export interface CustomerDebt {
  customer_id: number
  customer_name: string
  phone: string | null
  debts: DebtEntry[]
  total_debt: number
  total_paid: number
  due_date_min: string | null
}

export interface Summary {
  total_transactions: number
  omzet: number
  avg_belanja: number
  items_sold: number
}

export interface ReportsSummary {
  today: Summary
  this_month: Summary
  low_stock_count: number
}

export interface TopProduct {
  product_id: number
  product_name: string
  qty_sold: number
  revenue: number
}

export interface TransactionItem {
  id: number
  product_id: number
  product_name_snapshot: string
  unit_name: string
  qty: number
  price_per_unit: number
  subtotal: number
}

export interface Transaction {
  id: number
  invoice_no: string
  customer_id: number | null
  total_amount: number
  discount_amount: number
  payment_method: string
  cash_received: number | null
  change_amount: number | null
  payment_split_json: string | null
  status: string
  device_id: string | null
  synced: boolean
  created_at: string | null
  items: TransactionItem[]
}

export interface TransactionListResponse {
  items: Transaction[]
  total: number
}

export interface DailyReport {
  date: string
  summary: Summary
  by_method: Record<string, number>
  transactions: number
}

export interface MonthlyReport {
  month: number
  year: number
  summary: Summary
  daily: Record<string, number>
}

export interface HealthInfo {
  status: string
  app: string
  time: string
}

export interface SettingsInfo {
  store_name: string
  pin_set: boolean
  backup_enabled: boolean
  backup_hour: string
}

export interface BackupFile {
  filename: string
  size: number
  created_at: string
}
