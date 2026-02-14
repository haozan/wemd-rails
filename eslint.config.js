const eslint = require('@eslint/js')
const tseslint = require('@typescript-eslint/eslint-plugin')
const tsparser = require('@typescript-eslint/parser')

module.exports = [
  eslint.configs.recommended,
  {
    files: ['app/javascript/**/*.ts'],
    plugins: {
      '@typescript-eslint': tseslint,
    },
    languageOptions: {
      parser: tsparser,
      parserOptions: {
        ecmaVersion: 2022,
        sourceType: 'module',
      },
      globals: {
        ...require('globals').browser,
        App: 'readonly',
        showToast: 'readonly',
        NodeListOf: 'readonly',
      },
    },
    rules: {
      '@typescript-eslint/no-unused-vars': 'off',
      'no-unused-vars': 'off',
      '@typescript-eslint/explicit-function-return-type': 'off',
      '@typescript-eslint/explicit-module-boundary-types': 'off',
      '@typescript-eslint/no-explicit-any': 'off',

      'prefer-const': 'error',
      'no-var': 'error',
      'object-shorthand': 'off',
      'prefer-template': 'error',

      'eqeqeq': ['error', 'always'],
      'no-console': 'off',
      'no-debugger': 'error',
      'no-alert': 'error',
      'no-restricted-globals': ['error',
        {
          name: 'alert',
          message: 'Use showToast(message, type) instead. Example: showToast("Success!", "success")'
        },
        {
          name: 'confirm',
          message: 'Use custom modal or showToast() for confirmations instead of confirm()'
        },
        {
          name: 'prompt',
          message: 'Use custom input modal instead of prompt()'
        }
      ],
      'no-unused-expressions': 'error',
      'no-useless-return': 'off',

      'semi': 'off',
      'quotes': 'off',
      'comma-dangle': 'off',
      'indent': ['error', 2, { SwitchCase: 1 }],
      'max-len': ['error', { code: 180, ignoreUrls: true }],
    },
  },
  {
    files: ['app/javascript/controllers/**/*.ts'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
    },
  },
  {
    files: ['**/*.d.ts'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-unused-vars': 'off',
      'no-unused-vars': 'off',
      'no-undef': 'off',
    },
  },
  {
    files: ['app/javascript/error_handler.ts'],
    rules: {
      'no-alert': 'off',
      'no-restricted-globals': 'off',
    },
  },
  {
    files: ['app/javascript/controllers/theme_sync_controller.ts'],
    rules: {
      'no-alert': 'off',
      'no-restricted-globals': 'off',
    },
  },
  {
    files: ['app/javascript/controllers/history_panel_controller.ts'],
    rules: {
      'no-alert': 'off',
      'no-restricted-globals': 'off',
    },
  },
  {
    ignores: [
      'node_modules/',
      'app/assets/builds/',
      'public/',
      'tmp/',
      'log/',
      'storage/',
      'vendor/',
      'config/',
      'db/',
      'lib/',
      'spec/',
      'test/',
      '**/*.config.js',
      '**/*.min.js',
    ],
  },
]
