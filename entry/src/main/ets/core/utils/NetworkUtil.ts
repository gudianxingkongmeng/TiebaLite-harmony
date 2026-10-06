import connection from '@ohos.net.connection';

export default class NetworkUtil {
  static isWifi(): Promise<boolean> {
    return new Promise((resolve) => {
      try {
        connection.getDefaultNet().then((netHandle: connection.NetHandle) => {
          connection.getNetCapabilities(netHandle).then((caps: connection.NetCapabilities) => {
            let wifi = false;
            try {
              wifi = caps.bearerTypes.includes(connection.NetBearType.BEARER_WIFI);
            } catch (_) { wifi = false; }
            resolve(wifi);
          }).catch(() => resolve(false));
        }).catch(() => resolve(false));
      } catch (e) {
        resolve(false);
      }
    });
  }

  static async publishWifiState(): Promise<void> {
    try {
      AppStorage.SetOrCreate<boolean>('netIsWifi', await this.isWifi());
    } catch (e) {
      AppStorage.SetOrCreate<boolean>('netIsWifi', true);
    }
  }
}
