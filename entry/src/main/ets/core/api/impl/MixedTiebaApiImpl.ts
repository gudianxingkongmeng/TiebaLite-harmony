import { Dict } from '../../types/Dict';
import ITiebaApi, { ApiCallback } from '../ITiebaApi';
import { HttpClient } from '../../network/HttpClient';
import { API_BASE_URLS, ClientVersion, PARAM, HEADER } from '../../network/HttpConstants';
import { URLS, PROTO_CMDS } from '../ApiConstants';
import AccountManager from '../../auth/AccountManager';
import DeviceFingerprint from '../../device/DeviceFingerprint';
import { encodeAddPostReq, decodeAddPostRes, IAddPostReqParams } from '../../../proto/AddPostProto';
import { encodeGeneralTabListReq, decodeGeneralTabListRes } from '../../../proto/GeneralTabListProto';


export default class MixedTiebaApiImpl implements ITiebaApi {
  private http: HttpClient;

  constructor() {
    this.http = HttpClient.getInstance();
  }

  personalized(loadType: number, page: number, callback: ApiCallback<Dict>): void {
    this.postMiniApi(URLS.PERSONALIZED, {
      pn: String(page),
      q_type: '2',
      rn: '20',
      load_type: String(loadType),
      new_net_type: '1',
      need_tags: '0',
      page_thread_count: '20',
      pre_ad_thread_count: '0',
      sug_count: '0',
      tag_code: '0',
      need_forumlist: '0',
      new_install: '0',
      request_time: String(Date.now()),
      invoke_source: '',
      cuid_gid: '',
      scr_dip: String(DeviceFingerprint.getInstance().getScreenDensity()),
      scr_h: String(DeviceFingerprint.getInstance().getScreenHeight()),
      scr_w: String(DeviceFingerprint.getInstance().getScreenWidth()),
      from: '1021636m',
      subapp_type: 'mini'
    }, callback);
  }

  personalizedProto(loadType: number, page: number, callback: ApiCallback<Dict>): void {
    this.postProtoApi(URLS.PERSONALIZED, PROTO_CMDS.PERSONALIZED, {
      load_type: String(loadType),
      pn: String(page),
      q_type: '2',
      rn: '20',
      new_net_type: '1',
      need_tags: '0',
      page_thread_count: '20',
      pre_ad_thread_count: '0',
      sug_count: '0',
      tag_code: '0',
      need_forumlist: '1',
      new_install: '0',
      request_time: String(Date.now())
    }, callback);
  }

  forumRecommend(callback: ApiCallback<Dict>): void {
    this.postMiniApi(URLS.FORUM_RECOMMEND, {
      _client_version: ClientVersion.MINI_V8,
      like_forum: '1',
      recommend: '0',
      topic: '0'
    }, callback);
  }

  forumRecommendNew(sortType: number, callback: ApiCallback<Dict>): void {
    this.postProtoApi(URLS.FORUM_RECOMMEND, PROTO_CMDS.FORUM_RECOMMEND, {
      sortType: sortType
    }, callback);
  }

  forumGuide(sortType: number | null, pageNo: number, callback: ApiCallback<Dict>): void {
    const params: Record<string, string> = {
      pn: String(pageNo),
      rn: '20'
    };
    if (sortType !== null) {
      params.rn = String(sortType);
    }
    this.postMiniApi(URLS.FORUM_GUIDE, params, callback);
  }

  forumHome(sortType: number, page: number, callback: ApiCallback<Dict>): void {
    this.http.get(API_BASE_URLS.WEB_TIEBA, URLS.FORUM_HOME, {
      sort_type: String(sortType),
      pn: String(page)
    }).then(resp => callback.onSuccess(resp.data as Dict))
      .catch(err => callback.onError(-1, err.message));
  }

  userLikeForum(uid: number, page: number, callback: ApiCallback<Dict>): void {
    this.postMiniApi(URLS.USER_LIKE_FORUM, {
      uid: String(uid),
      page_no: String(page)
    }, callback);
  }

