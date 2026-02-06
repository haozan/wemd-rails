import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"
import type { TomInput, TomSettings, RecursivePartial } from "tom-select/dist/types/types"

/**
 * Tom Select Controller
 *
 * Enhances native <select> elements with search, multi-select, and AJAX capabilities
 * Note: Select form fields automatically use this controller
 *
 * Usage:
 *   <%= form.select :category_id, options, {}, {
 *     data: {
 *       controller: "tom-select",
 *       tom_select_max_items_value: 5,
 *       tom_select_placeholder_value: "Select tags..."
 *     },
 *     multiple: true
 *   } %>
 *
 * Values:
 *   - placeholder (String): Placeholder text for the select
 *   - maxItems (Number): Maximum number of items for multi-select
 *   - searchField (Array, default: ["text"]): Fields to search in
 *   - allowEmptyOption (Boolean, default: true): Allow empty/null selection
 *   - create (Boolean, default: false): Allow creating new options
 *   - plugins (Array, default: []): Tom Select plugins - "remove_button", "clear_button", "dropdown_header"
 *
 * Actions:
 *   - clear: Clear all selections
 *   - addOption: Add a new option programmatically
 *   - refresh: Refresh options list
 */

// stimulus-validator: system-controller
export default class extends Controller {
  static values = {
    placeholder: String,
    maxItems: Number,
    searchField: { type: Array, default: ["text"] },
    allowEmptyOption: { type: Boolean, default: true },
    create: { type: Boolean, default: false },
    plugins: { type: Array, default: [] }
  }

  declare placeholderValue: string
  declare maxItemsValue: number
  declare searchFieldValue: string[]
  declare allowEmptyOptionValue: boolean
  declare createValue: boolean
  declare pluginsValue: string[]

  declare readonly hasPlaceholderValue: boolean
  declare readonly hasMaxItemsValue: boolean

  private tomSelect: TomSelect | null = null
  private scrollHandler: (() => void) | null = null

  connect() {
    const element = this.element as HTMLSelectElement

    // Save original classes before Tom Select modifies them
    const originalClasses = element.className.split(' ').filter(cls => cls.trim() !== '')

    // Build configuration
    const config = {
      // Core options
      allowEmptyOption: this.allowEmptyOptionValue,
      searchField: this.searchFieldValue,

      // Disable input for single select - null disables typing
      // (TypeScript types are incorrect, but Tom Select docs support null)
      controlInput: null as any,

      // Fix z-index stacking context issue by rendering dropdown in body
      dropdownParent: 'body',

      // Placeholder
      ...(this.hasPlaceholderValue && {
        placeholder: this.placeholderValue
      }),

      // Max items (for multi-select)
      ...(this.hasMaxItemsValue && {
        maxItems: this.maxItemsValue
      }),

      // Allow creating new options
      ...(this.createValue && {
        create: true,
        createOnBlur: true
      }),

      // Plugins - auto-enable remove_button for multi-select
      plugins: this.buildPlugins(element.multiple),

      // Keyboard navigation
      closeAfterSelect: !element.multiple,

      // Performance
      loadThrottle: 300,

      // Rendering
      render: {
        no_results: () => {
          return '<div class="no-results">No results found</div>'
        }
      }
    }

    // Initialize Tom Select
    this.tomSelect = new TomSelect(element, config)

    // Copy original classes to ts-control (before Tom Select added its own classes)
    // This allows form-select, field-error, and other custom classes to style the control
    if (this.tomSelect && originalClasses.length > 0) {
      const control = this.tomSelect.control
      const wrapper = this.tomSelect.wrapper

      if (control) {
        originalClasses.forEach(cls => {
          // Add to control
          control.classList.add(cls)
          // Remove from wrapper (Tom Select might have copied them there)
          if (wrapper) {
            wrapper.classList.remove(cls)
          }
        })
      }
    }

    // Handle scroll events - reposition dropdown when scrolling
    this.scrollHandler = () => {
      if (this.tomSelect && this.tomSelect.isOpen) {
        this.tomSelect.positionDropdown()
      }
    }

    // Listen to scroll events on window and scrollable parents
    // Use passive: true for better scroll performance
    window.addEventListener('scroll', this.scrollHandler, { capture: true, passive: true })
  }

  disconnect() {
    // Remove scroll event listener
    if (this.scrollHandler) {
      window.removeEventListener('scroll', this.scrollHandler, { capture: true })
      this.scrollHandler = null
    }

    if (this.tomSelect) {
      this.tomSelect.destroy()
      this.tomSelect = null
    }
  }

  // Public API: Clear selection
  clear() {
    if (this.tomSelect) {
      this.tomSelect.clear()
    }
  }

  // Public API: Add option
  addOption(value: string, text: string) {
    if (this.tomSelect) {
      this.tomSelect.addOption({ value, text })
    }
  }

  // Public API: Refresh options
  refresh() {
    if (this.tomSelect) {
      this.tomSelect.refreshOptions(false)
    }
  }

  private buildPlugins(isMultiple: boolean = false): string[] | Record<string, any> {
    const plugins: Record<string, any> = {}

    // Auto-enable remove_button for multi-select
    if (isMultiple) {
      plugins['remove_button'] = {
        title: 'Remove this item',
        label: '×',
        className: 'remove'
      }
    }

    // Add user-specified plugins
    this.pluginsValue.forEach(plugin => {
      switch (plugin) {
        case 'remove_button':
          plugins['remove_button'] = {
            title: 'Remove this item',
            label: '×',
            className: 'remove'
          }
          break
        case 'clear_button':
          plugins['clear_button'] = { title: 'Clear All' }
          break
        case 'dropdown_header':
          plugins['dropdown_header'] = {}
          break
        default:
          plugins[plugin] = {}
      }
    })

    return Object.keys(plugins).length > 0 ? plugins : []
  }
}
