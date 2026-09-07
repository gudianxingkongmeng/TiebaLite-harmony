export const API_BASE_URLS = {
  NEW_TIEBA: 'https://c.tieba.baidu.com/',
  MINI_TIEBA: 'https://c.tieba.baidu.com/',
  OFFICIAL_TIEBA: 'https://c.tieba.baidu.com/',
  WEB_TIEBA: 'https://tieba.baidu.com/',
  HYBRID_TIEBA: 'https://tieba.baidu.com/',
  PROTOBUF_TIEBA: 'https://tiebac.baidu.com/',
  PROTOBUF_TIEBA_V12: 'https://tiebac.baidu.com/',
  PROTOBUF_TIEBA_POST: 'https://tiebac.baidu.com/',
  SOFIRE: 'https://sofire.baidu.com/'
};

export const HEADER = {
  NO_ST_PARAMS: 'no_st_params',
  FORCE_PARAM: 'force_param',
  FORCE_LOGIN: 'force_login',
  DROP_PARAMS: 'drop_params',
  DROP_HEADERS: 'drop_headers',
  NO_COMMON_PARAMS: 'no_common_params',
  ADD_WEB_COOKIE: 'add_cookie',
  ACCEPT_LANGUAGE: 'Accept-Language',
  ACCEPT: 'Accept',
  COOKIE: 'Cookie',
  HOST: 'Host',
  ORIGIN: 'Origin',
  REFERER: 'Referer',
  USER_AGENT: 'User-Agent',
  CUID: 'cuid',
  CUID_GALAXY2: 'cuid_galaxy2',
  CLIENT_TYPE: 'client_type',
  CLIENT_USER_TOKEN: 'client_user_token',
  CLIENT_LOG_ID: 'client_logid',
  X_BD_DATA_TYPE: 'x_bd_data_type',
  PRAGMA: 'Pragma',
  CACHE_CONTROL: 'Cache-Control'
};

export const PARAM = {
  BDUSS: 'BDUSS',
  STOKEN: 'STOKEN',
  TBS: 'tbs',
  CLIENT_VERSION: '_client_version',
  CLIENT_TYPE: '_client_type',
  CLIENT_ID: '_client_id',
  PHONE_IMEI: '_phone_imei',
  OS_VERSION: '_os_version',
  TIMESTAMP: 'timestamp',
  CUID: 'cuid',
  CUID_GALAXY2: 'cuid_galaxy2',
  C3_AID: 'c3_aid',
  CUID_GID: 'cuid_gid',
  FROM: 'from',
  MODEL: 'model',
  NET_TYPE: 'net_type',
  SIGN: 'sign',
  OAID: 'oaid',
  BRAND: 'brand',
  CMODE: 'cmode',
  ANDROID_ID: 'android_id',
  BAIDUID: 'baiduid',
  EVENT_DAY: 'event_day',
  EXTRA: 'extra',
  FIRST_INSTALL_TIME: 'first_install_time',
  FRAMEWORK_VER: 'framework_ver',
  IS_TEENAGER: 'is_teenager',
  LAST_UPDATE_TIME: 'last_update_time',
  SAMPLE_ID: 'sample_id',
  SDK_VER: 'sdk_ver',
  START_SCHEME: 'start_scheme',
  START_TYPE: 'start_type',
  SUBAPP_TYPE: 'subapp_type',
  SWAN_GAME_VER: 'swan_game_ver',
  Z_ID: 'z_id',
  ACTIVE_TIMESTAMP: 'active_timestamp',
  DEVICE_SCORE: 'device_score',
  MAC: 'mac',
  SCR_W: 'scr_w',
  SCR_H: 'scr_h',
  SCR_DIP: 'scr_dip',
  Q_TYPE: 'q_type',
  PERSONALIZED_REC_SWITCH: 'personalized_rec_switch',
  LEGO_LIB_VERSION: 'lego_lib_version',
  CLIENT_LOG_ID: 'client_logid'
};

export const APP_SECRET = 'tiebaclient!!!';

export const ERROR_CODES = {
  NETWORK: 10,
  UNKNOWN: -1,
  PARSE: -2,
  NOT_LOGGED_IN: 11,
  LOGGED_IN_EXPIRED: 12,
  UPDATE_NOT_ENABLE: 100,
  ACCOUNT_BLOCKED: 220012,
  POST_NOMORE: 350006
};

export enum ClientVersion {
  TIEBA_V11 = '11.10.8.6',
  TIEBA_V12 = '12.52.1.0',
  TIEBA_V12_POST = '12.35.1.0',
  TIEBA_V22 = '22.10.1.0',
  MINI_V7 = '7.2.0.0',
  MINI_V8 = '8.0.8.0',
  NEW_V8 = '8.2.2'
}