  getForumDetail(forumId: number, callback: ApiCallback<Dict>): void {
    this.postProtoApi(URLS.GET_FORUM_DETAIL, PROTO_CMDS.GET_FORUM_DETAIL, {
      forumId: forumId
    }, callback);
  }

  getBawuInfo(forumId: number, callback: ApiCallback<Dict>): void {
    this.postProtoApi(URLS.GET_BAWU_INFO, PROTO_CMDS.GET_BAWU_INFO, {
      forumId: forumId
    }, callback);
  }

  getLevelInfo(forumId: number, callback: ApiCallback<Dict>): void {
    this.postProtoApi(URLS.GET_LEVEL_INFO, PROTO_CMDS.GET_LEVEL_INFO, {
      forumId: forumId
    }, callback);
  }

  getMemberInfo(forumId: number, callback: ApiCallback<Dict>): void {
    this.postProtoApi(URLS.GET_MEMBER_INFO, PROTO_CMDS.GET_MEMBER_INFO, {
      forumId: forumId
    }, callback);
  }

  forumRuleDetail(forumId: number, callback: ApiCallback<Dict>): void {
    this.postProtoApi(URLS.FORUM_RULE_DETAIL, PROTO_CMDS.FORUM_RULE_DETAIL, {
      forumId: forumId
    }, callback);
  }

  getHistoryForum(history: string, callback: ApiCallback<Dict>): void {
    this.postProtoApi(URLS.GET_HISTORY_FORUM, PROTO_CMDS.GET_HISTORY_FORUM, {
      history: history
    }, callback);
  }

  frsPage(forumName: string, page: number, loadType: number, sortType: number, tabId: number, callback: ApiCallback<Dict>): void {
    const params: Record<string, string> = {
      kw: forumName,
      pn: String(page),
      rn: '30',
      load_type: String(loadType),
      sort_type: String(sortType),
      with_floor: '1'
    };
    if (loadType === 1) {
      params['is_good'] = '1';
    }
    if (tabId > 0) {
      params['tab_id'] = String(tabId);
    }
    this.postOfficialApi(URLS.FRS_PAGE, params, callback);
  }

  generalTabList(forumId: number, forumName: string, tabId: number, tabName: string, tabType: number, isGeneralTab: number, page: number, sortType: number, lastThreadId: number, callback: ApiCallback<Dict>): void {
    let protobufBytes: Uint8Array;
    try {
      protobufBytes = encodeGeneralTabListReq({
        forumId: forumId,
        tabId: tabId,
        tabName: tabName,
        tabType: tabType,
        isGeneralTab: isGeneralTab,
        pn: page,
        rn: 30,
        sortType: sortType,
        lastThreadId: lastThreadId
      });
    } catch (e) {
      callback.onError(-1, String(e));
      return;
    }
    this.http.postUserLikeProtobuf(URLS.GENERAL_TAB_LIST, protobufBytes, Number(PROTO_CMDS.GENERAL_TAB_LIST))
      .then((bytes: Uint8Array) => {
        try {
          const result = decodeGeneralTabListRes(bytes, forumName);
          callback.onSuccess({
            error_code: '0',
            data: {
              thread_list: result.threads,
              has_more: result.hasMore ? 1 : 0,
              user_list: []
            }
          });
        } catch (e) {
          callback.onError(-1, String(e));
        }
      })
      .catch((err: Error) => callback.onError(-1, err.message));
  }

  threadList(forumId: number, forumName: string, page: number, sortType: number, callback: ApiCallback<Dict>): void {
    this.postProtoApi(URLS.THREAD_LIST, PROTO_CMDS.THREAD_LIST, {
      forumId: forumId,
      forumName: forumName,
      page: page,
      sortType: sortType
    }, callback);
  }

  threadContent(threadId: number, page: number, seeLz: boolean, callback: ApiCallback<Dict>): void {
    this.postOfficialApi(URLS.PB_PAGE, {
      kw: '',
      tid: String(threadId),
      pid: '',
      pn: String(page),
      see_lz: seeLz ? '1' : '0',
      with_floor: '1',
      r: String(Math.random())
    }, callback);
  }

