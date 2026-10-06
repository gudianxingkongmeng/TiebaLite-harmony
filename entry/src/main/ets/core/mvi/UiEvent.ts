export default interface UiEvent {}

export enum CommonUiEventType {
  TOAST_ERROR,
  TOAST,
  NAVIGATE_UP
}

export class CommonUiEvent implements UiEvent {
  readonly type: CommonUiEventType;
  readonly message: string;
  readonly code?: number;

  constructor(type: CommonUiEventType, message: string, code?: number) {
    this.type = type;
    this.message = message;
    this.code = code;
  }

  static toastError(message: string, code?: number): CommonUiEvent {
    return new CommonUiEvent(CommonUiEventType.TOAST_ERROR, message, code);
  }

  static toast(message: string): CommonUiEvent {
    return new CommonUiEvent(CommonUiEventType.TOAST, message);
  }

  static navigateUp(): CommonUiEvent {
    return new CommonUiEvent(CommonUiEventType.NAVIGATE_UP, "");
  }
}
