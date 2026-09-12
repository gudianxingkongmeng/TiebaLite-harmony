import { Dict } from '../types/Dict';
import { ApiResult } from '../network/ApiResult';

export interface ApiCallback<T> {
  onSuccess(data: T): void;
  onError(code: number, message: string): void;
}

export default interface ITiebaApi {
  // Home - Personalized Feed
  personalized(loadType: number, page: number, callback: ApiCallback<Dict>): void;
  personalizedProto(loadType: number, page: number, callback: ApiCallback<Dict>): void;

  // Forum
  forumRecommend(callback: ApiCallback<Dict>): void;
  forumRecommendNew(sortType: number, callback: ApiCallback<Dict>): void;
  forumGuide(sortType: number | null, pageNo: number, callback: ApiCallback<Dict>): void;
  forumHome(sortType: number, page: number, callback: ApiCallback<Dict>): void;
  userLikeForum(uid: number, page: number, callback: ApiCallback<Dict>): void;
  getForumDetail(forumId: number, callback: ApiCallback<Dict>): void;
  getBawuInfo(forumId: number, callback: ApiCallback<Dict>): void;
  getLevelInfo(forumId: number, callback: ApiCallback<Dict>): void;
  getMemberInfo(forumId: number, callback: ApiCallback<Dict>): void;
  forumRuleDetail(forumId: number, callback: ApiCallback<Dict>): void;
  getHistoryForum(history: string, callback: ApiCallback<Dict>): void;

  // Forum Page (Thread List)
  frsPage(forumName: string, page: number, loadType: number, sortType: number, tabId: number, callback: ApiCallback<Dict>): void;
  generalTabList(forumId: number, forumName: string, tabId: number, tabName: string, tabType: number, isGeneralTab: number, page: number, sortType: number, lastThreadId: number, callback: ApiCallback<Dict>): void;
  threadList(forumId: number, forumName: string, page: number, sortType: number, callback: ApiCallback<Dict>): void;

  // Thread Content
  threadContent(threadId: number, page: number, seeLz: boolean, callback: ApiCallback<Dict>): void;
  pbPage(threadId: number, page: number, postId: number | null, seeLz: boolean, sortType: number | null, callback: ApiCallback<Dict>): void;
  pbFloor(threadId: number, postId: number, forumId: number, page: number, callback: ApiCallback<Dict>, subPostId?: number): void;

  // Search
  searchPost(keyword: string, forumName: string, page: number, sortMode: number, callback: ApiCallback<Dict>, onlyThread?: string): void;
  searchUser(keyword: string, callback: ApiCallback<Dict>): void;
  searchForum(keyword: string, callback: ApiCallback<Dict>): void;
  searchThread(keyword: string, page: number, sortMode: number, callback: ApiCallback<Dict>, forumName?: string, filterType?: number): void;
  searchSuggestions(keyword: string, callback: ApiCallback<Dict>): void;

  // Like/Unlike Forum
  likeForum(forumId: number, forumName: string, tbs: string, callback: ApiCallback<Dict>): void;
  unlikeForum(forumId: number, forumName: string, tbs: string, callback: ApiCallback<Dict>): void;

  // Sign
  sign(forumId: number, forumName: string, tbs: string, callback: ApiCallback<Dict>): void;
  mSign(forumIds: number[], tbs: string, callback: ApiCallback<Dict>): void;

  // Post Operations
  addPost(content: string, forumId: number, forumName: string, threadId: number, tbs: string, callback: ApiCallback<Dict>, postId?: number, subPostId?: number, replyUserId?: number): void;
  addThread(content: string, forumName: string, fid: number, title: string, callback: ApiCallback<Dict>, tabId?: number): void;
  addPollPost(forumId: number, threadId: number, option: string, callback: ApiCallback<Dict>): void;

  // Delete
  delThread(forumId: number, forumName: string, threadId: number, tbs: string, callback: ApiCallback<Dict>): void;
  delPost(forumId: number, forumName: string, threadId: number, postId: number, tbs: string, callback: ApiCallback<Dict>): void;

  // Agreement
  opAgree(threadId: number, postId: number, opType: number, callback: ApiCallback<Dict>): void;
  disagree(threadId: number, postId: number, opType: number, callback: ApiCallback<Dict>): void;

  // Store/Favorites
  threadStore(page: number, callback: ApiCallback<Dict>): void;
  addStore(threadId: number, postId: number, callback: ApiCallback<Dict>): void;

  removeStore(threadId: number, callback: ApiCallback<Dict>): void;
  // Messages
  msg(callback: ApiCallback<Dict>): void;
  replyMe(page: number, callback: ApiCallback<Dict>): void;
  atMe(page: number, callback: ApiCallback<Dict>): void;
  agreeMe(page: number, callback: ApiCallback<Dict>): void;

  // User
  profile(uid: number, callback: ApiCallback<Dict>): void;
  userProfile(uid: number, callback: ApiCallback<Dict>): void;
  getUserInfo(uid: number, callback: ApiCallback<Dict>): void;
  userPost(uid: number, page: number, isThread: boolean, callback: ApiCallback<Dict>): void;

  // Follow
  follow(portrait: string, tbs: string, callback: ApiCallback<Dict>): void;
  unfollow(portrait: string, tbs: string, callback: ApiCallback<Dict>): void;
  getFollows(uid: number, page: number, callback: ApiCallback<Dict>): void;
  getFans(uid: number, page: number, callback: ApiCallback<Dict>): void;

  // Login
  login(bduss: string, sToken: string, callback: ApiCallback<Dict>): void;
  loginFlow(callback: ApiCallback<Dict>): void;
  initNickName(bduss: string, sToken: string, callback: ApiCallback<Dict>): void;

  // Other
  submitDislike(dislikeJson: string, callback: ApiCallback<Dict>): void;
  hotThreadList(tabCode: string, callback: ApiCallback<Dict>): void;
  topicList(callback: ApiCallback<Dict>): void;
  userLike(pageTag: string, loadType: string, lastRequestUnix: string, callback: ApiCallback<Dict>, followType?: string): void;
  picPage(forumId: number, forumName: string, threadId: number, picId: string, picIndex: number, prev: boolean, callback: ApiCallback<Dict>): void;
}
