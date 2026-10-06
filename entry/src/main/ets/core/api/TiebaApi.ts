import ITiebaApi from './ITiebaApi';
import MixedTiebaApiImpl from './impl/MixedTiebaApiImpl';

export class TiebaApi {
  private static instance: ITiebaApi;

  static getInstance(): ITiebaApi {
    if (!TiebaApi.instance) {
      TiebaApi.instance = new MixedTiebaApiImpl();
    }
    return TiebaApi.instance;
  }
}
