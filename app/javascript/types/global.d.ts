// Global type declarations
import { Application } from "@hotwired/stimulus"

declare global {
  interface Window {
    Stimulus: Application;
    ActionCable: any;
    Turbo: any;
    App: {
      adminSidebar?: any;
    };
    restoreButtonStates: () => void;
    errorHandler: ErrorHandler;
    stimulusValidator: any;
    copyToClipboard: (text: string) => Promise<boolean>;
    sdkUtils: any;
    sendToSDK: (message: string) => boolean;
    sendErrorToSDK: (errorInfo: any) => boolean;
    isSDKAvailable: () => boolean;
    showToast: (message: string, type?: 'success' | 'error' | 'info' | 'warning' | 'danger', position?: 'top-right' | 'top-center' | 'top-left', duration?: number) => void;
    sdk?: {
      send: (message: string) => void;
    };
  }

  var App: {
    adminSidebar?: any;
  };
}

// ActionCable types
declare module '@rails/actioncable' {
  export function createConsumer(url?: string): any;
  export * as ActionCable from '@rails/actioncable';
  
  interface Consumer {
    subscriptions: any;
  }
  
  interface Channel {
    perform: (action: string, data?: any) => void;
    send: (data: any) => void;
  }
}

// ActiveStorage types
declare module '@rails/activestorage' {
  export function start(): void;
}

export {};
