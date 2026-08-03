import { Navigate, Route, Routes } from 'react-router-dom'
import Layout from './components/layout'
import Dashboard from './pages/Dashboard'
import Debts from './pages/Debts'
import Products from './pages/Products'
import Reports from './pages/Reports'
import Settings from './pages/Settings'
import Stock from './pages/Stock'

export default function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/reports" element={<Reports />} />
        <Route path="/products" element={<Products />} />
        <Route path="/stock" element={<Stock />} />
        <Route path="/debts" element={<Debts />} />
        <Route path="/settings" element={<Settings />} />
      </Route>
      <Route path="/" element={<Navigate to="/dashboard" replace />} />
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  )
}
