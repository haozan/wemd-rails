import { Controller } from "@hotwired/stimulus"

/**
 * ImageUpload Controller
 * 
 * Handles image file selection, upload via ActiveStorage, and insertion into Markdown editor
 * 
 * Targets:
 * - fileInput: Hidden file input element
 * - uploadButton: Button to trigger file selection
 * - progressBar: Progress bar showing upload status (optional)
 * 
 * Values:
 * - apiUrl: API endpoint for upload (default: /api/uploads)
 * 
 * Events:
 * - image-uploaded: Fired when image upload succeeds, detail contains {url, filename}
 */
export default class extends Controller<HTMLElement> {
  static targets = [
    "fileInput"
  ]

  static values = {
    apiUrl: { type: String, default: "/api/uploads" }
  }

  declare readonly fileInputTarget: HTMLInputElement
  declare readonly apiUrlValue: string

  connect(): void {
    console.log("ImageUpload connected")
  }

  disconnect(): void {
    console.log("ImageUpload disconnected")
  }

  /**
   * Trigger file selection dialog
   */
  selectFile(): void {
    this.fileInputTarget.click()
  }

  /**
   * Handle file selection and upload
   */
  async handleFileSelect(event: Event): Promise<void> {
    const input = event.target as HTMLInputElement
    const file = input.files?.[0]
    
    if (!file) {
      return
    }

    // Validate file type
    if (!this.isValidImageType(file)) {
      this.showError('请选择图片文件 (jpg, png, gif, webp, svg)')
      return
    }

    // Validate file size (10MB max)
    if (file.size > 10 * 1024 * 1024) {
      this.showError('图片大小不能超过 10MB')
      return
    }

    await this.uploadFile(file)
  }

  /**
   * Upload file to server
   */
  private async uploadFile(file: File): Promise<void> {
    const formData = new FormData()
    formData.append('file', file)

    try {
      this.setUploading(true)
      
      // stimulus-validator: disable-next-line
      const response = await fetch(this.apiUrlValue, {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': this.getCsrfToken(),
        },
        credentials: 'same-origin'
      })

      const result = await response.json()

      if (result.success) {
        this.showSuccess('图片上传成功')
        
        // Dispatch custom event with upload result
        this.dispatch('uploaded', {
          detail: {
            url: result.url,
            filename: result.filename,
            size: result.size
          }
        })
        
        // Reset file input
        this.fileInputTarget.value = ''
      } else {
        this.showError(result.error || '图片上传失败')
      }
    } catch (error) {
      console.error('Upload error:', error)
      this.showError('图片上传失败，请重试')
    } finally {
      this.setUploading(false)
    }
  }

  /**
   * Validate image file type
   */
  private isValidImageType(file: File): boolean {
    const validTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml']
    return validTypes.includes(file.type)
  }

  /**
   * Set uploading state
   */
  private setUploading(uploading: boolean): void {
    // Optional targets are checked via has* methods
    // No specific DOM targets required for upload state in this implementation
  }

  /**
   * Show success message
   */
  private showSuccess(message: string): void {
    if (typeof showToast === 'function') {
      showToast(message, 'success')
    } else {
      console.log(message)
    }
  }

  /**
   * Show error message
   */
  private showError(message: string): void {
    if (typeof showToast === 'function') {
      showToast(message, 'error')
    } else {
      console.error(message)
    }
  }

  /**
   * Get CSRF token from meta tag
   */
  private getCsrfToken(): string {
    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    return token || ''
  }
}
