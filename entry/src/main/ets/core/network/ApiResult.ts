export class ApiResult<T> {
  readonly data: T | null;
  readonly errorCode: number;
  readonly errorMsg: string;
  readonly success: boolean;

  private constructor(data: T | null, errorCode: number, errorMsg: string, success: boolean) {
    this.data = data;
    this.errorCode = errorCode;
    this.errorMsg = errorMsg;
    this.success = success;
  }

  static success<T>(data: T): ApiResult<T> {
    return new ApiResult(data, 0, "", true);
  }

  static failure<T>(errorCode: number, errorMsg: string): ApiResult<T> {
    return new ApiResult(null, errorCode, errorMsg, false);
  }
}