  pbPage(threadId: number, page: number, postId: number | null, seeLz: boolean, sortType: number | null, callback: ApiCallback<Dict>): void {
    this.postOfficialApi(URLS.PB_PAGE, {
      kz: String(threadId),
      pn: String(page),
      r: String(sortType ?? 0),
      lz: seeLz ? '1' : '0',
      rn: '30',
      with_floor: '1',
      floor_rn: '3',
      st_type: 'tb_frslist',
      scr_dip: String(DeviceFingerprint.getInstance().getScreenDensity()),
      scr_h: String(DeviceFingerprint.getInstance().getScreenHeight()),
      scr_w: String(DeviceFingerprint.getInstance().getScreenWidth())
    }, callback);
  }

  pbFloor(threadId: number, postId: number, forumId: number, page: number, callback: ApiCallback<Dict>): void {
    this.postProtoApi(URLS.PB_FLOOR, PROTO_CMDS.PB_FLOOR, {
      kz: threadId,
      pid: postId,
      forum_id: forumId > 0 ? forumId : 0,
      pn: page,
      spid: 0
    }, callback);
  }

  searchPost(keyword: string, forumName: string, page: number, sortMode: number, callback: ApiCallback<Dict>, onlyThread?: string): void {
    this.postMiniApi(URLS.SEARCH_POST, {
      word: keyword,
      kw: forumName,
      pn: String(page),
      rn: '20',
      only_thread: onlyThread || '0',
      sort_mode: String(sortMode),
      need_floor: '1'
    }, callback);
  }

  searchUser(keyword: string, callback: ApiCallback<Dict>): void {
    this.http.simpleGet(API_BASE_URLS.WEB_TIEBA, URLS.SEARCH_USER, {
      word: keyword,
      pn: '1',
      rn: '10'
    }).then(resp => {
      const d = resp.data as Dict || {};
      const errCode = d.no ?? d.error_code ?? d.errno;
      if (errCode !== undefined && errCode !== null && Number(errCode) !== 0) {
        callback.onError(Number(errCode), String(d.error || d.error_msg || d.errmsg || ''));
        return;
      }
      const raw = (d.data as Object) || d;
      let list: Dict[] = [];
      if (Array.isArray(raw)) {
        list = raw as Dict[];
      } else {
        const obj = raw as Dict;
        list = (obj.fuzzyMatch || obj.user_list || obj.list || obj.data_list || obj.data || obj.result || obj.user || obj.users || []) as Dict[];
        const exact = obj.exactMatch as Dict | undefined;
        if (exact && Object.keys(exact).length > 0) {
          list = [exact, ...list];
        }
      }
      const result: Dict = { user_list: list as Object };
      callback.onSuccess(result);
    }).catch(err => {
      console.error('TiebaLite: searchUser error=' + String(err));
      callback.onError(-1, err.message || String(err));
    });
  }

  searchForum(keyword: string, callback: ApiCallback<Dict>): void {
    this.http.simpleGet(API_BASE_URLS.WEB_TIEBA, URLS.SEARCH_FORUM, {
      word: keyword,
      pn: '1',
      rn: '10'
    }).then(resp => {
      const d = resp.data as Dict || {};
      const errCode = d.no ?? d.error_code ?? d.errno;
      if (errCode !== undefined && errCode !== null && Number(errCode) !== 0) {
        callback.onError(Number(errCode), String(d.error || d.error_msg || d.errmsg || ''));
        return;
      }
      const raw = (d.data as Object) || d;
      let list: Dict[] = [];
      if (Array.isArray(raw)) {
        list = raw as Dict[];
      } else {
        const obj = raw as Dict;
        list = (obj.fuzzyMatch || obj.forum_list || obj.list || obj.data_list || obj.data || obj.result || obj.forum || obj.forums || []) as Dict[];
        const exact = obj.exactMatch as Dict | undefined;
        if (exact && Object.keys(exact).length > 0) {
          list = [exact, ...list];
        }
      }
      const result: Dict = { forum_list: list as Object };
      callback.onSuccess(result);
    }).catch(err => {
      console.error('TiebaLite: searchForum error=' + String(err));
      callback.onError(-1, err.message || String(err));
    });
  }

