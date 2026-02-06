import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"
import type { Instance } from "flatpickr/dist/types/instance"
import type { Options } from "flatpickr/dist/types/options"

/**
 * Flatpickr Controller
 *
 * Enhances text inputs with date/time picker
 * Note: Date/datetime form fields automatically use this controller
 *
 * Usage:
 *   <%= form.text_field :published_at,
 *     data: {
 *       controller: "flatpickr",
 *       flatpickr_enable_time_value: true,
 *       flatpickr_mode_value: "range"
 *     }
 *   %>
 *
 * Values:
 *   - enableTime (Boolean, default: false): Enable time picker
 *   - noCalendar (Boolean, default: false): Hide calendar, show time only
 *   - mode (String, default: "single"): Selection mode - "single", "multiple", or "range"
 *   - dateFormat (String): Date format for form submission (auto-detected if not set)
 *   - altFormat (String): Display format shown to user (auto-detected if not set)
 *   - minDate (String): Minimum selectable date
 *   - maxDate (String): Maximum selectable date
 *   - disable (Array): Array of dates to disable
 *   - enable (Array): Array of dates to enable (disables all others)
 *   - inline (Boolean, default: false): Display calendar inline instead of dropdown
 *   - time24hr (Boolean, default: true): Use 24-hour time format
 *   - defaultDate (String): Default selected date
 *   - defaultHour (Number, default: 12): Default hour for time picker
 *   - defaultMinute (Number, default: 0): Default minute for time picker
 *
 * Actions:
 *   - setDate: Set date programmatically
 *   - clear: Clear selected date
 *   - open: Open calendar
 *   - close: Close calendar
 */

// stimulus-validator: system-controller
export default class extends Controller {
  static values = {
    enableTime: { type: Boolean, default: false },
    noCalendar: { type: Boolean, default: false },
    mode: { type: String, default: "single" }, // single, multiple, range
    dateFormat: String,
    altFormat: String,
    minDate: String,
    maxDate: String,
    disable: Array,
    enable: Array,
    inline: { type: Boolean, default: false },
    time24hr: { type: Boolean, default: true },
    defaultDate: String,
    defaultHour: { type: Number, default: 12 },
    defaultMinute: { type: Number, default: 0 }
  }

  declare enableTimeValue: boolean
  declare noCalendarValue: boolean
  declare modeValue: string
  declare dateFormatValue: string
  declare altFormatValue: string
  declare minDateValue: string
  declare maxDateValue: string
  declare disableValue: string[]
  declare enableValue: string[]
  declare inlineValue: boolean
  declare time24hrValue: boolean
  declare defaultDateValue: string
  declare defaultHourValue: number
  declare defaultMinuteValue: number

  declare readonly hasDateFormatValue: boolean
  declare readonly hasAltFormatValue: boolean
  declare readonly hasMinDateValue: boolean
  declare readonly hasMaxDateValue: boolean
  declare readonly hasDefaultDateValue: boolean

  private fp: Instance | null = null

  connect() {
    const element = this.element as HTMLInputElement

    // Build configuration
    const config: Partial<Options> = {
      // Date/Time mode
      enableTime: this.enableTimeValue,
      noCalendar: this.noCalendarValue,
      time_24hr: this.time24hrValue,

      // Selection mode
      mode: this.modeValue as any,

      // Display settings
      altInput: true, // Show user-friendly format
      altFormat: this.getAltFormat(),
      dateFormat: this.getDateFormat(),

      // Inline calendar (if specified)
      inline: this.inlineValue,

      // Default values
      ...(this.hasDefaultDateValue && {
        defaultDate: this.defaultDateValue
      }),
      defaultHour: this.defaultHourValue,
      defaultMinute: this.defaultMinuteValue,

      // Min/Max dates
      ...(this.hasMinDateValue && {
        minDate: this.minDateValue
      }),
      ...(this.hasMaxDateValue && {
        maxDate: this.maxDateValue
      }),

      // Disable/Enable specific dates
      ...(this.disableValue.length > 0 && {
        disable: this.disableValue
      }),
      ...(this.enableValue.length > 0 && {
        enable: this.enableValue
      }),

      // Behavior
      allowInput: true, // Allow manual input
      clickOpens: true,
      closeOnSelect: this.modeValue === "single",

      // Week numbers (optional enhancement)
      weekNumbers: false,

      // Localization
      locale: {
        firstDayOfWeek: 1 // Monday
      },

      // Events
      onChange: (selectedDates: Date[], dateStr: string) => {
        // Dispatch custom event for other controllers
        this.element.dispatchEvent(
          new CustomEvent('flatpickr:change', {
            detail: { selectedDates, dateStr },
            bubbles: true
          })
        )
      }
    }

    // Initialize Flatpickr
    this.fp = flatpickr(element, config)
  }

  disconnect() {
    if (this.fp) {
      this.fp.destroy()
      this.fp = null
    }
  }

  // Public API: Set date programmatically
  setDate(date: string | Date) {
    if (this.fp) {
      this.fp.setDate(date)
    }
  }

  // Public API: Clear date
  clear() {
    if (this.fp) {
      this.fp.clear()
    }
  }

  // Public API: Open calendar
  open() {
    if (this.fp) {
      this.fp.open()
    }
  }

  // Public API: Close calendar
  close() {
    if (this.fp) {
      this.fp.close()
    }
  }

  private getDateFormat(): string {
    if (this.hasDateFormatValue) {
      return this.dateFormatValue
    }

    // Auto-detect format based on mode
    if (this.enableTimeValue) {
      return "Y-m-d H:i" // Rails datetime format
    }
    return "Y-m-d" // Rails date format
  }

  private getAltFormat(): string {
    if (this.hasAltFormatValue) {
      return this.altFormatValue
    }

    // User-friendly format
    if (this.enableTimeValue && this.noCalendarValue) {
      return "h:i K" // Time only: "3:30 PM"
    } else if (this.enableTimeValue) {
      return "F j, Y at h:i K" // "January 15, 2024 at 3:30 PM"
    }
    return "F j, Y" // "January 15, 2024"
  }
}
