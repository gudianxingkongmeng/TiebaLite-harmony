import Window from '@ohos.window';

export async function setPageStatusBar(context: Object, _primaryColor: string, isDark: boolean, _bgColor?: string): Promise<void> {
  try {
    const win = await Window.getLastWindow(context as any);
    const iconColor = isDark ? '#FFFFFF' : '#000000';
    win.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: iconColor,
      navigationBarContentColor: iconColor
    });
    try { win.setWindowSystemBarEnable(['status']); } catch (_) {}
  } catch (e) {
    console.warn('TiebaLite: setPageStatusBar error: ' + JSON.stringify(e));
  }
}

export async function setDarkStatusBar(context: Object): Promise<void> {
  try {
    const win = await Window.getLastWindow(context as any);
    win.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: '#FFFFFF',
      navigationBarContentColor: '#FFFFFF'
    });
    try { win.setWindowSystemBarEnable(['status']); } catch (_) {}
  } catch (e) {
    console.warn('TiebaLite: setDarkStatusBar error: ' + JSON.stringify(e));
  }
}