  searchThread(keyword: string, page: number, sortMode: number, callback: ApiCallback<Dict>, forumName?: string, filterType?: number): void {
    const params: Record<string, string> = {
      word: keyword,
      pn: String(page),
      rn: '20',
      st: String(sortMode),
      tt: String(filterType ?? 1),
      ct: '1',
      cv: '99.9.101'
    };
    if (forumName) params.fname = forumName;
    const referer = 'https://tieba.baidu.com/mo/q/hybrid/search?keyword=' + encodeURIComponent(keyword) + '&_webview_time=' + Date.now();
    this.http.get(API_BASE_URLS.WEB_TIEBA, URLS.SEARCH_THREAD, params, {
      [HEADER.REFERER]: referer,
      [HEADER.NO_COMMON_PARAMS]: 'true',
      [HEADER.NO_ST_PARAMS]: 'true'
    }).then(resp => {
      const d = resp.data as Dict || {};
      const data = (d.data as Dict) || d;
      let list: Dict[] = [];
      const tl = data.thread_list || data.post_list;
      if (tl && Array.isArray(tl)) list = tl as Dict[];
      if (list.length === 0) {
        console.info('TiebaLite: searchThread empty, keys=' + Object.keys(d).join(','));
      }
      const result: Dict = { thread_list: list as Object };
      callback.onSuccess(result);
    }).catch(err => {
      console.error('TiebaLite: searchThread error=' + String(err));
      callback.onError(-1, err.message || String(err));
    });
  }

  searchSuggestions(keyword: string, callback: ApiCallback<Dict>): void {
    this.postProtoApi(URLS.SEARCH_SUG, PROTO_CMDS.SEARCH_SUG, {
      word: keyword,
      isForum: 0
    }, callback);
  }

  likeForum(forumId: number, forumName: string, tbs: string, callback: ApiCallback<Dict>): void {
    this.postMiniApi(URLS.LIKE_FORUM, {
      fid: String(forumId),
      kw: forumName,
      tbs: tbs
    }, callback);
  }

  unlikeForum(forumId: number, forumName: string, tbs: string, callback: ApiCallback<Dict>): void {
    this.postMiniApi(URLS.UNLIKE_FORUM, {
      fid: String(forumId),
      kw: forumName,
      tbs: tbs
    }, callback);
  }

  sign(forumId: number, forumName: string, tbs: string, callback: ApiCallback<Dict>): void {
    this.postMiniApi(URLS.SIGN, {
      fid: String(forumId),
      kw: forumName,
      tbs: tbs
    }, callback);
  }

  mSign(forumIds: number[], tbs: string, callback: ApiCallback<Dict>): void {
    this.postOfficialApi(URLS.M_SIGN, {
      forum_ids: forumIds.join(','),
      tbs: tbs
    }, callback);
  }

  addPost(content: string, forumId: number, forumName: string, threadId: number, tbs: string, callback: ApiCallback<Dict>, postId?: number, subPostId?: number, replyUserId?: number): void {
    const account = AccountManager.getInstance().getCurrentAccountSync();
    if (!account) {
      callback.onError(-1, 'Not logged in');
      return;
    }
    const params: IAddPostReqParams = {
      content: content,
      forumId: String(forumId),
      forumName: forumName,
      threadId: String(threadId),
      tbs: tbs,
      account: account,
      nameShow: account.nickname
    };
    if (postId && postId > 0) {
      params.postId = String(postId);
    }
    if (subPostId && subPostId > 0) {
      params.subPostId = String(subPostId);
    }
    if (replyUserId && replyUserId > 0) {
      params.replyUid = String(replyUserId);
    }
    let body: Uint8Array;
    try {
      body = encodeAddPostReq(params);
    } catch (e) {
      callback.onError(-1, String(e));
      return;
    }
    this.http.postUserLikeProtobuf(URLS.ADD_POST, body, Number(PROTO_CMDS.ADD_POST))
      .then(bytes => {
        const res = decodeAddPostRes(bytes);
        if (res.errorNo !== 0) {
          callback.onError(res.errorNo, res.errorMsg || 'Unknown error');
          return;
        }
        const data: Dict = {};
        data['error_code'] = '0';
        const inner: Dict = {};
        inner['pid'] = res.pid;
        inner['tid'] = res.tid;
        data['data'] = inner;
        callback.onSuccess(data);
      })
      .catch(err => callback.onError(-1, String(err)));
  }

