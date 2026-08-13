let _pendingDeepLink: string = '';

export function setPendingDeepLink(json: string): void {
  _pendingDeepLink = json;
}

export function consumePendingDeepLink(): string {
  const v: string = _pendingDeepLink;
  _pendingDeepLink = '';
  return v;
}
