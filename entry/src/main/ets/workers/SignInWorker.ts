import worker from '@ohos.worker';
import http from '@ohos.net.http';
import { BusinessError } from '@kit.BasicServicesKit';
import { Dict } from '../core/types/Dict';

const workerPort = worker.workerPort;

workerPort.onmessage = (event: { data: Dict }) => {
  const eventData: Dict = event.data;
  const type: string = String(eventData.type || '');
  const data: Dict = eventData.data as Dict;
  if (type === 'start') {
    const forumIds: number[] = data.forumIds as number[];
    const tbs: string = String(data.tbs || '');
    const results: Dict[] = [];
    let processed: number = 0;

    const doNext = (): void => {
      if (processed >= forumIds.length) {
        workerPort.postMessage({ type: 'complete', data: results });
        return;
      }
      const forumId: number = forumIds[processed];
      const httpRequest: http.HttpRequest = http.createHttp();
      httpRequest.request(
        'https://tieba.baidu.com/c/c/forum/sign',
        {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/x-www-form-urlencoded' },
          extraData: 'tbs=' + encodeURIComponent(tbs) + '&forum_id=' + String(forumId)
        },
        (err: BusinessError | null, response: http.HttpResponse) => {
          if (!err) {
            try {
              const json: Dict = JSON.parse(response.result as string) as Dict;
              results.push({
                forumId: forumId,
                success: json.error_code === '0',
                msg: String(json.error_msg || 'ok')
              } as Dict);
            } catch (e) {
              results.push({
                forumId: forumId,
                success: false,
                msg: 'parse error'
              } as Dict);
            }
          } else {
            results.push({
              forumId: forumId,
              success: false,
              msg: err.message || 'network error'
            } as Dict);
          }
          processed++;
          doNext();
        }
      );
    };

    doNext();
  }
};
