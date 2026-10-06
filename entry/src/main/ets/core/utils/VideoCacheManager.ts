import http from '@ohos.net.http';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';

interface DownloadProgressData {
  receiveSize: number;
  totalSize: number;
}

interface CacheTask {
  url: string;
  path: string;
  ctx: common.UIAbilityContext;
  fd: number;
  done: boolean;
  lastPct: number;
  high: boolean;
  aborted: boolean;
  paused: boolean;
  dataEnded: boolean;
}

type CacheListener = (pct: number, done: boolean, path: string) => void;

export default class VideoCacheManager {
  private static instance: VideoCacheManager | null = null;
  private static readonly MAX_CONCURRENT: number = 2;
  private tasks: Map<string, CacheTask> = new Map();
  private listeners: Map<string, CacheListener[]> = new Map();
  private queue: string[] = [];
  private active: number = 0;

  static getInstance(): VideoCacheManager {
    if (VideoCacheManager.instance === null) {
      VideoCacheManager.instance = new VideoCacheManager();
    }
    return VideoCacheManager.instance;
  }

  cachePathFor(url: string): string {
    return 'tlb_' + this.hash(url) + '.mp4';
  }

  hasTask(url: string): boolean {
    const t = this.tasks.get(url);
    return t !== undefined;
  }

  getCachedPath(url: string, ctx: common.UIAbilityContext): string {
    const path = ctx.cacheDir + '/' + this.cachePathFor(url);
    try {
      if (fs.accessSync(path) && fs.accessSync(path + '.done')) {
        const st = fs.statSync(path);
        if (st.size > 0) return path;
      }
    } catch (e) {}
    return '';
  }

  getPartialCachedPath(url: string, ctx: common.UIAbilityContext, minBytes: number = 1048576): string {
    const path = ctx.cacheDir + '/' + this.cachePathFor(url);
    try {
      if (fs.accessSync(path)) {
        const st = fs.statSync(path);
        if (st.size >= minBytes) return path;
      }
    } catch (e) {}
    return '';
  }

  invalidate(url: string, ctx: common.UIAbilityContext): void {
    const path = ctx.cacheDir + '/' + this.cachePathFor(url);
    try { fs.unlinkSync(path); } catch (e) {}
    try { fs.unlinkSync(path + '.done'); } catch (e) {}
  }

  subscribe(url: string, cb: CacheListener): () => void {
    let arr = this.listeners.get(url);
    if (!arr) {
      arr = [];
      this.listeners.set(url, arr);
    }
    arr.push(cb);
    const task = this.tasks.get(url);
    if (task) {
      cb(task.done ? 100 : task.lastPct, task.done, task.path);
    } else {
      cb(-1, false, '');
    }
    return () => {
      const a = this.listeners.get(url);
      if (a) {
        const idx = a.indexOf(cb);
        if (idx >= 0) a.splice(idx, 1);
        if (a.length === 0) this.listeners.delete(url);
      }
    };
  }

  startDownload(url: string, ctx: common.UIAbilityContext, highPriority: boolean = false): void {
    if (!url) return;
    const tag = this.cachePathFor(url);
    const existing = this.tasks.get(url);
    if (existing) {
      if (highPriority && !existing.high && !existing.done && !existing.aborted) {
        console.info('TiebaLite: dl promote to high ' + tag);
        existing.high = true;
        if (existing.fd === -1 && this.queue.includes(url)) {
          this.queue = this.queue.filter((u: string) => u !== url);
          if (this.active < VideoCacheManager.MAX_CONCURRENT) {
            this.active++;
            void this.run(existing);
          } else {
            this.queue.unshift(url);
          }
        }
      }
      return;
    }
    this.cleanupOld(ctx);
    const task: CacheTask = {
      url: url,
      path: ctx.cacheDir + '/' + this.cachePathFor(url),
      ctx: ctx,
      fd: -1,
      done: false,
      lastPct: 0,
      high: highPriority,
      aborted: false,
      paused: false,
      dataEnded: false
    };
    this.tasks.set(url, task);
    const ls = this.listeners.get(url);
    if (ls && ls.length > 0) {
      for (const cb of ls) {
        try { cb(task.lastPct, task.done, task.path); } catch (e) {}
      }
    }
    if (this.active < VideoCacheManager.MAX_CONCURRENT) {
      console.info('TiebaLite: dl start ' + (highPriority ? 'high' : 'low') + ' ' + tag);
      this.active++;
      void this.run(task);
    } else if (highPriority) {
      const victim = this.pickVictim(url);
      if (victim) {
        console.info('TiebaLite: dl preempt victim ' + this.cachePathFor(victim.url) + ' for ' + tag);
        this.abortTask(victim, false);
        this.active++;
        void this.run(task);
      } else {
        this.queue.unshift(url);
      }
    } else {
      this.tasks.delete(url);
    }
  }

