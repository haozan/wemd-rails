import { Application } from "@hotwired/stimulus"

import ThemeController from "./theme_controller"
import DropdownController from "./dropdown_controller"
import SdkIntegrationController from "./sdk_integration_controller"
import ClipboardController from "./clipboard_controller"
import TomSelectController from "./tom_select_controller"
import FlatpickrController from "./flatpickr_controller"
import SystemMonitorController from "./system_monitor_controller"
import FlashController from "./flash_controller"
import WemdEditorController from "./wemd_editor_controller"
import MarkdownRendererController from "./markdown_renderer_controller"
import ImageUploadController from "./image_upload_controller"
import HistoryPanelController from "./history_panel_controller"
import RedirectController from "./redirect_controller"
import ThemeSyncController from "./theme_sync_controller"
import CalendarController from "./calendar_controller"

const application = Application.start()

application.register("theme", ThemeController)
application.register("dropdown", DropdownController)
application.register("sdk-integration", SdkIntegrationController)
application.register("clipboard", ClipboardController)
application.register("tom-select", TomSelectController)
application.register("flatpickr", FlatpickrController)
application.register("system-monitor", SystemMonitorController)
application.register("flash", FlashController)
application.register("wemd-editor", WemdEditorController)
application.register("markdown-renderer", MarkdownRendererController)
application.register("image-upload", ImageUploadController)
application.register("history-panel", HistoryPanelController)
application.register("redirect", RedirectController)
application.register("theme-sync", ThemeSyncController)
application.register("calendar", CalendarController)

window.Stimulus = application
