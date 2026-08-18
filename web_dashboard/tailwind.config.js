/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: '#A8402E',
        primaryDark: '#7E2F21',
        accentGreen: '#2F5233',
        success: '#3D7A4A',
        warning: '#C17A1F',
        danger: '#B33A3A',
        background: '#FBF6EC',
        surface: '#FFFFFF',
        textPrimary: '#2A211C',
        textSecondary: '#8A7A6B',
        border: '#E8DCC8',
      },
      fontFamily: {
        sans: ['"Plus Jakarta Sans"', 'system-ui', '-apple-system', 'sans-serif'],
        display: ['"Fraunces"', 'Georgia', 'serif'],
        mono: ['"JetBrains Mono"', 'monospace'],
      },
      borderRadius: {
        card: '16px',
        button: '10px',
        input: '8px',
      },
    },
  },
  plugins: [],
}