  cancelTask(url: string): void {
    const t = this.tasks.get(url);
    if (!t || t.done) return;
    console.info('TiebaLite: dl cancel ' + this.cachePathFor(url));
    if (t.fd !== -1) {
      this.abortTask(t, true);
    } else if (this.queue.includes(url)) {
      this.queue = this.queue.filter((u: string) => u !== url);
      this.tasks.delete(url);
      this.notify(url, -1, false, t.path);
    } else {
      t.aborted = true;
      this.tasks.delete(url);
      this.notify(url, -1, false, t.path);
    }
  }

  pauseDownload(url: string): void {
    const t = this.tasks.get(url);
    if (!t || t.done || t.paused) return;
    t.paused = true;
    this.queue = this.queue.filter((u: string) => u !== url);
    if (t.fd !== -1) {
      try { fs.closeSync(t.fd); } catch (e) {}
      t.fd = -1;
      this.active--;
      if (this.active < 0) this.active = 0;
    }
    console.info('TiebaLite: dl paused ' + this.cachePathFor(url) + ' at ' + t.lastPct + '%');
  }

  resumeDownload(url: string): void {
    const t = this.tasks.get(url);
    if (!t || t.done || !t.paused) return;
    t.paused = false;
    if (this.active < VideoCacheManager.MAX_CONCURRENT) {
      this.active++;
      void this.run(t);
    } else {
      this.queue.push(url);
    }
    console.info('TiebaLite: dl resumed ' + this.cachePathFor(url));
  }

  private pickVictim(url: string): CacheTask | null {
    let victim: CacheTask | null = null;
    for (const t of this.tasks.values()) {
      if (t.done || t.aborted || t.fd === -1 || t.url === url) continue;
      if (!victim || t.lastPct < victim.lastPct) victim = t;
    }
    return victim;
  }

  private abortTask(t: CacheTask, runDequeue: boolean): void {
    t.aborted = true;
    if (t.fd !== -1) {
      try { fs.closeSync(t.fd); } catch (e) {}
      t.fd = -1;
    }
    try { fs.unlinkSync(t.path); } catch (e) {}
    try { fs.unlinkSync(t.path + '.done'); } catch (e) {}
    this.tasks.delete(t.url);
    this.active--;
    if (this.active < 0) this.active = 0;
    this.notify(t.url, -1, false, t.path);
    if (runDequeue) {
      this.dequeue(t.ctx);
    }
  }