  addThread(content: string, forumName: string, fid: number, title: string, callback: ApiCallback<Dict>, tabId?: number): void {
    const params: Record<string, string> = {
      kw: forumName,
      fid: String(fid),
      title: title,
      content: content,
      is_hide: '0',
      is_title: '0'
    };
    if (tabId && tabId > 0) {
      params['tab_id'] = String(tabId);
    }
    this.postMiniApi(URLS.ADD_THREAD, params, callback);
  }

  addPollPost(forumId: number, threadId: number, option: string, callback: ApiCallback<Dict>): void {
    this.postProtoApi(URLS.ADD_POLL_POST, PROTO_CMDS.ADD_POLL_POST, {
      forumId: forumId,
      threadId: threadId,
      pollOption: option
    }, callback);
  }

  delThread(forumId: number, forumName: string, threadId: number, tbs: string, callback: ApiCallback<Dict>): void {
    this.postMiniApi(URLS.DEL_THREAD, {
      fid: String(forumId),
      word: forumName,
      z: String(threadId),
      tbs: tbs,
      src: '1',
      is_vipdel: '0',
      delete_my_post: '1'
    }, callback);
  }

  delPost(forumId: number, forumName: string, threadId: number, postId: number, tbs: string, callback: ApiCallback<Dict>): void {
    this.postMiniApi(URLS.DEL_POST, {
      fid: String(forumId),
      pid: String(postId),
      z: String(threadId),
      tbs: tbs
    }, callback);
  }

  opAgree(threadId: number, postId: number, opType: number, callback: ApiCallback<Dict>): void {
    this.postMiniApi(URLS.AGREEMENT, {
      thread_id: String(threadId),
      post_id: String(postId),
      op_type: String(opType),
      agree_type: '2',
      obj_type: postId === 0 ? '3' : '1'
    }, callback);
  }

  disagree(threadId: number, postId: number, opType: number, callback: ApiCallback<Dict>): void {
    const account = AccountManager.getInstance().getCurrentAccountSync();
    this.postMiniApi(URLS.AGREEMENT, {
      thread_id: String(threadId),
      post_id: String(postId),
      op_type: String(opType),
      agree_type: '5',
      obj_type: postId === 0 ? '3' : '1',
      tbs: account?.tbs || ''
    }, callback);
  }

  threadStore(page: number, callback: ApiCallback<Dict>): void {
    this.postOfficialApi(URLS.THREAD_STORE, {
      pn: String(page),
      rn: '30'
    }, callback);
  }

  addStore(threadId: number, postId: number, callback: ApiCallback<Dict>): void {
    const data = JSON.stringify([{tid: String(threadId), pid: String(postId), status: 1}]);
    this.postOfficialApi(URLS.ADD_STORE, { data: data }, callback, { [HEADER.FORCE_LOGIN]: 'true' });
  }

  removeStore(threadId: number, callback: ApiCallback<Dict>): void {
    const account = AccountManager.getInstance().getCurrentAccountSync();
    this.postOfficialApi(URLS.REMOVE_STORE, {
      tid: String(threadId),
      fid: 'null',
      user_id: String(account?.uid || 0)
    }, callback, { [HEADER.FORCE_LOGIN]: 'true' });
  }

  msg(callback: ApiCallback<Dict>): void {
    this.postNewApi(URLS.MSG, {}, callback);
  }

  replyMe(page: number, callback: ApiCallback<Dict>): void {
    this.postNewApi(URLS.REPLY_ME, {
      pn: String(page),
      rn: '20'
    }, callback);
  }

  atMe(page: number, callback: ApiCallback<Dict>): void {
    this.postNewApi(URLS.AT_ME, {
      pn: String(page),
      rn: '20'
    }, callback);
  }

