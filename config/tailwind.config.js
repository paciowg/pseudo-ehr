const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}',
    './node_modules/flowbite/**/*.js'
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
    require('flowbite/plugin'),
  ],
  extend: {
    animation: {
      bounce: 'bounce 1s infinite',
      bounce200: 'bounce 1s infinite 200ms',
      bounce400: 'bounce 1s infinite 400ms',
    },
    keyframes: {
      bounce: {
        '0%, 100%': { transform: 'translateY(-25%)', opacity: '0.3' },
        '50%': { transform: 'none', opacity: '1' },
      },
    },
  }
}