  private async run(task: CacheTask): Promise<void> {
    if (task.aborted || task.paused) return;
    try {
      let offset = 0;
      try {
        const st = fs.statSync(task.path);
        if (st.size > 0) offset = st.size;
      } catch (e) {}
      task.dataEnded = false;
      const req = http.createHttp();
      req.on('dataReceive', (data: ArrayBuffer) => {
        if (task.aborted || task.paused) return;
        if (task.fd === -1) {
          try {
            task.fd = fs.openSync(task.path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.APPEND).fd;
          } catch (e) {}
        }
        if (task.fd !== -1) {
          try { fs.writeSync(task.fd, data); } catch (e) {}
        }
      });
      req.on('dataReceiveProgress', (data: DownloadProgressData) => {
        if (task.aborted || task.paused) return;
        if (offset > 0) return;
        if (data.totalSize > 0) {
          const pct = Math.floor(data.receiveSize * 100 / data.totalSize);
          if (pct >= 0 && pct <= 100 && pct !== task.lastPct) {
            task.lastPct = pct;
            this.notify(task.url, pct, false, task.path);
          }
        }
      });
      req.on('dataEnd', () => {
        task.dataEnded = true;
      });
      const header: Record<string, string> = {
        'User-Agent': 'bdtb for Android 12.52.1.0',
        'Referer': 'https://tieba.baidu.com/'
      };
      if (offset > 0) {
        header['Range'] = 'bytes=' + offset + '-';
      }
      const resp = await req.request(task.url, {
        method: http.RequestMethod.GET,
        header: header,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      if (task.aborted || task.paused) return;
      if (offset > 0 && resp.responseCode !== 206) {
        console.info('TiebaLite: dl server ignored Range, restart from zero ' + this.cachePathFor(task.url));
        if (task.fd !== -1) {
          try { fs.closeSync(task.fd); } catch (e) {}
          task.fd = -1;
        }
        try { fs.unlinkSync(task.path); } catch (e) {}
        task.lastPct = 0;
        task.dataEnded = false;
        this.notify(task.url, 0, false, task.path);
        await this.run(task);
        return;
      }
      if (task.dataEnded || offset > 0) {
        this.finish(task);
      }
    } catch (e) {
      if (task.aborted || task.paused) return;
      this.cleanupTask(task);
    }
  }

  private finish(task: CacheTask): void {
    if (task.fd !== -1) {
      try { fs.closeSync(task.fd); } catch (e) {}
      task.fd = -1;
    }
    try {
      const f = fs.openSync(task.path + '.done', fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.closeSync(f);
    } catch (e) {}
    task.done = true;
    task.lastPct = 100;
    this.notify(task.url, 100, true, task.path);
    this.dequeue(task.ctx);
  }

  private cleanupTask(task: CacheTask): void {
    if (task.fd !== -1) {
      try { fs.closeSync(task.fd); } catch (e) {}
      task.fd = -1;
    }
    try { fs.unlinkSync(task.path); } catch (e) {}
    try { fs.unlinkSync(task.path + '.done'); } catch (e) {}
    this.tasks.delete(task.url);
    this.notify(task.url, -1, false, task.path);
    this.dequeue(task.ctx);
  }

  private dequeue(ctx: common.UIAbilityContext): void {
    this.active--;
    if (this.active < 0) this.active = 0;
    if (this.active >= VideoCacheManager.MAX_CONCURRENT) return;
    while (this.queue.length > 0) {
      const u = this.queue.shift();
      if (!u) break;
      const t = this.tasks.get(u);
      if (t && !t.done) {
        this.active++;
        void this.run(t);
        break;
      }
    }
  }

  private notify(url: string, pct: number, done: boolean, path: string): void {
    const arr = this.listeners.get(url);
    if (!arr) return;
    for (const cb of arr) {
      cb(pct, done, path);
    }
  }

  private cleanupOld(ctx: common.UIAbilityContext): void {
    try {
      const names = fs.listFileSync(ctx.cacheDir);
      const cacheNames: string[] = [];
      for (const n of names) {
        if (n.startsWith('tlb_') && n.endsWith('.mp4')) cacheNames.push(n);
      }
      if (cacheNames.length <= 30) return;
      cacheNames.sort((a: string, b: string) => {
        let ma = 0;
        let mb = 0;
        try { ma = fs.statSync(ctx.cacheDir + '/' + a).mtime; } catch (e) {}
        try { mb = fs.statSync(ctx.cacheDir + '/' + b).mtime; } catch (e) {}
        return ma - mb;
      });
      const removeCount = cacheNames.length - 20;
      for (let i = 0; i < removeCount; i++) {
        const n = cacheNames[i];
        try { fs.unlinkSync(ctx.cacheDir + '/' + n); } catch (e) {}
        try { fs.unlinkSync(ctx.cacheDir + '/' + n + '.done'); } catch (e) {}
      }
    } catch (e) {}
  }

  private hash(s: string): string {
    let h = 5381;
    for (let i = 0; i < s.length; i++) {
      h = ((h << 5) + h) ^ s.charCodeAt(i);
    }
    return (h >>> 0).toString(16);
  }
}