  agreeMe(page: number, callback: ApiCallback<Dict>): void {
    this.postNewApi(URLS.AGREE_ME, {
      pn: String(page),
      rn: '20'
    }, callback);
  }

  profile(uid: number, callback: ApiCallback<Dict>): void {
    this.postMiniApi(URLS.USER_PROFILE, {
      uid: String(uid)
    }, callback);
  }

  userProfile(uid: number, callback: ApiCallback<Dict>): void {
    this.postProtoApi(URLS.USER_PROFILE, PROTO_CMDS.USER_PROFILE, {
      uid: uid,
      needPostCount: 1
    }, callback);
  }

  getUserInfo(uid: number, callback: ApiCallback<Dict>): void {
    this.postProtoApi(URLS.GET_USER_INFO, PROTO_CMDS.GET_USER_INFO, {
      uid: uid
    }, callback);
  }

  userPost(uid: number, page: number, isThread: boolean, callback: ApiCallback<Dict>): void {
    // 安卓 UserPostRequestData: uid, rn=20, is_thread, need_content=1, pn, q_type=1, is_view_card
    this.postProtoApi(URLS.USER_POST, PROTO_CMDS.USER_POST, {
      uid: uid,
      rn: '20',
      is_thread: isThread ? '1' : '0',
      need_content: '1',
      pn: page,
      q_type: '1',
      is_view_card: isThread ? '1' : '0'
    }, callback);
  }

  follow(portrait: string, tbs: string, callback: ApiCallback<Dict>): void {
    this.postMiniApi(URLS.FOLLOW, {
      portrait: portrait,
      tbs: tbs
    }, callback);
  }

  unfollow(portrait: string, tbs: string, callback: ApiCallback<Dict>): void {
    this.postMiniApi(URLS.UNFOLLOW, {
      portrait: portrait,
      tbs: tbs
    }, callback);
  }

  getFollows(uid: number, page: number, callback: ApiCallback<Dict>): void {
    this.postMiniApi(URLS.FOLLOW_LIST, {
      pn: String(page),
      uid: String(uid)
    }, callback);
  }

  getFans(uid: number, page: number, callback: ApiCallback<Dict>): void {
    this.postMiniApi(URLS.FANS_PAGE, {
      pn: String(page),
      uid: String(uid)
    }, callback);
  }

  login(bduss: string, sToken: string, callback: ApiCallback<Dict>): void {
    this.postOfficialApi(URLS.LOGIN, {
      bdusstoken: bduss ? `${bduss}|null` : '',
      stoken: sToken
    }, callback);
  }

  loginFlow(callback: ApiCallback<Dict>): void {
    this.postOfficialApi(URLS.LOGIN, {}, callback);
  }

  initNickName(bduss: string, sToken: string, callback: ApiCallback<Dict>): void {
    this.postOfficialApi(URLS.INIT_NICKNAME, {
      BDUSS: bduss,
      stoken: sToken
    }, callback);
  }

  submitDislike(dislikeJson: string, callback: ApiCallback<Dict>): void {
    this.postOfficialApi(URLS.SUBMIT_DISLIKE, {
      dislike: dislikeJson
    }, callback);
  }

  hotThreadList(tabCode: string, callback: ApiCallback<Dict>): void {
    // 安卓原版 HotThreadListRequestData: common, tabId = "1", tabCode
    this.postProtoApi(URLS.HOT_THREAD_LIST, PROTO_CMDS.HOT_THREAD_LIST, {
      tabId: '1',
      tabCode: tabCode
    }, callback);
  }

  topicList(callback: ApiCallback<Dict>): void {
    this.postProtoApi(URLS.TOPIC_LIST, PROTO_CMDS.TOPIC_LIST, {}, callback);
  }

  userLike(pageTag: string, loadType: string, lastRequestUnix: string, callback: ApiCallback<Dict>, followType?: string): void {
    this.postProtoApi(URLS.USER_LIKE, PROTO_CMDS.USER_LIKE, {
      pageTag: pageTag || '',
      loadType: loadType || '1',
      lastRequestUnix: lastRequestUnix || '0',
      followType: followType || '1'
    }, callback);
  }

