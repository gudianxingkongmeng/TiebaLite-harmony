import { Dict } from '../types/Dict';
import { TiebaApi } from '../api/TiebaApi';
import ITiebaApi from '../api/ITiebaApi';

export default class HotTopicRepository {
  private static instance: HotTopicRepository;
  private api: ITiebaApi;

  private constructor() {
    this.api = TiebaApi.getInstance();
  }

  static getInstance(): HotTopicRepository {
    if (!HotTopicRepository.instance) {
      HotTopicRepository.instance = new HotTopicRepository();
    }
    return HotTopicRepository.instance;
  }

  async loadTopicList(): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.topicList({
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }
}