  picPage(forumId: number, forumName: string, threadId: number, picId: string, picIndex: number, prev: boolean, callback: ApiCallback<Dict>): void {
    this.postMiniApi(URLS.PIC_PAGE, {
      forum_id: String(forumId),
      kw: forumName,
      tid: String(threadId),
      pic_id: picId,
      pic_index: String(Math.max(picIndex, 1)),
      obj_type: 'pb',
      page_name: 'PB',
      next: prev ? '0' : '10',
      prev: prev ? '10' : '0',
      not_see_lz: '1',
      q_type: '2'
    }, callback);
  }

  private postMiniApi(path: string, params: Record<string, string>, callback: ApiCallback<Dict>): void {
    this.sendRequest(API_BASE_URLS.MINI_TIEBA, path, params, callback);
  }

  private postOfficialApi(path: string, params: Record<string, string>, callback: ApiCallback<Dict>, extraHeaders?: Record<string, string>): void {
    this.sendRequest(API_BASE_URLS.OFFICIAL_TIEBA, path, params, callback, extraHeaders);
  }

  private postNewApi(path: string, params: Record<string, string>, callback: ApiCallback<Dict>): void {
    this.sendRequest(API_BASE_URLS.NEW_TIEBA, path, params, callback);
  }

  private sendRequest(baseUrl: string, path: string, params: Record<string, string>, callback: ApiCallback<Dict>, extraHeaders?: Record<string, string>): void {
    console.info('TiebaLite: [E1] sendRequest ' + path);
    const account = AccountManager.getInstance().getCurrentAccountSync();
    if (account) {
      params[PARAM.BDUSS] = account.bduss;
      params[PARAM.STOKEN] = account.sToken;
    }

    console.info('TiebaLite: [E2] calling http.post');
    this.http.post(baseUrl, path, params, extraHeaders)
      .then(response => {
        console.info('TiebaLite: [E3] http.post success');
        const raw = response.data;
        if (typeof raw !== 'object' || raw === null) {
          // WAF/HTML 页或空响应：绝不能当作成功（否则收藏/取消收藏会假成功）
          console.error('TiebaLite: [EERR] non-object response type=' + typeof raw);
          callback.onError(-1, '响应格式异常');
          return;
        }
        const data: Dict = raw as Dict;
        const code = data?.error_code;
        const msg = String(data?.error_msg || '');
        console.info('TiebaLite: [E4] resp error_code=' + JSON.stringify(code) + ' error_msg=' + msg);
        if (code && code !== '0' && code !== 0 && code !== 300000 && code !== '300000') {
          console.info('TiebaLite: [E5] calling onError');
          callback.onError(Number(code), msg || 'Unknown error');
        } else {
          console.info('TiebaLite: [E6] calling onSuccess');
          callback.onSuccess(data);
        }
      })
      .catch(err => {
        console.error('TiebaLite: [EERR] sendRequest catch err=' + String(err));
        console.info('TiebaLite: [E7] calling onError from catch');
        callback.onError(-1, err.message || 'Network error');
      });
  }

  private postProtoApi(path: string, cmd: string, data: Dict, callback: ApiCallback<Dict>): void {
    const params: Record<string, string> = {
      cmd: cmd,
      ...Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)]))
    };

    const account = AccountManager.getInstance().getCurrentAccountSync();
    if (account) {
      params[PARAM.BDUSS] = account.bduss;
      params[PARAM.STOKEN] = account.sToken;
    }

    this.http.post(API_BASE_URLS.PROTOBUF_TIEBA, path, params)
      .then(response => {
        const respData: Dict = response.data as Dict;
        const code = respData?.error_code;
        const msg = String(respData?.error_msg || '');
        console.info('TiebaLite: postProtoApi resp error_code=' + JSON.stringify(code) + ' error_msg=' + msg);
        if (code && code !== '0' && code !== 0 && code !== 300000 && code !== '300000') {
          callback.onError(Number(code), msg || 'Unknown error');
        } else {
          callback.onSuccess(respData);
        }
      })
      .catch(err => callback.onError(-1, err.message));
  }
}
