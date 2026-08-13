// (C) 1995-2013 Jean-loup Gailly and Mark Adler
// (C) 2014-2017 Vitaly Puzrin and Andrey Tupitsin
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//   claim that you wrote the original software. If you use this software
//   in a product, an acknowledgment in the product documentation would be
//   appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//   misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.
/* eslint-disable space-unary-ops */
/* Public constants ==========================================================*/
/* ===========================================================================*/
//const Z_FILTERED          = 1;
//const Z_HUFFMAN_ONLY      = 2;
import { util } from "@kit.ArkTS";

//const Z_RLE               = 3;
const Z_FIXED$1 = 4;
//const Z_DEFAULT_STRATEGY  = 0;
/* Possible values of the data_type field (though see inflate()) */
const Z_BINARY$1 = 0;
const Z_TEXT$1 = 1;
//const Z_ASCII             = 1; // = Z_TEXT
const Z_UNKNOWN$1 = 2;
/*============================================================================*/
function zero$1(buf:Uint16Array) {
  let len = buf.length;
  while (--len >= 0) {
    buf[len] = 0;
  }
}
// From zutil.h
const STORED_BLOCK = 0;
const STATIC_TREES = 1;
const DYN_TREES = 2;
/* The three kinds of block type */
const MIN_MATCH$1 = 3;
const MAX_MATCH$1 = 258;
/* The minimum and maximum match lengths */
// From deflate.h
/* ===========================================================================
 * Internal compression state.
 */
const LENGTH_CODES$1 = 29;
/* number of length codes, not counting the special END_BLOCK code */
const LITERALS$1 = 256;
/* number of literal bytes 0..255 */
const L_CODES$1 = LITERALS$1 + 1 + LENGTH_CODES$1;
/* number of Literal or Length codes, including the END_BLOCK code */
const D_CODES$1 = 30;
/* number of distance codes */
const BL_CODES$1 = 19;
/* number of codes used to transfer the bit lengths */
const HEAP_SIZE$1 = 2 * L_CODES$1 + 1;
/* maximum heap size */
const MAX_BITS$1 = 15;
/* All codes must not exceed MAX_BITS bits */
const Buf_size = 16;
/* size of bit buffer in bi_buf */
/* ===========================================================================
 * Constants
 */
const MAX_BL_BITS = 7;
/* Bit length codes must not exceed MAX_BL_BITS bits */
const END_BLOCK = 256;
/* end of block literal code */
const REP_3_6 = 16;
/* repeat previous bit length 3-6 times (2 bits of repeat count) */
const REPZ_3_10 = 17;
/* repeat a zero length 3-10 times  (3 bits of repeat count) */
const REPZ_11_138 = 18;
/* repeat a zero length 11-138 times  (7 bits of repeat count) */
/* eslint-disable comma-spacing,array-bracket-spacing */
const extra_lbits = /* extra bits for each length code */ new Uint8Array([0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]);
const extra_dbits = /* extra bits for each distance code */ new Uint8Array([0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]);
const extra_blbits = /* extra bits for each bit length code */ new Uint8Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 3, 7]);
const bl_order = new Uint8Array([16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]);
/* eslint-enable comma-spacing,array-bracket-spacing */
/* The lengths of the bit length codes are sent in order of decreasing
 * probability, to avoid transmitting the lengths for unused bit length codes.
 */
/* ===========================================================================
 * Local data. These are initialized only once.
 */
// We pre-fill arrays with 0 to avoid uninitialized gaps
const DIST_CODE_LEN = 512; /* see definition of array dist_code below */
// !!!! Use flat array instead of structure, Freq = i*2, Len = i*2+1
const static_ltree = new Uint16Array((L_CODES$1 + 2) * 2);
zero$1(static_ltree);
/* The static literal tree. Since the bit lengths are imposed, there is no
 * need for the L_CODES extra codes used during heap construction. However
 * The codes 286 and 287 are needed to build a canonical tree (see _tr_init
 * below).
 */
const static_dtree = new Uint16Array(D_CODES$1 * 2);
zero$1(static_dtree);
/* The static distance tree. (Actually a trivial tree since all codes use
 * 5 bits.)
 */
const _dist_code = new Uint16Array(DIST_CODE_LEN);
zero$1(_dist_code);
/* Distance codes. The first 256 values correspond to the distances
 * 3 .. 258, the last 256 values correspond to the top 8 bits of
 * the 15 bit distances.
 */
const _length_code = new Uint16Array(MAX_MATCH$1 - MIN_MATCH$1 + 1);
zero$1(_length_code);
/* length code for each normalized match length (0 == MIN_MATCH) */
const base_length = new Uint16Array(LENGTH_CODES$1);
zero$1(base_length);
/* First normalized length for each code (0 = MIN_MATCH) */
const base_dist = new Uint16Array(D_CODES$1);
zero$1(base_dist);
/* First normalized distance for each code (0 = distance of 1) */
class StaticTreeDesc {
  static_tree: Uint16Array;
  extra_bits: Uint8Array;
  extra_base: number;
  elems: number;
  max_length: number;
  has_stree: boolean;

  constructor(static_tree: Uint16Array, extra_bits: Uint8Array, extra_base: number, elems: number, max_length: number) {
    this.static_tree = static_tree;
    this.extra_bits = extra_bits;
    this.extra_base = extra_base;
    this.elems = elems;
    this.max_length = max_length;
    this.has_stree = static_tree && (static_tree.length > 0);
  }
}
let static_l_desc: StaticTreeDesc;
let static_d_desc: StaticTreeDesc;
let static_bl_desc: StaticTreeDesc;
export class TreeDesc {
  dyn_tree: Uint16Array;
  max_code: number;
  stat_desc: StaticTreeDesc;

  constructor(dyn_tree: Uint16Array, stat_desc: StaticTreeDesc) {
    this.dyn_tree = dyn_tree;
    this.max_code = 0;
    this.stat_desc = stat_desc;
  }
}
const d_code = (dist: number): number => {
  return dist < 256 ? _dist_code[dist] : _dist_code[256 + (dist >>> 7)];
};
/* ===========================================================================
 * Output a short LSB first on the stream.
 * IN assertion: there is enough room in pendingBuf.
 */
const put_short = (s: DeflateState, w: number) => {
  s.pending_buf[s.pending++] = w & 0xff;
  s.pending_buf[s.pending++] = (w >>> 8) & 0xff;
};
/* ===========================================================================
 * Send a value on a given number of bits.
 * IN assertion: length <= 16 and value fits in length bits.
 */
const send_bits = (s: DeflateState, value: number, length: number) => {
  if (s.bi_valid > (Buf_size - length)) {
    s.bi_buf |= (value << s.bi_valid) & 0xffff;
    put_short(s, s.bi_buf);
    s.bi_buf = value >> (Buf_size - s.bi_valid);
    s.bi_valid += length - Buf_size;
  }
  else {
    s.bi_buf |= (value << s.bi_valid) & 0xffff;
    s.bi_valid += length;
  }
};
const send_code = (s: DeflateState, c: number, tree: Uint16Array) => {
  send_bits(s, tree[c * 2] /*.Code*/, tree[c * 2 + 1] /*.Len*/);
};
/* ===========================================================================
 * Reverse the first len bits of a code, using straightforward code (a faster
 * method would use a table)
 * IN assertion: 1 <= len <= 15
 */
const bi_reverse = (code: number, len: number): number => {
  let res = 0;
  do {
    res |= code & 1;
    code >>>= 1;
    res <<= 1;
  } while (--len > 0);
  return res >>> 1;
};
/* ===========================================================================
 * Flush the bit buffer, keeping at most 7 bits in it.
 */
const bi_flush = (s: DeflateState) => {
  if (s.bi_valid === 16) {
    put_short(s, s.bi_buf);
    s.bi_buf = 0;
    s.bi_valid = 0;
  }
  else if (s.bi_valid >= 8) {
    s.pending_buf[s.pending++] = s.bi_buf & 0xff;
    s.bi_buf >>= 8;
    s.bi_valid -= 8;
  }
};
/* ===========================================================================
 * Compute the optimal bit lengths for a tree and update the total bit length
 * for the current block.
 * IN assertion: the fields freq and dad are set, heap[heap_max] and
 *    above are the tree nodes sorted by increasing frequency.
 * OUT assertions: the field len is set to the optimal bit length, the
 *     array bl_count contains the frequencies for each bit length.
 *     The length opt_len is updated; static_len is also updated if stree is
 *     not null.
 */

const gen_bitlen = (s: DeflateState, desc: TreeDesc) => {
  const tree            = desc.dyn_tree;
  const max_code        = desc.max_code;
  const stree           = desc.stat_desc.static_tree;
  const has_stree       = desc.stat_desc.has_stree;
  const extra           = desc.stat_desc.extra_bits;
  const base            = desc.stat_desc.extra_base;
  const max_length      = desc.stat_desc.max_length;
  let h: number; /* heap index */
  let n: number, m: number; /* iterate over the tree elements */
  let bits: number; /* bit length */
  let xbits: number; /* extra bits */
  let f: number; /* frequency */
  let overflow: number = 0; /* number of elements with bit length too large */
  for (bits = 0; bits <= MAX_BITS$1; bits++) {
    s.bl_count[bits] = 0;
  }
  tree[s.heap[s.heap_max] * 2 + 1] /*.Len*/ = 0; /* root of the heap */
  for (h = s.heap_max + 1; h < HEAP_SIZE$1; h++) {
    n = s.heap[h];
    bits = tree[tree[n * 2 + 1] /*.Dad*/ * 2 + 1] /*.Len*/ + 1;
    if (bits > max_length) {
      bits = max_length;
      overflow++;
    }
    tree[n * 2 + 1] /*.Len*/ = bits;
    if (n > max_code) {
      continue;
    } /* not a leaf node */
    s.bl_count[bits]++;
    xbits = 0;
    if (n >= base) {
      xbits = extra[n - base];
    }
    f = tree[n * 2] /*.Freq*/;
    s.opt_len += f * (bits + xbits);
    if (has_stree) {
      s.static_len += f * (stree[n * 2 + 1] /*.Len*/ + xbits);
    }
  }
  if (overflow === 0) {
    return;
  }
  do {
    bits = max_length - 1;
    while (s.bl_count[bits] === 0) {
      bits--;
    }
    s.bl_count[bits]--; /* move one leaf down the tree */
    s.bl_count[bits + 1] += 2; /* move one overflow item as its brother */
    s.bl_count[max_length]--;
    overflow -= 2;
  } while (overflow > 0);
  for (bits = max_length; bits !== 0; bits--) {
    n = s.bl_count[bits];
    while (n !== 0) {
      m = s.heap[--h];
      if (m > max_code) {
        continue;
      }
      if (tree[m * 2 + 1] /*.Len*/ !== bits) {
        s.opt_len += (bits - tree[m * 2 + 1]) /*.Len*/ * tree[m * 2] /*.Freq*/;
        tree[m * 2 + 1] /*.Len*/ = bits;
      }
      n--;
    }
  }
};
/* ===========================================================================
 * Generate the codes for a given tree and bit counts (which need not be
 * optimal).
 * IN assertion: the array bl_count contains the bit length statistics for
 * the given tree and the field len is set for all tree elements.
 * OUT assertion: the field code is set for all tree elements of non
 *     zero code length.
 */
const gen_codes = (tree: Uint16Array, max_code: number, bl_count: Uint16Array) => {
  const next_code: number[] = new Array(MAX_BITS + 1); /* next code value for each bit length */
  let code: number = 0; /* running code value */
  let bits: number; /* bit index */
  let n: number; /* code index */
  for (bits = 1; bits <= MAX_BITS; bits++) {
    code = (code + bl_count[bits - 1]) << 1;
    next_code[bits] = code;
  }
  for (n = 0; n <= max_code; n++) {
    let len: number = tree[n * 2 + 1]; /*.Len*/
    if (len === 0) {
      continue;
    }
    tree[n * 2] /*.Code*/ = bi_reverse(next_code[len]++, len);
    //Tracecv(tree != static_ltree, (stderr,"\nn %3d %c l %2d c %4x (%x) ",
    //     n, (isgraph(n) ? n : ' '), len, tree[n].Code, next_code[len]-1));
  }
};
/* ===========================================================================
 * Initialize the various 'constant' tables.
 */
const tr_static_init = () => {
  let n: number; /* iterates over tree elements */
  let bits: number; /* bit counter */
  let length: number; /* length value */
  let code: number; /* code value */
  let dist: number; /* distance index */
  const bl_count = new Uint16Array(MAX_BITS$1 + 1);
  length = 0;
  for (code = 0; code < LENGTH_CODES$1 - 1; code++) {
    base_length[code] = length;
    for (n = 0; n < (1 << extra_lbits[code]); n++) {
      _length_code[length++] = code;
    }
  }
  _length_code[length - 1] = code;
  dist = 0;
  for (code = 0; code < 16; code++) {
    base_dist[code] = dist;
    for (n = 0; n < (1 << extra_dbits[code]); n++) {
      _dist_code[dist++] = code;
    }
  }
  dist >>= 7; /* from now on, all distances are divided by 128 */
  for (; code < D_CODES$1; code++) {
    base_dist[code] = dist << 7;
    for (n = 0; n < (1 << (extra_dbits[code] - 7)); n++) {
      _dist_code[256 + dist++] = code;
    }
  }
  for (bits = 0; bits <= MAX_BITS$1; bits++) {
    bl_count[bits] = 0;
  }
  n = 0;
  while (n <= 143) {
    static_ltree[n * 2 + 1] /*.Len*/ = 8;
    n++;
    bl_count[8]++;
  }
  while (n <= 255) {
    static_ltree[n * 2 + 1] /*.Len*/ = 9;
    n++;
    bl_count[9]++;
  }
  while (n <= 279) {
    static_ltree[n * 2 + 1] /*.Len*/ = 7;
    n++;
    bl_count[7]++;
  }
  while (n <= 287) {
    static_ltree[n * 2 + 1] /*.Len*/ = 8;
    n++;
    bl_count[8]++;
  }
  gen_codes(static_ltree, L_CODES$1 + 1, bl_count);
  for (n = 0; n < D_CODES$1; n++) {
    static_dtree[n * 2 + 1] /*.Len*/ = 5;
    static_dtree[n * 2] /*.Code*/ = bi_reverse(n, 5);
  }
  static_l_desc = new StaticTreeDesc(static_ltree, extra_lbits, LITERALS$1 + 1, L_CODES$1, MAX_BITS$1);
  static_d_desc = new StaticTreeDesc(static_dtree, extra_dbits, 0, D_CODES$1, MAX_BITS$1);
  static_bl_desc = new StaticTreeDesc(new Uint16Array(0), extra_blbits, 0, BL_CODES$1, MAX_BL_BITS);
  //static_init_done = true;
};
/* ===========================================================================
 * Initialize a new block.
 */
const init_block = (s: DeflateState) => {
  let n: number; /* iterates over tree elements */
  for (n = 0; n < L_CODES$1; n++) {
    s.dyn_ltree[n * 2] = 0;
  }
  for (n = 0; n < D_CODES$1; n++) {
    s.dyn_dtree[n * 2] = 0;
  }
  for (n = 0; n < BL_CODES$1; n++) {
    s.bl_tree[n * 2] = 0;
  }
  s.dyn_ltree[END_BLOCK * 2] = 1;
  s.opt_len = s.static_len = 0;
  s.sym_next = s.matches = 0;
};
/* ===========================================================================
 * Flush the bit buffer and align the output on a byte boundary
 */
const bi_windup = (s: DeflateState) => {
  if (s.bi_valid > 8) {
    put_short(s, s.bi_buf);
  }
  else if (s.bi_valid > 0) {
    s.pending_buf[s.pending++] = s.bi_buf;
  }
  s.bi_buf = 0;
  s.bi_valid = 0;
};
/* ===========================================================================
 * Compares to subtrees, using the tree depth as tie breaker when
 * the subtrees have equal frequency. This minimizes the worst case length.
 */
const smaller = (tree: Uint16Array, n: number, m: number, depth: Uint16Array): boolean => {
  const _n2 = n * 2;
  const _m2 = m * 2;
  return (tree[_n2] /*.Freq*/ < tree[_m2] /*.Freq*/ ||
    (tree[_n2] /*.Freq*/ === tree[_m2] /*.Freq*/ && depth[n] <= depth[m]));
};
/* ===========================================================================
 * Restore the heap property by moving down the tree starting at node k,
 * exchanging a node with the smallest of its two sons if necessary, stopping
 * when the heap property is re-established (each father smaller than its
 * two sons).
 */
const pqdownheap = (s: DeflateState, tree: Uint16Array, k: number) => {
  const v: number = s.heap[k];
  let j = k << 1; /* left son of k */
  while (j <= s.heap_len) {
    if (j < s.heap_len && smaller(tree, s.heap[j + 1], s.heap[j], s.depth)) {
      j++;
    }
    if (smaller(tree, v, s.heap[j], s.depth)) {
      break;
    }
    s.heap[k] = s.heap[j];
    k = j;
    j <<= 1;
  }
  s.heap[k] = v;
};
// inlined manually
// const SMALLEST = 1;
/* ===========================================================================
 * Send the block data compressed using the given Huffman trees
 */
const compress_block = (s: DeflateState, ltree: Uint16Array, dtree: Uint16Array) => {
  let dist: number; /* distance of matched string */
  let lc: number; /* match length or unmatched char (if dist == 0) */
  let sx: number = 0; /* running index in sym_buf */
  let code: number; /* the code to send */
  let extra: number; /* number of extra bits to send */
  if (s.sym_next !== 0) {
    do {
      dist = s.pending_buf[s.sym_buf + sx++] & 0xff;
      dist += (s.pending_buf[s.sym_buf + sx++] & 0xff) << 8;
      lc = s.pending_buf[s.sym_buf + sx++];
      if (dist === 0) {
        send_code(s, lc, ltree); /* send a literal byte */
        //Tracecv(isgraph(lc), (stderr," '%c' ", lc));
      }
      else {
        code = _length_code[lc];
        send_code(s, code + LITERALS$1 + 1, ltree); /* send the length code */
        extra = extra_lbits[code];
        if (extra !== 0) {
          lc -= base_length[code];
          send_bits(s, lc, extra); /* send the extra length bits */
        }
        dist--; /* dist is now the match distance - 1 */
        code = d_code(dist);
        send_code(s, code, dtree); /* send the distance code */
        extra = extra_dbits[code];
        if (extra !== 0) {
          dist -= base_dist[code];
          send_bits(s, dist, extra); /* send the extra distance bits */
        }
      } /* literal or match pair ? */
      /* Check that the overlay between pending_buf and sym_buf is ok: */
      //Assert(s->pending < s->lit_bufsize + sx, "pendingBuf overflow");
    } while (sx < s.sym_next);
  }
  send_code(s, END_BLOCK, ltree);
};
/* ===========================================================================
 * Construct one Huffman tree and assigns the code bit strings and lengths.
 * Update the total bit length for the current block.
 * IN assertion: the field freq is set for all tree elements.
 * OUT assertions: the fields len and code are set to the optimal bit length
 *     and corresponding code. The length opt_len is updated; static_len is
 *     also updated if stree is not null. The field max_code is set.
 */
const build_tree = (s: DeflateState, desc: TreeDesc) => {
  const tree = desc.dyn_tree;
  const stree = desc.stat_desc.static_tree;
  const has_stree = desc.stat_desc.has_stree;
  const elems = desc.stat_desc.elems;
  let n: number, m: number; /* iterate over heap elements */
  let max_code: number = -1; /* largest code with non zero frequency */
  let node: number; /* new node being created */
  s.heap_len = 0;
  s.heap_max = HEAP_SIZE$1;
  for (n = 0; n < elems; n++) {
    if (tree[n * 2] /*.Freq*/ !== 0) {
      s.heap[++s.heap_len] = max_code = n;
      s.depth[n] = 0;
    }
    else {
      tree[n * 2 + 1] /*.Len*/ = 0;
    }
  }
  while (s.heap_len < 2) {
    node = s.heap[++s.heap_len] = (max_code < 2 ? ++max_code : 0);
    tree[node * 2] /*.Freq*/ = 1;
    s.depth[node] = 0;
    s.opt_len--;
    if (has_stree) {
      s.static_len -= stree[node * 2 + 1] /*.Len*/;
    }
    /* node is 0 or 1 so it does not have extra bits */
  }
  desc.max_code = max_code;
  for (n = s.heap_len >> 1 /*int /2*/; n >= 1; n--) {
    pqdownheap(s, tree, n);
  }
  node = elems; /* next internal node of the tree */
  do {
    /*** pqremove ***/
    n = s.heap[1 /*SMALLEST*/];
    s.heap[1 /*SMALLEST*/] = s.heap[s.heap_len--];
    pqdownheap(s, tree, 1 /*SMALLEST*/);
    /***/
    m = s.heap[1 /*SMALLEST*/]; /* m = node of next least frequency */
    s.heap[--s.heap_max] = n; /* keep the nodes sorted by frequency */
    s.heap[--s.heap_max] = m;
    tree[node * 2] /*.Freq*/ = tree[n * 2] /*.Freq*/ + tree[m * 2] /*.Freq*/;
    s.depth[node] = (s.depth[n] >= s.depth[m] ? s.depth[n] : s.depth[m]) + 1;
    tree[n * 2 + 1] /*.Dad*/ = tree[m * 2 + 1] /*.Dad*/ = node;
    s.heap[1 /*SMALLEST*/] = node++;
    pqdownheap(s, tree, 1 /*SMALLEST*/);
  } while (s.heap_len >= 2);
  s.heap[--s.heap_max] = s.heap[1 /*SMALLEST*/];
  gen_bitlen(s, desc);
  gen_codes(tree, max_code, s.bl_count);
};
/* ===========================================================================
 * Scan a literal or distance tree to determine the frequencies of the codes
 * in the bit length tree.
 */
const scan_tree = (s: DeflateState, tree: Uint16Array, max_code: number) => {
  let n: number; /* iterates over all tree elements */
  let prevlen: number = -1; /* last emitted length */
  let curlen: number; /* length of current code */
  let nextlen: number = tree[0 * 2 + 1]; /*.Len*/ /* length of next code */
  let count = 0; /* repeat count of the current code */
  let max_count = 7; /* max repeat count */
  let min_count = 4; /* min repeat count */
  if (nextlen === 0) {
    max_count = 138;
    min_count = 3;
  }
  tree[(max_code + 1) * 2 + 1] /*.Len*/ = 0xffff; /* guard */
  for (n = 0; n <= max_code; n++) {
    curlen = nextlen;
    nextlen = tree[(n + 1) * 2 + 1] /*.Len*/;
    if (++count < max_count && curlen === nextlen) {
      continue;
    }
    else if (count < min_count) {
      s.bl_tree[curlen * 2] /*.Freq*/ += count;
    }
    else if (curlen !== 0) {
      if (curlen !== prevlen) {
        s.bl_tree[curlen * 2] /*.Freq*/++;
      }
      s.bl_tree[REP_3_6 * 2] /*.Freq*/++;
    }
    else if (count <= 10) {
      s.bl_tree[REPZ_3_10 * 2] /*.Freq*/++;
    }
    else {
      s.bl_tree[REPZ_11_138 * 2] /*.Freq*/++;
    }
    count = 0;
    prevlen = curlen;
    if (nextlen === 0) {
      max_count = 138;
      min_count = 3;
    }
    else if (curlen === nextlen) {
      max_count = 6;
      min_count = 3;
    }
    else {
      max_count = 7;
      min_count = 4;
    }
  }
};
/* ===========================================================================
 * Send a literal or distance tree in compressed form, using the codes in
 * bl_tree.
 */
const send_tree = (s: DeflateState, tree: Uint16Array, max_code: number) => {
  let n: number; /* iterates over all tree elements */
  let prevlen: number = -1; /* last emitted length */
  let curlen: number; /* length of current code */
  let nextlen: number = tree[0 * 2 + 1]; /*.Len*/ /* length of next code */
  let count = 0; /* repeat count of the current code */
  let max_count = 7; /* max repeat count */
  let min_count = 4; /* min repeat count */
  if (nextlen === 0) {
    max_count = 138;
    min_count = 3;
  }
  for (n = 0; n <= max_code; n++) {
    curlen = nextlen;
    nextlen = tree[(n + 1) * 2 + 1] /*.Len*/;
    if (++count < max_count && curlen === nextlen) {
      continue;
    }
    else if (count < min_count) {
      do {
        send_code(s, curlen, s.bl_tree);
      } while (--count !== 0);
    }
    else if (curlen !== 0) {
      if (curlen !== prevlen) {
        send_code(s, curlen, s.bl_tree);
        count--;
      }
      send_code(s, REP_3_6, s.bl_tree);
      send_bits(s, count - 3, 2);
    }
    else if (count <= 10) {
      send_code(s, REPZ_3_10, s.bl_tree);
      send_bits(s, count - 3, 3);
    }
    else {
      send_code(s, REPZ_11_138, s.bl_tree);
      send_bits(s, count - 11, 7);
    }
    count = 0;
    prevlen = curlen;
    if (nextlen === 0) {
      max_count = 138;
      min_count = 3;
    }
    else if (curlen === nextlen) {
      max_count = 6;
      min_count = 3;
    }
    else {
      max_count = 7;
      min_count = 4;
    }
  }
};
/* ===========================================================================
 * Construct the Huffman tree for the bit lengths and return the index in
 * bl_order of the last bit length code to send.
 */
const build_bl_tree = (s: DeflateState): number => {
  let max_blindex: number; /* index of last bit length code of non zero freq */
  scan_tree(s, s.dyn_ltree, (s.l_desc as TreeDesc).max_code);
  scan_tree(s, s.dyn_dtree, (s.d_desc as TreeDesc).max_code);
  build_tree(s, s.bl_desc as TreeDesc);
  for (max_blindex = BL_CODES$1 - 1; max_blindex >= 3; max_blindex--) {
    if (s.bl_tree[bl_order[max_blindex] * 2 + 1] /*.Len*/ !== 0) {
      break;
    }
  }
  s.opt_len += 3 * (max_blindex + 1) + 5 + 5 + 4;
  return max_blindex;
};
/* ===========================================================================
 * Send the header for a block using dynamic Huffman trees: the counts, the
 * lengths of the bit length codes, the literal tree and the distance tree.
 * IN assertion: lcodes >= 257, dcodes >= 1, blcodes >= 4.
 */
const send_all_trees = (s: DeflateState, lcodes: number, dcodes: number, blcodes: number) => {
  let rank: number; /* index in bl_order */
  send_bits(s, lcodes - 257, 5); /* not +255 as stated in appnote.txt */
  send_bits(s, dcodes - 1, 5);
  send_bits(s, blcodes - 4, 4); /* not -3 as stated in appnote.txt */
  for (rank = 0; rank < blcodes; rank++) {
    send_bits(s, s.bl_tree[bl_order[rank] * 2 + 1] /*.Len*/, 3);
  }
  send_tree(s, s.dyn_ltree, lcodes - 1); /* literal tree */
  send_tree(s, s.dyn_dtree, dcodes - 1); /* distance tree */
  //Tracev((stderr, "\ndist tree: sent %ld", s->bits_sent));
};
/* ===========================================================================
 * Check if the data type is TEXT or BINARY, using the following algorithm:
 * - TEXT if the two conditions below are satisfied:
 *    a) There are no non-portable control characters belonging to the
 *       "block list" (0..6, 14..25, 28..31).
 *    b) There is at least one printable character belonging to the
 *       "allow list" (9 {TAB}, 10 {LF}, 13 {CR}, 32..255).
 * - BINARY otherwise.
 * - The following partially-portable control characters form a
 *   "gray list" that is ignored in this detection algorithm:
 *   (7 {BEL}, 8 {BS}, 11 {VT}, 12 {FF}, 26 {SUB}, 27 {ESC}).
 * IN assertion: the fields Freq of dyn_ltree are set.
 */
const detect_data_type = (s: DeflateState): number => {
  let block_mask: number = 0xf3ffc07f;
  let n: number;
  /* Check for non-textual ("block-listed") bytes. */
  for (n = 0; n <= 31; n++, block_mask >>>= 1) {
    if ((block_mask & 1) && (s.dyn_ltree[n * 2] /*.Freq*/ !== 0)) {
      return Z_BINARY$1;
    }
  }
  /* Check for textual ("allow-listed") bytes. */
  if (s.dyn_ltree[9 * 2] /*.Freq*/ !== 0 || s.dyn_ltree[10 * 2] /*.Freq*/ !== 0 ||
    s.dyn_ltree[13 * 2] /*.Freq*/ !== 0) {
    return Z_TEXT$1;
  }
  for (n = 32; n < LITERALS$1; n++) {
    if (s.dyn_ltree[n * 2] /*.Freq*/ !== 0) {
      return Z_TEXT$1;
    }
  }
  /* There are no "block-listed" or "allow-listed" bytes:
     * this stream either is empty or has tolerated ("gray-listed") bytes only.
     */
  return Z_BINARY$1;
};
let static_init_done = false;
/* ===========================================================================
 * Initialize the tree data structures for a new zlib stream.
 */
const _tr_init = (s: DeflateState) => {
  if (!static_init_done) {
    tr_static_init();
    static_init_done = true;
  }
  s.l_desc = new TreeDesc(s.dyn_ltree, static_l_desc);
  s.d_desc = new TreeDesc(s.dyn_dtree, static_d_desc);
  s.bl_desc = new TreeDesc(s.bl_tree, static_bl_desc);
  s.bi_buf = 0;
  s.bi_valid = 0;
  /* Initialize the first block of the first file: */
  init_block(s);
};
/* ===========================================================================
 * Send a stored block
 */
const _tr_stored_block = (s: DeflateState, buf: number, stored_len: number, last: boolean) => {
  send_bits(s, (STORED_BLOCK << 1) + (last ? 1 : 0), 3); /* send block type */
  bi_windup(s); /* align on byte boundary */
  put_short(s, stored_len);
  put_short(s, ~stored_len);
  if (stored_len) {
    s.pending_buf.set(s.window.subarray(buf, buf + stored_len), s.pending);
  }
  s.pending += stored_len;
};
/* ===========================================================================
 * Send one empty static block to give enough lookahead for inflate.
 * This takes 10 bits, of which 7 may remain in the bit buffer.
 */
const _tr_align = (s: DeflateState) => {
  send_bits(s, STATIC_TREES << 1, 3);
  send_code(s, END_BLOCK, static_ltree);
  bi_flush(s);
};
/* ===========================================================================
 * Determine the best encoding for the current block: dynamic trees, static
 * trees or store, and write out the encoded block.
 */
const _tr_flush_block = (s: DeflateState, buf: number, stored_len: number, last: boolean) => {
  let opt_lenb: number, static_lenb: number; /* opt_len and static_len in bytes */
  let max_blindex: number = 0; /* index of last bit length code of non zero freq */
  if (s.level > 0) {
    if (s.strm.data_type === Z_UNKNOWN) {
      s.strm.data_type = detect_data_type(s);
    }
    build_tree(s, s.l_desc as TreeDesc);
    build_tree(s, s.d_desc as TreeDesc);
    max_blindex = build_bl_tree(s);
    opt_lenb = (s.opt_len + 3 + 7) >>> 3;
    static_lenb = (s.static_len + 3 + 7) >>> 3;
    if (static_lenb <= opt_lenb) {
      opt_lenb = static_lenb;
    }
  }
  else {
    opt_lenb = static_lenb = stored_len + 5; /* force a stored block */
  }
  if ((stored_len + 4 <= opt_lenb) && (buf !== -1)) {
    _tr_stored_block(s, buf, stored_len, last);
  }
  else if (s.strategy === Z_FIXED$1 || static_lenb === opt_lenb) {
    send_bits(s, (STATIC_TREES << 1) + (last ? 1 : 0), 3);
    compress_block(s, static_ltree, static_dtree);
  }
  else {
    send_bits(s, (DYN_TREES << 1) + (last ? 1 : 0), 3);
    send_all_trees(s, (s.l_desc as TreeDesc).max_code + 1, (s.d_desc as TreeDesc).max_code + 1, max_blindex + 1);
    compress_block(s, s.dyn_ltree, s.dyn_dtree);
  }
  init_block(s);
  if (last) {
    bi_windup(s);
  }
  // Tracev((stderr,"\ncomprlen %lu(%lu) ", s->compressed_len>>3,
  //       s->compressed_len-7*last));
};
/* ===========================================================================
 * Save the match info and tally the frequency counts. Return true if
 * the current block must be flushed.
 */
const _tr_tally = (s: DeflateState, dist: number, lc: number): boolean => {
  s.pending_buf[s.sym_buf + s.sym_next++] = dist;
  s.pending_buf[s.sym_buf + s.sym_next++] = dist >> 8;
  s.pending_buf[s.sym_buf + s.sym_next++] = lc;
  if (dist === 0) {
    s.dyn_ltree[lc * 2] /*.Freq*/++;
  }
  else {
    s.matches++;
    dist--;
    s.dyn_ltree[(_length_code[lc] + LITERALS$1 + 1) * 2]++;
    s.dyn_dtree[d_code(dist) * 2]++;
  }
  return (s.sym_next === s.sym_end);
};

// Note: adler32 takes 12% for level 0 and 2% for level 6.
// It isn't worth it to make additional optimizations as in original.
// Small size is preferable.
// (C) 1995-2013 Jean-loup Gailly and Mark Adler
// (C) 2014-2017 Vitaly Puzrin and Andrey Tupitsin
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//   claim that you wrote the original software. If you use this software
//   in a product, an acknowledgment in the product documentation would be
//   appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//   misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.
const adler32 = (adler: number, buf: Uint8Array, len: number, pos: number): number => {
  let s1 = adler & 0xffff;
  let s2 = (adler >>> 16) & 0xffff;
  const mod = 65521;
  while (len > 0) {
    let n = len > 5552 ? 5552 : len;
    len -= n;
    const end4 = pos + (n & -4);
    while (pos < end4) {
      s1 += buf[pos];
      s2 += s1;
      s1 += buf[pos + 1];
      s2 += s1;
      s1 += buf[pos + 2];
      s2 += s1;
      s1 += buf[pos + 3];
      s2 += s1;
      pos += 4;
    }
    const end = pos + (n & 3);
    while (pos < end) {
      s1 += buf[pos++];
      s2 += s1;
    }
    s1 %= mod;
    s2 %= mod;
  }
  return (s1 | (s2 << 16)) | 0;
};

// Note: we can't get significant speed boost here.
// So write code to minimize size - no pregenerated tables
// and array tools dependencies.
// (C) 1995-2013 Jean-loup Gailly and Mark Adler
// (C) 2014-2017 Vitaly Puzrin and Andrey Tupitsin
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//   claim that you wrote the original software. If you use this software
//   in a product, an acknowledgment in the product documentation would be
//   appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//   misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.
// Use ordinary array, since untyped makes no boost here
const makeTable = () => {
  const table = new Uint32Array(256);
  let c: number;
  for (let n = 0; n < 256; n++) {
    c = n;
    for (let k = 0; k < 8; k++) {
      c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    }
    table[n] = c;
  }
  return table;
};
// Create table on load. Just 255 signed longs. Not a problem.
const crcTable = makeTable();
const crc32 = (crc: number, buf: Uint8Array, len: number, pos: number): number => {
  const t = crcTable;
  const end = pos + len;
  crc ^= -1;
  for (let i = pos; i < end; i++) {
    crc = (crc >>> 8) ^ t[(crc ^ buf[i]) & 0xFF];
  }
  return (crc ^ (-1)); // >>> 0;
};

// (C) 1995-2013 Jean-loup Gailly and Mark Adler
// (C) 2014-2017 Vitaly Puzrin and Andrey Tupitsin
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//   claim that you wrote the original software. If you use this software
//   in a product, an acknowledgment in the product documentation would be
//   appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//   misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.
const record_Messages_1: Record<string, string>  = {
  '2': 'need dictionary' /* Z_NEED_DICT       2  */,
  '1': 'stream end' /* Z_STREAM_END      1  */,
  '0': '' /* Z_OK              0  */,
  '-1': 'file error' /* Z_ERRNO         (-1) */,
  '-2': 'stream error' /* Z_STREAM_ERROR  (-2) */,
  '-3': 'data error' /* Z_DATA_ERROR    (-3) */,
  '-4': 'insufficient memory' /* Z_MEM_ERROR     (-4) */,
  '-5': 'buffer error' /* Z_BUF_ERROR     (-5) */,
  '-6': 'incompatible version' /* Z_VERSION_ERROR (-6) */,
};

const Z_NO_FLUSH = 0;
const Z_PARTIAL_FLUSH = 1;
const Z_SYNC_FLUSH = 2;
const Z_FULL_FLUSH = 3;
const Z_FINISH = 4;
const Z_BLOCK = 5;
const Z_TREES = 6;
const Z_OK = 0;
const Z_STREAM_END = 1;
const Z_NEED_DICT = 2;
const Z_ERRNO = -1;
const Z_STREAM_ERROR = -2;
const Z_DATA_ERROR = -3;
const Z_MEM_ERROR = -4;
const Z_BUF_ERROR = -5;
const Z_NO_COMPRESSION = 0;
const Z_BEST_SPEED = 1;
const Z_BEST_COMPRESSION = 9;
const Z_DEFAULT_COMPRESSION = -1;
const Z_FILTERED = 1;
const Z_HUFFMAN_ONLY = 2;
const Z_RLE = 3;
const Z_FIXED = 4;
const Z_DEFAULT_STRATEGY = 0;
const Z_BINARY = 0;
const Z_TEXT = 1;
const Z_UNKNOWN = 2;
const Z_DEFLATED = 8;

interface GeneratedObjectLiteralInterface_1 {
  Z_NO_FLUSH: number;
  Z_PARTIAL_FLUSH: number;
  Z_SYNC_FLUSH: number;
  Z_FULL_FLUSH: number;
  Z_FINISH: number;
  Z_BLOCK: number;
  Z_TREES: number;
  Z_OK: number;
  Z_STREAM_END: number;
  Z_NEED_DICT: number;
  Z_ERRNO: number;
  Z_STREAM_ERROR: number;
  Z_DATA_ERROR: number;
  Z_MEM_ERROR: number;
  Z_BUF_ERROR: number;
  Z_NO_COMPRESSION: number;
  Z_BEST_SPEED: number;
  Z_BEST_COMPRESSION: number;
  Z_DEFAULT_COMPRESSION: number;
  Z_FILTERED: number;
  Z_HUFFMAN_ONLY: number;
  Z_RLE: number;
  Z_FIXED: number;
  Z_DEFAULT_STRATEGY: number;
  Z_BINARY: number;
  Z_TEXT: number;
  Z_UNKNOWN: number;
  Z_DEFLATED: number;
}

const varGeneratedObjTypeLiteralInterface_Constants1: GeneratedObjectLiteralInterface_1 = {
  Z_NO_FLUSH: Z_NO_FLUSH,
  Z_PARTIAL_FLUSH: Z_PARTIAL_FLUSH,
  Z_SYNC_FLUSH: Z_SYNC_FLUSH,
  Z_FULL_FLUSH: Z_FULL_FLUSH,
  Z_FINISH: Z_FINISH,
  Z_BLOCK: Z_BLOCK,
  Z_TREES: Z_TREES,
  Z_OK: Z_OK,
  Z_STREAM_END: Z_STREAM_END,
  Z_NEED_DICT: Z_NEED_DICT,
  Z_ERRNO: Z_ERRNO,
  Z_STREAM_ERROR: Z_STREAM_ERROR,
  Z_DATA_ERROR: Z_DATA_ERROR,
  Z_MEM_ERROR: Z_MEM_ERROR,
  Z_BUF_ERROR: Z_BUF_ERROR,
  Z_NO_COMPRESSION: Z_NO_COMPRESSION,
  Z_BEST_SPEED: Z_BEST_SPEED,
  Z_BEST_COMPRESSION: Z_BEST_COMPRESSION,
  Z_DEFAULT_COMPRESSION: Z_DEFAULT_COMPRESSION,
  Z_FILTERED: Z_FILTERED,
  Z_HUFFMAN_ONLY: Z_HUFFMAN_ONLY,
  Z_RLE: Z_RLE,
  Z_FIXED: Z_FIXED,
  Z_DEFAULT_STRATEGY: Z_DEFAULT_STRATEGY,
  Z_BINARY: Z_BINARY,
  Z_TEXT: Z_TEXT,
  Z_UNKNOWN: Z_UNKNOWN,
  Z_DEFLATED: Z_DEFLATED,
};

class ZStreamDeflate {
  input: Uint8Array;
  next_in: number;
  avail_in: number;
  total_in: number;
  output: Uint8Array;
  next_out: number;
  avail_out: number;
  total_out: number;
  msg: string;
  state: DeflateState | null;
  data_type: number;
  adler: number;

  constructor() {
    this.input = new Uint8Array;
    this.next_in = 0;
    this.avail_in = 0;
    this.total_in = 0;
    this.output = new Uint8Array;
    this.next_out = 0;
    this.avail_out = 0;
    this.total_out = 0;
    this.msg = '';
    this.state = null;
    this.data_type = 2;
    this.adler = 0;
  }
}
class ZStreamInflate {
  input: Uint8Array;
  next_in: number;
  avail_in: number;
  total_in: number;
  output: Uint8Array;
  next_out: number;
  avail_out: number;
  total_out: number;
  msg: string;
  state: InflateState | null;
  data_type: number;
  adler: number;

  constructor() {
    this.input = new Uint8Array;
    this.next_in = 0;
    this.avail_in = 0;
    this.total_in = 0;
    this.output = new Uint8Array;
    this.next_out = 0;
    this.avail_out = 0;
    this.total_out = 0;
    this.msg = '';
    this.state = null;
    this.data_type = 2;
    this.adler = 0;
  }
}

/*============================================================================*/
const MAX_MEM_LEVEL = 9;
const LENGTH_CODES = 29;
/* number of length codes, not counting the special END_BLOCK code */
const LITERALS = 256;
/* number of literal bytes 0..255 */
const L_CODES = LITERALS + 1 + LENGTH_CODES;
/* number of Literal or Length codes, including the END_BLOCK code */
const D_CODES = 30;
/* number of distance codes */
const BL_CODES = 19;
/* number of codes used to transfer the bit lengths */
const HEAP_SIZE = 2 * L_CODES + 1;
/* maximum heap size */
const MAX_BITS = 15;
/* All codes must not exceed MAX_BITS bits */
const MAX_MATCH = 258;
const MIN_MATCH = 3;
const MIN_LOOKAHEAD = (MAX_MATCH + MIN_MATCH + 1);
const PRESET_DICT = 0x20;
const INIT_STATE = 42; /* zlib header -> BUSY_STATE */
//#ifdef GZIP
const GZIP_STATE = 57; /* gzip header -> BUSY_STATE | EXTRA_STATE */
//#endif
const EXTRA_STATE = 69; /* gzip extra block -> NAME_STATE */
const NAME_STATE = 73; /* gzip file name -> COMMENT_STATE */
const COMMENT_STATE = 91; /* gzip comment -> HCRC_STATE */
const HCRC_STATE = 103; /* gzip header CRC -> BUSY_STATE */
const BUSY_STATE = 113;
/* deflate -> FINISH_STATE */
const FINISH_STATE = 666; /* stream complete */
const BS_NEED_MORE = 1; /* block not completed, need more input or more output */
const BS_BLOCK_DONE = 2; /* block flush performed */
const BS_FINISH_STARTED = 3; /* finish started, need only more output at next deflate */
const BS_FINISH_DONE = 4; /* finish done, accept no more input or output */
const OS_CODE = 0x03; // Unix :) . Don't detect, use this default.
const err = (strm: ZStreamDeflate, errorCode: number): number => {
  strm.msg = record_Messages_1[errorCode];
  return errorCode;
};
const rank = (f: number): number => {
  return ((f) * 2) - ((f) > 4 ? 9 : 0);
};
const zero = (buf: Uint16Array) => {
  let len = buf.length;
  while (--len >= 0) {
    buf[len] = 0;
  }
};
/* ===========================================================================
 * Slide the hash table when sliding the window down (could be avoided with 32
 * bit values at the expense of memory usage). We slide even when level == 0 to
 * keep the hash table consistent if we switch back to level > 0 later.
 */
const slide_hash = (s: DeflateState) => {
  let n: number, m: number;
  let p: number;
  let wsize: number = s.w_size;
  n = s.hash_size;
  p = n;
  do {
    m = s.head[--p];
    s.head[p] = (m >= wsize ? m - wsize : 0);
  } while (--n);
  n = wsize;
  p = n;
  do {
    m = s.prev[--p];
    s.prev[p] = (m >= wsize ? m - wsize : 0);
    /* If n is not on any hash chain, prev[n] is garbage but
         * its value will never be used.
         */
  } while (--n);
};
/* eslint-disable new-cap */
let HASH = (s: DeflateState, prev: number, data: number): number => ((prev << s.hash_shift) ^ data) & s.hash_mask;
/* =========================================================================
 * Flush as much pending output as possible. All deflate() output, except for
 * some deflate_stored() output, goes through this function so some
 * applications may wish to modify it to avoid allocating a large
 * strm->next_out buffer and copying into it. (See also read_buf()).
 */
const flush_pending = (strm: ZStreamDeflate) => {
  const s:DeflateState = strm.state as DeflateState;
  let len: number = s.pending;
  if (len > strm.avail_out) {
    len = strm.avail_out;
  }
  if (len === 0) {
    return;
  }
  strm.output.set(s.pending_buf.subarray(s.pending_out, s.pending_out + len), strm.next_out);
  strm.next_out += len;
  s.pending_out += len;
  strm.total_out += len;
  strm.avail_out -= len;
  s.pending -= len;
  if (s.pending === 0) {
    s.pending_out = 0;
  }
};
const flush_block_only = (s: DeflateState, last: boolean) => {
  _tr_flush_block(s, s.block_start >= 0 ? s.block_start : -1, s.strstart - s.block_start, last);
  s.block_start = s.strstart;
  flush_pending(s.strm);
};
const put_byte = (s: DeflateState, b: number) => {
  s.pending_buf[s.pending++] = b;
};
/* =========================================================================
 * Put a short in the pending buffer. The 16-bit value is put in MSB order.
 * IN assertion: the stream state is correct and there is enough room in
 * pending_buf.
 */
const putShortMSB = (s: DeflateState, b: number) => {
  s.pending_buf[s.pending++] = (b >>> 8) & 0xff;
  s.pending_buf[s.pending++] = b & 0xff;
};
/* ===========================================================================
 * Read a new buffer from the current input stream, update the adler32
 * and total number of bytes read.  All deflate() input goes through
 * this function so some applications may wish to modify it to avoid
 * allocating a large strm->input buffer and copying from it.
 * (See also flush_pending()).
 */
const read_buf = (strm: ZStreamDeflate, buf: Uint8Array, start: number, size: number): number => {
  let len = strm.avail_in;
  if (len > size) {
    len = size;
  }
  if (len === 0 || strm.state === null) {
    return 0;
  }
  strm.avail_in -= len;
  // zmemcpy(buf, strm->next_in, len);
  buf.set(strm.input.subarray(strm.next_in, strm.next_in + len), start);
  if (strm.state.wrap === 1) {
    strm.adler = adler32(strm.adler, buf, len, start);
  }
  else if (strm.state.wrap === 2) {
    strm.adler = crc32(strm.adler, buf, len, start);
  }
  strm.next_in += len;
  strm.total_in += len;
  return len;
};
/* ===========================================================================
 * Set match_start to the longest match starting at the given string and
 * return its length. Matches shorter or equal to prev_length are discarded,
 * in which case the result is equal to prev_length and match_start is
 * garbage.
 * IN assertions: cur_match is the head of the hash chain for the current
 *   string (strstart) and its distance is <= MAX_DIST, and prev_length >= 1
 * OUT assertion: the match length is not greater than s->lookahead.
 */
const longest_match = (s: DeflateState, cur_match: number): number => {
  let chain_length = s.max_chain_length; /* max hash chain length */
  let scan = s.strstart; /* current string */
  let match: number; /* matched string */
  let len: number; /* length of current match */
  let best_len = s.prev_length; /* best match length so far */
  let nice_match = s.nice_match; /* stop if match long enough */
  const limit = (s.strstart > (s.w_size - MIN_LOOKAHEAD)) ?
    s.strstart - (s.w_size - MIN_LOOKAHEAD) : 0 /*NIL*/;
  const _win = s.window; // shortcut
  const wmask = s.w_mask;
  const prev = s.prev;
  const strend = s.strstart + MAX_MATCH;
  let scan_end1 = _win[scan + best_len - 1];
  let scan_end = _win[scan + best_len];
  if (s.prev_length >= s.good_match) {
    chain_length >>= 2;
  }
  if (nice_match > s.lookahead) {
    nice_match = s.lookahead;
  }
  do {
    match = cur_match;
    if (_win[match + best_len] !== scan_end ||
      _win[match + best_len - 1] !== scan_end1 ||
      _win[match] !== _win[scan] ||
      _win[++match] !== _win[scan + 1]) {
      continue;
    }
    scan += 2;
    match++;
    do {
      /*jshint noempty:false*/
    } while (_win[++scan] === _win[++match] && _win[++scan] === _win[++match] &&
      _win[++scan] === _win[++match] && _win[++scan] === _win[++match] &&
      _win[++scan] === _win[++match] && _win[++scan] === _win[++match] &&
      _win[++scan] === _win[++match] && _win[++scan] === _win[++match] &&
      scan < strend);
    len = MAX_MATCH - (strend - scan);
    scan = strend - MAX_MATCH;
    if (len > best_len) {
      s.match_start = cur_match;
      best_len = len;
      if (len >= nice_match) {
        break;
      }
      scan_end1 = _win[scan + best_len - 1];
      scan_end = _win[scan + best_len];
    }
  } while ((cur_match = prev[cur_match & wmask]) > limit && --chain_length !== 0);
  if (best_len <= s.lookahead) {
    return best_len;
  }
  return s.lookahead;
};
/* ===========================================================================
 * Fill the window when the lookahead becomes insufficient.
 * Updates strstart and lookahead.
 *
 * IN assertion: lookahead < MIN_LOOKAHEAD
 * OUT assertions: strstart <= window_size-MIN_LOOKAHEAD
 *    At least one byte has been read, or avail_in == 0; reads are
 *    performed for at least two bytes (required for the zip translate_eol
 *    option -- not supported here).
 */
const fill_window = (s: DeflateState) => {
  const _w_size = s.w_size;
  let n: number, more: number, str: number;
  const MIN_MATCH = 3; // Define MIN_MATCH as per the context
  do {
    more = s.window_size - s.lookahead - s.strstart;
    if (s.strstart >= _w_size + (_w_size - MIN_LOOKAHEAD)) {
      s.window.set(s.window.subarray(_w_size, _w_size + _w_size - more), 0);
      s.match_start -= _w_size;
      s.strstart -= _w_size;
      s.block_start -= _w_size;
      if (s.insert > s.strstart) {
        s.insert = s.strstart;
      }
      slide_hash(s);
      more += _w_size;
    }
    if (s.strm.avail_in === 0) {
      break;
    }
    n = read_buf(s.strm, s.window, s.strstart + s.lookahead, more);
    s.lookahead += n;
    if (s.lookahead + s.insert >= MIN_MATCH) {
      str = s.strstart - s.insert;
      s.ins_h = s.window[str];
      s.ins_h = HASH(s, s.ins_h, s.window[str + 1]);
      while (s.insert) {
        s.ins_h = HASH(s, s.ins_h, s.window[str + MIN_MATCH - 1]);
        s.prev[str & s.w_mask] = s.head[s.ins_h];
        s.head[s.ins_h] = str;
        str++;
        s.insert--;
        if (s.lookahead + s.insert < MIN_MATCH) {
          break;
        }
      }
    }
  } while (s.lookahead < MIN_LOOKAHEAD && s.strm.avail_in !== 0);
};
/* ===========================================================================
 * Copy without compression as much as possible from the input stream, return
 * the current block state.
 *
 * In case deflateParams() is used to later switch to a non-zero compression
 * level, s->matches (otherwise unused when storing) keeps track of the number
 * of hash table slides to perform. If s->matches is 1, then one hash table
 * slide will be done when switching. If s->matches is 2, the maximum value
 * allowed here, then the hash table will be cleared, since two or more slides
 * is the same as a clear.
 *
 * deflate_stored() is written to minimize the number of times an input byte is
 * copied. It is most efficient with large input and output buffers, which
 * maximizes the opportunites to have a single copy from next_in to next_out.
 */
const deflate_stored = (s: DeflateState, flush: number): number => {
  let min_block: number = s.pending_buf_size - 5 > s.w_size ? s.w_size : s.pending_buf_size - 5;
  let len: number;
  let left: number;
  let have: number;
  let last: number = 0;
  let used: number = s.strm.avail_in;
  do {
    len = 65535; /* MAX_STORED */
    have = (s.bi_valid + 42) >> 3;
    if (s.strm.avail_out < have) {
      break;
    }
    have = s.strm.avail_out - have;
    left = s.strstart - s.block_start;
    if (len > left + s.strm.avail_in) {
      len = left + s.strm.avail_in;
    }
    if (len > have) {
      len = have;
    }
    if (len < min_block && ((len === 0 && flush !== Z_FINISH) || flush === Z_NO_FLUSH || len !== left + s.strm.avail_in)) {
      break;
    }
    last = flush === Z_FINISH && len === left + s.strm.avail_in ? 1 : 0;
    _tr_stored_block(s, 0, 0, Boolean(last));
    s.pending_buf[s.pending - 4] = len;
    s.pending_buf[s.pending - 3] = len >> 8;
    s.pending_buf[s.pending - 2] = ~len;
    s.pending_buf[s.pending - 1] = ~len >> 8;
    flush_pending(s.strm);
    if (left) {
      if (left > len) {
        left = len;
      }
      s.strm.output.set(s.window.subarray(s.block_start, s.block_start + left), s.strm.next_out);
      s.strm.next_out += left;
      s.strm.avail_out -= left;
      s.strm.total_out += left;
      s.block_start += left;
      len -= left;
    }
    if (len) {
      read_buf(s.strm, s.strm.output, s.strm.next_out, len);
      s.strm.next_out += len;
      s.strm.avail_out -= len;
      s.strm.total_out += len;
    }
  } while (last === 0);
  used -= s.strm.avail_in;
  if (used) {
    if (used >= s.w_size) {
      s.matches = 2;
      s.window.set(s.strm.input.subarray(s.strm.next_in - s.w_size, s.strm.next_in), 0);
      s.strstart = s.w_size;
      s.insert = s.strstart;
    }
    else {
      if (s.window_size - s.strstart <= used) {
        s.strstart -= s.w_size;
        s.window.set(s.window.subarray(s.w_size, s.w_size + s.strstart), 0);
        if (s.matches < 2) {
          s.matches++;
        }
        if (s.insert > s.strstart) {
          s.insert = s.strstart;
        }
      }
      s.window.set(s.strm.input.subarray(s.strm.next_in - used, s.strm.next_in), s.strstart);
      s.strstart += used;
      s.insert += used > s.w_size - s.insert ? s.w_size - s.insert : used;
    }
    s.block_start = s.strstart;
  }
  if (s.high_water < s.strstart) {
    s.high_water = s.strstart;
  }
  if (last) {
    return BS_FINISH_DONE;
  }
  if (flush !== Z_NO_FLUSH && flush !== Z_FINISH &&
    s.strm.avail_in === 0 && s.strstart === s.block_start) {
    return BS_BLOCK_DONE;
  }
  have = s.window_size - s.strstart;
  if (s.strm.avail_in > have && s.block_start >= s.w_size) {
    s.block_start -= s.w_size;
    s.strstart -= s.w_size;
    s.window.set(s.window.subarray(s.w_size, s.w_size + s.strstart), 0);
    if (s.matches < 2) {
      s.matches++;
    }
    have += s.w_size;
    if (s.insert > s.strstart) {
      s.insert = s.strstart;
    }
  }
  if (have > s.strm.avail_in) {
    have = s.strm.avail_in;
  }
  if (have) {
    read_buf(s.strm, s.window, s.strstart, have);
    s.strstart += have;
    s.insert += have > s.w_size - s.insert ? s.w_size - s.insert : have;
  }
  if (s.high_water < s.strstart) {
    s.high_water = s.strstart;
  }
  have = (s.bi_valid + 42) >> 3;
  have = s.pending_buf_size - have > 65535 ? 65535 : s.pending_buf_size - have;
  min_block = have > s.w_size ? s.w_size : have;
  left = s.strstart - s.block_start;
  if (left >= min_block ||
    ((left || flush === Z_FINISH) && flush !== Z_NO_FLUSH &&
      s.strm.avail_in === 0 && left <= have)) {
    len = left > have ? have : left;
    last = flush === Z_FINISH && s.strm.avail_in === 0 &&
      len === left ? 1 : 0;
    _tr_stored_block(s, s.block_start, len, Boolean(last));
    s.block_start += len;
    flush_pending(s.strm);
  }
  return last ? BS_FINISH_STARTED : BS_NEED_MORE;
};
/* ===========================================================================
 * Compress as much as possible from the input stream, return the current
 * block state.
 * This function does not perform lazy evaluation of matches and inserts
 * new strings in the dictionary only for unmatched strings or for short
 * matches. It is used only for the fast compression options.
 */
const deflate_fast = (s: DeflateState, flush: number): number => {
  let hash_head = 0; /* head of the hash chain */
  let bflush = false; /* set if current block must be flushed */
  for (;;) {
    if (s.lookahead < MIN_LOOKAHEAD) {
      fill_window(s);
      if (s.lookahead < MIN_LOOKAHEAD && flush === Z_NO_FLUSH) {
        return BS_NEED_MORE;
      }
      if (s.lookahead === 0) {
        break; /* flush the current block */
      }
    }
    hash_head = 0 /*NIL*/;
    if (s.lookahead >= MIN_MATCH) {
      /*** INSERT_STRING(s, s.strstart, hash_head); ***/
      s.ins_h = HASH(s, s.ins_h, s.window[s.strstart + MIN_MATCH - 1]);
      hash_head = s.prev[s.strstart & s.w_mask] = s.head[s.ins_h];
      s.head[s.ins_h] = s.strstart;
      /***/
    }
    if (hash_head !== 0 /*NIL*/ && ((s.strstart - hash_head) <= (s.w_size - MIN_LOOKAHEAD))) {
      s.match_length = longest_match(s, hash_head);
      /* longest_match() sets match_start */
    }
    if (s.match_length >= MIN_MATCH) {
      /*** _tr_tally_dist(s, s.strstart - s.match_start,
       s.match_length - MIN_MATCH, bflush); ***/
      bflush = _tr_tally(s, s.strstart - s.match_start, s.match_length - MIN_MATCH);
      s.lookahead -= s.match_length;
      if (s.match_length <= s.max_lazy_match /*max_insert_length*/ && s.lookahead >= MIN_MATCH) {
        s.match_length--; /* string at strstart already in table */
        do {
          s.strstart++;
          /*** INSERT_STRING(s, s.strstart, hash_head); ***/
          s.ins_h = HASH(s, s.ins_h, s.window[s.strstart + MIN_MATCH - 1]);
          hash_head = s.prev[s.strstart & s.w_mask] = s.head[s.ins_h];
          s.head[s.ins_h] = s.strstart;
          /***/
          /* strstart never exceeds WSIZE-MAX_MATCH, so there are
                     * always MIN_MATCH bytes ahead.
                     */
        } while (--s.match_length !== 0);
        s.strstart++;
      }
      else {
        s.strstart += s.match_length;
        s.match_length = 0;
        s.ins_h = s.window[s.strstart];
        s.ins_h = HASH(s, s.ins_h, s.window[s.strstart + 1]);
        //#if MIN_MATCH != 3
        //                Call UPDATE_HASH() MIN_MATCH-3 more times
        //#endif
        /* If lookahead < MIN_MATCH, ins_h is garbage, but it does not
                 * matter since it will be recomputed at next deflate call.
                 */
      }
    }
    else {
      /*** _tr_tally_lit(s, s.window[s.strstart], bflush); ***/
      bflush = _tr_tally(s, 0, s.window[s.strstart]);
      s.lookahead--;
      s.strstart++;
    }
    if (bflush) {
      /*** FLUSH_BOCK(s, 0); ***/
      flush_block_only(s, false);
      if (s.strm.avail_out === 0) {
        return BS_NEED_MORE;
      }
      /***/
    }
  }
  s.insert = ((s.strstart < (MIN_MATCH - 1)) ? s.strstart : MIN_MATCH - 1);
  if (flush === Z_FINISH) {
    /*** FLUSH_BLOCK(s, 1); ***/
    flush_block_only(s, true);
    if (s.strm.avail_out === 0) {
      return BS_FINISH_STARTED;
    }
    /***/
    return BS_FINISH_DONE;
  }
  if (s.sym_next) {
    /*** FLUSH_BLOCK(s, 0); ***/
    flush_block_only(s, false);
    if (s.strm.avail_out === 0) {
      return BS_NEED_MORE;
    }
    /***/
  }
  return BS_BLOCK_DONE;
};
/* ===========================================================================
 * Same as above, but achieves better compression. We use a lazy
 * evaluation for matches: a match is finally adopted only if there is
 * no better match at the next window position.
 */
const deflate_slow = (s: DeflateState, flush: number): number => {
  let hash_head = 0; /* head of hash chain */
  let bflush = false; /* set if current block must be flushed */
  let max_insert = 0;
  for (;;) {
    if (s.lookahead < MIN_LOOKAHEAD) {
      fill_window(s);
      if (s.lookahead < MIN_LOOKAHEAD && flush === Z_NO_FLUSH) {
        return BS_NEED_MORE;
      }
      if (s.lookahead === 0) {
        break;
      } /* flush the current block */
    }
    hash_head = 0 /*NIL*/;
    if (s.lookahead >= MIN_MATCH) {
      /*** INSERT_STRING(s, s.strstart, hash_head); ***/
      s.ins_h = HASH(s, s.ins_h, s.window[s.strstart + MIN_MATCH - 1]);
      hash_head = s.prev[s.strstart & s.w_mask] = s.head[s.ins_h];
      s.head[s.ins_h] = s.strstart;
      /***/
    }
    s.prev_length = s.match_length;
    s.prev_match = s.match_start;
    s.match_length = MIN_MATCH - 1;
    if (hash_head !== 0 /*NIL*/ && s.prev_length < s.max_lazy_match &&
      s.strstart - hash_head <= (s.w_size - MIN_LOOKAHEAD) /*MAX_DIST(s)*/) {
      s.match_length = longest_match(s, hash_head);
      if (s.match_length <= 5 &&
        (s.strategy === Z_FILTERED || (s.match_length === MIN_MATCH && s.strstart - s.match_start > 4096 /*TOO_FAR*/))) {
        s.match_length = MIN_MATCH - 1;
      }
    }
    if (s.prev_length >= MIN_MATCH && s.match_length <= s.prev_length) {
      max_insert = s.strstart + s.lookahead - MIN_MATCH;
      /***_tr_tally_dist(s, s.strstart - 1 - s.prev_match,
       s.prev_length - MIN_MATCH, bflush);***/
      bflush = _tr_tally(s, s.strstart - 1 - s.prev_match, s.prev_length - MIN_MATCH);
      s.lookahead -= s.prev_length - 1;
      s.prev_length -= 2;
      do {
        if (++s.strstart <= max_insert) {
          /*** INSERT_STRING(s, s.strstart, hash_head); ***/
          s.ins_h = HASH(s, s.ins_h, s.window[s.strstart + MIN_MATCH - 1]);
          hash_head = s.prev[s.strstart & s.w_mask] = s.head[s.ins_h];
          s.head[s.ins_h] = s.strstart;
          /***/
        }
      } while (--s.prev_length !== 0);
      s.match_available = false;
      s.match_length = MIN_MATCH - 1;
      s.strstart++;
      if (bflush) {
        /*** FLUSH_BLOCK(s, 0); ***/
        flush_block_only(s, false);
        if (s.strm.avail_out === 0) {
          return BS_NEED_MORE;
        }
        /***/
      }
    }
    else if (s.match_available) {
      /*** _tr_tally_lit(s, s.window[s.strstart-1], bflush); ***/
      bflush = _tr_tally(s, 0, s.window[s.strstart - 1]);
      if (bflush) {
        /*** FLUSH_BLOCK_ONLY(s, 0) ***/
        flush_block_only(s, false);
        /***/
      }
      s.strstart++;
      s.lookahead--;
      if (s.strm.avail_out === 0) {
        return BS_NEED_MORE;
      }
    }
    else {
      s.match_available = true;
      s.strstart++;
      s.lookahead--;
    }
  }
  if (s.match_available) {
    /*** _tr_tally_lit(s, s.window[s.strstart-1], bflush); ***/
    bflush = _tr_tally(s, 0, s.window[s.strstart - 1]);
    s.match_available = false;
  }
  s.insert = s.strstart < MIN_MATCH - 1 ? s.strstart : MIN_MATCH - 1;
  if (flush === Z_FINISH) {
    /*** FLUSH_BLOCK(s, 1); ***/
    flush_block_only(s, true);
    if (s.strm.avail_out === 0) {
      return BS_FINISH_STARTED;
    }
    /***/
    return BS_FINISH_DONE;
  }
  if (s.sym_next) {
    /*** FLUSH_BLOCK(s, 0); ***/
    flush_block_only(s, false);
    if (s.strm.avail_out === 0) {
      return BS_NEED_MORE;
    }
    /***/
  }
  return BS_BLOCK_DONE;
};
/* ===========================================================================
 * For Z_RLE, simply look for runs of bytes, generate matches only of distance
 * one.  Do not maintain a hash table.  (It will be regenerated if this run of
 * deflate switches away from Z_RLE.)
 */
const deflate_rle = (s: DeflateState, flush: number): number => {
  let bflush = false; /* set if current block must be flushed */
  let prev = 0; /* byte at distance one to match */
  let scan = 0, strend = 0; /* scan goes up to strend for length of run */
  const _win = s.window;
  for (;;) {
    if (s.lookahead <= MAX_MATCH) {
      fill_window(s);
      if (s.lookahead <= MAX_MATCH && flush === Z_NO_FLUSH) {
        return BS_NEED_MORE;
      }
      if (s.lookahead === 0) {
        break;
      } /* flush the current block */
    }
    s.match_length = 0;
    if (s.lookahead >= MIN_MATCH && s.strstart > 0) {
      scan = s.strstart - 1;
      prev = _win[scan];
      if (prev === _win[++scan] && prev === _win[++scan] && prev === _win[++scan]) {
        strend = s.strstart + MAX_MATCH;
        do {
          /*jshint noempty:false*/
        } while (prev === _win[++scan] &&
          prev === _win[++scan] &&
          prev === _win[++scan] &&
          prev === _win[++scan] &&
          prev === _win[++scan] &&
          prev === _win[++scan] &&
          prev === _win[++scan] &&
          prev === _win[++scan] &&
          scan < strend);
        s.match_length = MAX_MATCH - (strend - scan);
        if (s.match_length > s.lookahead) {
          s.match_length = s.lookahead;
        }
      }
      //Assert(scan <= s->window+(uInt)(s->window_size-1), "wild scan");
    }
    if (s.match_length >= MIN_MATCH) {
      /*** _tr_tally_dist(s, 1, s.match_length - MIN_MATCH, bflush); ***/
      bflush = _tr_tally(s, 1, s.match_length - MIN_MATCH);
      s.lookahead -= s.match_length;
      s.strstart += s.match_length;
      s.match_length = 0;
    }
    else {
      /*** _tr_tally_lit(s, s.window[s.strstart], bflush); ***/
      bflush = _tr_tally(s, 0, s.window[s.strstart]);
      s.lookahead--;
      s.strstart++;
    }
    if (bflush) {
      flush_block_only(s, false);
      if (s.strm.avail_out === 0) {
        return BS_NEED_MORE;
      }
    }
  }
  s.insert = 0;
  if (flush === Z_FINISH) {
    flush_block_only(s, true);
    if (s.strm.avail_out === 0) {
      return BS_FINISH_STARTED;
    }
    return BS_FINISH_DONE;
  }
  if (s.sym_next) {
    flush_block_only(s, false);
    if (s.strm.avail_out === 0) {
      return BS_NEED_MORE;
    }
  }
  return BS_BLOCK_DONE;
};
/* ===========================================================================
 * For Z_HUFFMAN_ONLY, do not look for matches.  Do not maintain a hash table.
 * (It will be regenerated if this run of deflate switches away from Huffman.)
 */
const deflate_huff = (s: DeflateState, flush: number): number => {
  let bflush = false; /* set if current block must be flushed */
  for (;;) {
    if (s.lookahead === 0) {
      fill_window(s);
      if (s.lookahead === 0) {
        if (flush === Z_NO_FLUSH) {
          return BS_NEED_MORE;
        }
        break; /* flush the current block */
      }
    }
    s.match_length = 0;
    /*** _tr_tally_lit(s, s.window[s.strstart], bflush); ***/
    bflush = _tr_tally(s, 0, s.window[s.strstart]);
    s.lookahead--;
    s.strstart++;
    if (bflush) {
      /*** FLUSH_BLOCK(s, 0); ***/
      flush_block_only(s, false);
      if (s.strm.avail_out === 0) {
        return BS_NEED_MORE;
      }
      /***/
    }
  }
  s.insert = 0;
  if (flush === Z_FINISH) {
    /*** FLUSH_BLOCK(s, 1); ***/
    flush_block_only(s, true);
    if (s.strm.avail_out === 0) {
      return BS_FINISH_STARTED;
    }
    /***/
    return BS_FINISH_DONE;
  }
  if (s.sym_next) {
    /*** FLUSH_BLOCK(s, 0); ***/
    flush_block_only(s, false);
    if (s.strm.avail_out === 0) {
      return BS_NEED_MORE;
    }
    /***/
  }
  return BS_BLOCK_DONE;
};
/* Values for max_lazy_match, good_match and max_chain_length, depending on
 * the desired pack level (0..9). The values given below have been tuned to
 * exclude worst case performance for pathological files. Better values may be
 * found for specific files.
 */
class Config {
  good_length: number;
  max_lazy: number;
  nice_length: number;
  max_chain: number;
  func: Function;

  constructor(good_length: number, max_lazy: number, nice_length: number, max_chain: number, func: Function) {
    this.good_length = good_length;
    this.max_lazy = max_lazy;
    this.nice_length = nice_length;
    this.max_chain = max_chain;
    this.func = func;
  }
}
const configuration_table = [
  new Config(0, 0, 0, 0, deflate_stored), /* 0 store only */
  new Config(4, 4, 8, 4, deflate_fast), /* 1 max speed, no lazy matches */
  new Config(4, 5, 16, 8, deflate_fast), /* 2 */
  new Config(4, 6, 32, 32, deflate_fast), /* 3 */
  new Config(4, 4, 16, 16, deflate_slow), /* 4 lazy matches */
  new Config(8, 16, 32, 32, deflate_slow), /* 5 */
  new Config(8, 16, 128, 128, deflate_slow), /* 6 */
  new Config(8, 32, 128, 256, deflate_slow), /* 7 */
  new Config(32, 128, 258, 1024, deflate_slow), /* 8 */
  new Config(32, 258, 258, 4096, deflate_slow) /* 9 max compression */
];
/* ===========================================================================
 * Initialize the "longest match" routines for a new zlib stream
 */
const lm_init = (s: DeflateState) => {
  s.window_size = 2 * s.w_size;
  /*** CLEAR_HASH(s); ***/
  zero(s.head); // Fill with NIL (= 0);
  s.max_lazy_match = configuration_table[s.level].max_lazy;
  s.good_match = configuration_table[s.level].good_length;
  s.nice_match = configuration_table[s.level].nice_length;
  s.max_chain_length = configuration_table[s.level].max_chain;
  s.strstart = 0;
  s.block_start = 0;
  s.lookahead = 0;
  s.insert = 0;
  s.match_length = s.prev_length = MIN_MATCH - 1;
  s.match_available = Boolean(0);
  s.ins_h = 0;
};
class DeflateState {
  strm: ZStreamDeflate;
  status: number;
  pending_buf: Uint8Array;
  pending_buf_size: number;
  pending_out: number;
  pending: number;
  wrap: number;
  gzhead: GZheader | null;
  gzindex: number;
  method: number;
  last_flush: number;
  w_size: number;
  w_bits: number;
  w_mask: number;
  window: Uint8Array;
  window_size: number;
  prev: Uint16Array;
  head: Uint16Array;
  ins_h: number;
  hash_size: number;
  hash_bits: number;
  hash_mask: number;
  hash_shift: number;
  block_start: number;
  match_length: number;
  prev_match: number;
  match_available: boolean;
  strstart: number;
  match_start: number;
  lookahead: number;
  prev_length: number;
  max_chain_length: number;
  max_lazy_match: number;
  level: number;
  strategy: number;
  high_water:number;
  good_match: number;
  nice_match: number;
  dyn_ltree: Uint16Array;
  dyn_dtree: Uint16Array;
  bl_tree: Uint16Array;
  l_desc: TreeDesc | null;
  d_desc: TreeDesc | null;
  bl_desc: TreeDesc | null;
  bl_count: Uint16Array;
  heap: Uint16Array;
  heap_len: number;
  heap_max: number;
  depth: Uint16Array;
  sym_buf: number;
  lit_bufsize: number;
  sym_next: number;
  sym_end: number;
  opt_len: number;
  static_len: number;
  matches: number;
  insert: number;
  bi_buf: number;
  bi_valid: number;

  constructor() {
    this.high_water = 0;
    this.strm = new ZStreamDeflate;
    this.status = 0;
    this.pending_buf = new Uint8Array;
    this.pending_buf_size = 0;
    this.pending_out = 0;
    this.pending = 0;
    this.wrap = 0;
    this.gzhead = null;
    this.gzindex = 0;
    this.method = Z_DEFLATED;
    this.last_flush = -1;
    this.w_size = 0;
    this.w_bits = 0;
    this.w_mask = 0;
    this.window = new Uint8Array;
    this.window_size = 0;
    this.prev = new Uint16Array;
    this.head = new Uint16Array;
    this.ins_h = 0;
    this.hash_size = 0;
    this.hash_bits = 0;
    this.hash_mask = 0;
    this.hash_shift = 0;
    this.block_start = 0;
    this.match_length = 0;
    this.prev_match = 0;
    this.match_available = Boolean(0);
    this.strstart = 0;
    this.match_start = 0;
    this.lookahead = 0;
    this.prev_length = 0;
    this.max_chain_length = 0;
    this.max_lazy_match = 0;
    this.level = 0;
    this.strategy = 0;
    this.good_match = 0;
    this.nice_match = 0;
    this.dyn_ltree = new Uint16Array(HEAP_SIZE * 2);
    this.dyn_dtree = new Uint16Array((2 * D_CODES + 1) * 2);
    this.bl_tree = new Uint16Array((2 * BL_CODES + 1) * 2);
    zero(this.dyn_ltree);
    zero(this.dyn_dtree);
    zero(this.bl_tree);
    this.l_desc = null;
    this.d_desc = null;
    this.bl_desc = null;
    this.bl_count = new Uint16Array(MAX_BITS + 1);
    this.heap = new Uint16Array(2 * L_CODES + 1);
    zero(this.heap);
    this.heap_len = 0;
    this.heap_max = 0;
    this.depth = new Uint16Array(2 * L_CODES + 1);
    zero(this.depth);
    this.sym_buf = 0;
    this.lit_bufsize = 0;
    this.sym_next = 0;
    this.sym_end = 0;
    this.opt_len = 0;
    this.static_len = 0;
    this.matches = 0;
    this.insert = 0;
    this.bi_buf = 0;
    this.bi_valid = 0;
  }
}/* =========================================================================
 * Check for a valid deflate stream state. Return 0 if ok, 1 if not.
 */
const deflateStateCheck = (strm: ZStreamDeflate | null): boolean => {
  if (!strm || strm.state === null) {
    return true;
  }
  const s = strm.state;
  if (s.strm !== strm ||
    (s.status !== INIT_STATE &&
      s.status !== GZIP_STATE &&
      s.status !== EXTRA_STATE &&
      s.status !== NAME_STATE &&
      s.status !== COMMENT_STATE &&
      s.status !== HCRC_STATE &&
      s.status !== BUSY_STATE &&
      s.status !== FINISH_STATE)) {
    return true;
  }
  return false;
};
const deflateResetKeep = (strm: ZStreamDeflate): number => {
  if (deflateStateCheck(strm) || strm.state === null) {
    return err(strm, Z_STREAM_ERROR);
  }
  strm.total_in = strm.total_out = 0;
  strm.data_type = Z_UNKNOWN;
  const s = strm.state;
  s.pending = 0;
  s.pending_out = 0;
  if (s.wrap < 0) {
    s.wrap = -s.wrap;
    /* was made negative by deflate(..., Z_FINISH); */
  }
  s.status =
    s.wrap === 2
      ? GZIP_STATE
      : //#endif
      s.wrap
        ? INIT_STATE
        : BUSY_STATE;
  strm.adler =
    s.wrap === 2
      ? 0 // crc32(0, Z_NULL, 0)
      : 1; // adler32(0, Z_NULL, 0)
  s.last_flush = -2;
  _tr_init(s);
  return Z_OK;
};
const deflateReset = (strm: ZStreamDeflate): number => {
  const ret = deflateResetKeep(strm);
  if (ret === Z_OK && strm.state) {
    lm_init(strm.state);
  }
  return ret;
};
const deflateSetHeader = (strm: ZStreamDeflate, head: GZheader) => {
  if (deflateStateCheck(strm) || strm.state === null || (strm.state && strm.state.wrap !== 2)) {
    return Z_STREAM_ERROR;
  }
  strm.state.gzhead = head;
  return Z_OK;
};
const deflateInit2 =(
  strm: ZStreamDeflate,
  level: number,
  method: number,
  windowBits: number,
  memLevel: number,
  strategy: number,
): number => {
  if (!strm) {
    return Z_STREAM_ERROR;
  }
  let wrap = 1;
  if (level === Z_DEFAULT_COMPRESSION) {
    level = 6;
  }
  if (windowBits < 0) {
    wrap = 0;
    windowBits = -windowBits;
  }
  else if (windowBits > 15) {
    wrap = 2; /* write gzip wrapper instead */
    windowBits -= 16;
  }
  if (memLevel < 1 ||
    memLevel > MAX_MEM_LEVEL ||
    method !== Z_DEFLATED ||
    windowBits < 8 ||
    windowBits > 15 ||
    level < 0 ||
    level > 9 ||
    strategy < 0 ||
    strategy > Z_FIXED ||
    (windowBits === 8 && wrap !== 1)) {
    return err(strm, Z_STREAM_ERROR);
  }
  if (windowBits === 8) {
    windowBits = 9;
  }
  const s = new DeflateState();
  strm.state = s;
  s.strm = strm;
  s.status = INIT_STATE; /* to pass state test in deflateReset() */
  s.wrap = wrap;
  s.gzhead = null;
  s.w_bits = windowBits;
  s.w_size = 1 << s.w_bits;
  s.w_mask = s.w_size - 1;
  s.hash_bits = memLevel + 7;
  s.hash_size = 1 << s.hash_bits;
  s.hash_mask = s.hash_size - 1;
  s.hash_shift = ~~((s.hash_bits + MIN_MATCH - 1) / MIN_MATCH);
  s.window = new Uint8Array(s.w_size * 2);
  s.head = new Uint16Array(s.hash_size);
  s.prev = new Uint16Array(s.w_size);
  s.lit_bufsize = 1 << (memLevel + 6); /* 16K elements by default */
  s.pending_buf_size = s.lit_bufsize * 4;
  s.pending_buf = new Uint8Array(s.pending_buf_size);
  s.sym_buf = s.lit_bufsize;
  s.sym_end = (s.lit_bufsize - 1) * 3;
  s.level = level;
  s.strategy = strategy;
  s.method = method;
  return deflateReset(strm);
};
/* ========================================================================= */
const deflate$1 = (strm: ZStreamDeflate, flush:number):number => {
  if (deflateStateCheck(strm) || flush > Z_BLOCK || flush < 0 || strm.state === null) {
    return strm ? err(strm, Z_STREAM_ERROR) : Z_STREAM_ERROR;
  }
  const s = strm.state;
  if ((strm.avail_in !== 0 && !strm.input) || (s.status === FINISH_STATE && flush !== Z_FINISH)) {
    return err(strm, strm.avail_out === 0 ? Z_BUF_ERROR : Z_STREAM_ERROR);
  }
  const old_flush = s.last_flush;
  s.last_flush = flush;
  if (s.pending !== 0) {
    flush_pending(strm);
    if (strm.avail_out === 0) {
      s.last_flush = -1;
      return Z_OK;
    }
    /* Make sure there is something to do and avoid duplicate consecutive
         * flushes. For repeated and useless calls with Z_FINISH, we keep
         * returning Z_STREAM_END instead of Z_BUF_ERROR.
         */
  }
  else if (strm.avail_in === 0 && rank(flush) <= rank(old_flush) && flush !== Z_FINISH) {
    return err(strm, Z_BUF_ERROR);
  }
  if (s.status === FINISH_STATE && strm.avail_in !== 0) {
    return err(strm, Z_BUF_ERROR);
  }
  if (s.status === INIT_STATE && s.wrap === 0) {
    s.status = BUSY_STATE;
  }
  if (s.status === INIT_STATE) {
    let header = (Z_DEFLATED + ((s.w_bits - 8) << 4)) << 8;
    let level_flags = -1;
    if (s.strategy >= Z_HUFFMAN_ONLY || s.level < 2) {
      level_flags = 0;
    }
    else if (s.level < 6) {
      level_flags = 1;
    }
    else if (s.level === 6) {
      level_flags = 2;
    }
    else {
      level_flags = 3;
    }
    header |= (level_flags << 6);
    if (s.strstart !== 0) {
      header |= PRESET_DICT;
    }
    header += 31 - (header % 31);
    putShortMSB(s, header);
    if (s.strstart !== 0) {
      putShortMSB(s, strm.adler >>> 16);
      putShortMSB(s, strm.adler & 0xffff);
    }
    strm.adler = 1; // adler32(0L, Z_NULL, 0);
    s.status = BUSY_STATE;
    flush_pending(strm);
    if (s.pending !== 0) {
      s.last_flush = -1;
      return Z_OK;
    }
  }
  if (s.status === GZIP_STATE) {
    strm.adler = 0; //crc32(0L, Z_NULL, 0);
    put_byte(s, 31);
    put_byte(s, 139);
    put_byte(s, 8);
    if (!s.gzhead) {
      put_byte(s, 0);
      put_byte(s, 0);
      put_byte(s, 0);
      put_byte(s, 0);
      put_byte(s, 0);
      put_byte(s, s.level === 9 ? 2 :
        (s.strategy >= Z_HUFFMAN_ONLY || s.level < 2 ?
          4 : 0));
      put_byte(s, OS_CODE);
      s.status = BUSY_STATE;
      flush_pending(strm);
      if (s.pending !== 0) {
        s.last_flush = -1;
        return Z_OK;
      }
    }
    else {
      put_byte(s, (s.gzhead.text ? 1 : 0) + (s.gzhead.hcrc ? 2 : 0) + (!s.gzhead.extra ? 0 : 4) + (!s.gzhead.name ? 0 : 8) + (!s.gzhead.comment ? 0 : 16));
      put_byte(s, (s.gzhead.time as number) & 0xff);
      put_byte(s, ((s.gzhead.time as number) >> 8) & 0xff);
      put_byte(s, ((s.gzhead.time as number) >> 16) & 0xff);
      put_byte(s, ((s.gzhead.time as number) >> 24) & 0xff);
      put_byte(s, s.level === 9 ? 2 :
        (s.strategy >= Z_HUFFMAN_ONLY || s.level < 2 ?
          4 : 0));
      put_byte(s, (s.gzhead.os as number) & 0xff);
      if (s.gzhead.extra && s.gzhead.extra.length) {
        put_byte(s, s.gzhead.extra.length & 0xff);
        put_byte(s, (s.gzhead.extra.length >> 8) & 0xff);
      }
      if (s.gzhead.hcrc) {
        strm.adler = crc32(strm.adler, s.pending_buf, s.pending, 0);
      }
      s.gzindex = 0;
      s.status = EXTRA_STATE;
    }
  }
  if (s.status === EXTRA_STATE && s.gzhead) {
    if (s.gzhead.extra /* != Z_NULL*/) {
      let beg = s.pending; /* start of bytes to update crc */
      let left = (s.gzhead.extra.length & 0xffff) - s.gzindex;
      while (s.pending + left > s.pending_buf_size) {
        let copy = s.pending_buf_size - s.pending;
        s.pending_buf.set((s.gzhead.extra as Uint8Array).subarray(s.gzindex, s.gzindex + copy), s.pending);
        s.pending = s.pending_buf_size;
        if (s.gzhead.hcrc && s.pending > beg) {
          strm.adler = crc32(strm.adler, s.pending_buf, s.pending - beg, beg);
        }
        s.gzindex += copy;
        flush_pending(strm);
        if (s.pending !== 0) {
          s.last_flush = -1;
          return Z_OK;
        }
        beg = 0;
        left -= copy;
      }
      let gzhead_extra = new Uint8Array(s.gzhead.extra);
      s.pending_buf.set(gzhead_extra.subarray(s.gzindex, s.gzindex + left), s.pending);
      s.pending += left;
      if (s.gzhead.hcrc && s.pending > beg) {
        strm.adler = crc32(strm.adler, s.pending_buf, s.pending - beg, beg);
      }
      s.gzindex = 0;
    }
    s.status = NAME_STATE;
  }
  if (s.status === NAME_STATE && s.gzhead) {
    if (s.gzhead.name /* != Z_NULL*/) {
      let beg = s.pending; /* start of bytes to update crc */
      let val:number;
      do {
        if (s.pending === s.pending_buf_size) {
          if (s.gzhead.hcrc && s.pending > beg) {
            strm.adler = crc32(strm.adler, s.pending_buf, s.pending - beg, beg);
          }
          flush_pending(strm);
          if (s.pending !== 0) {
            s.last_flush = -1;
            return Z_OK;
          }
          beg = 0;
        }
        if (s.gzindex < s.gzhead.name.length) {
          val = s.gzhead.name.charCodeAt(s.gzindex++) & 0xff;
        }
        else {
          val = 0;
        }
        put_byte(s, val);
      } while (val !== 0);
      if (s.gzhead.hcrc && s.pending > beg) {
        strm.adler = crc32(strm.adler, s.pending_buf, s.pending - beg, beg);
      }
      s.gzindex = 0;
    }
    s.status = COMMENT_STATE;
  }
  if (s.status === COMMENT_STATE && s.gzhead) {
    if (s.gzhead.comment /* != Z_NULL*/) {
      let beg = s.pending; /* start of bytes to update crc */
      let val:number;
      do {
        if (s.pending === s.pending_buf_size) {
          if (s.gzhead.hcrc && s.pending > beg) {
            strm.adler = crc32(strm.adler, s.pending_buf, s.pending - beg, beg);
          }
          flush_pending(strm);
          if (s.pending !== 0) {
            s.last_flush = -1;
            return Z_OK;
          }
          beg = 0;
        }
        if (s.gzindex < s.gzhead.comment.length) {
          val = s.gzhead.comment.charCodeAt(s.gzindex++) & 0xff;
        }
        else {
          val = 0;
        }
        put_byte(s, val);
      } while (val !== 0);
      if (s.gzhead.hcrc && s.pending > beg) {
        strm.adler = crc32(strm.adler, s.pending_buf, s.pending - beg, beg);
      }
      //---//
    }
    s.status = HCRC_STATE;
  }
  if (s.status === HCRC_STATE && s.gzhead) {
    if (s.gzhead.hcrc) {
      if (s.pending + 2 > s.pending_buf_size) {
        flush_pending(strm);
        if (s.pending !== 0) {
          s.last_flush = -1;
          return Z_OK;
        }
      }
      put_byte(s, strm.adler & 0xff);
      put_byte(s, (strm.adler >> 8) & 0xff);
      strm.adler = 0; //crc32(0L, Z_NULL, 0);
    }
    s.status = BUSY_STATE;
    flush_pending(strm);
    if (s.pending !== 0) {
      s.last_flush = -1;
      return Z_OK;
    }
  }
  if (strm.avail_in !== 0 || s.lookahead !== 0 || (flush !== Z_NO_FLUSH && s.status !== FINISH_STATE)) {
    let bstate:number =s.level === 0 ? deflate_stored(s, flush) :
      s.strategy === Z_HUFFMAN_ONLY ? deflate_huff(s, flush) :
        s.strategy === Z_RLE ? deflate_rle(s, flush) :
        configuration_table[s.level].func(s, flush);
    if (bstate === BS_FINISH_STARTED || bstate === BS_FINISH_DONE) {
      s.status = FINISH_STATE;
    }
    if (bstate === BS_NEED_MORE || bstate === BS_FINISH_STARTED) {
      if (strm.avail_out === 0) {
        s.last_flush = -1;
        /* avoid BUF_ERROR next call, see above */
      }
      return Z_OK;
      /* If flush != Z_NO_FLUSH && avail_out == 0, the next call
             * of deflate should use the same flush parameter to make sure
             * that the flush is complete. So we don't have to output an
             * empty block here, this will be done at next call. This also
             * ensures that for a very small output buffer, we emit at most
             * one empty block.
             */
    }
    if (bstate === BS_BLOCK_DONE) {
      if (flush === Z_PARTIAL_FLUSH) {
        _tr_align(s);
      }
      else if (flush !== Z_BLOCK) {
        _tr_stored_block(s, 0, 0, false);
        if (flush === Z_FULL_FLUSH) {
          /*** CLEAR_HASH(s); ***/ zero(s.head); // Fill with NIL (= 0);
          if (s.lookahead === 0) {
            s.strstart = 0;
            s.block_start = 0;
            s.insert = 0;
          }
        }
      }
      flush_pending(strm);
      if (strm.avail_out === 0) {
        s.last_flush = -1; /* avoid BUF_ERROR at next call, see above */
        return Z_OK;
      }
    }
  }
  if (flush !== Z_FINISH) {
    return Z_OK;
  }
  if (s.wrap <= 0) {
    return Z_STREAM_END;
  }
  if (s.wrap === 2) {
    put_byte(s, strm.adler & 0xff);
    put_byte(s, (strm.adler >> 8) & 0xff);
    put_byte(s, (strm.adler >> 16) & 0xff);
    put_byte(s, (strm.adler >> 24) & 0xff);
    put_byte(s, strm.total_in & 0xff);
    put_byte(s, (strm.total_in >> 8) & 0xff);
    put_byte(s, (strm.total_in >> 16) & 0xff);
    put_byte(s, (strm.total_in >> 24) & 0xff);
  }
  else {
    putShortMSB(s, strm.adler >>> 16);
    putShortMSB(s, strm.adler & 0xffff);
  }
  flush_pending(strm);
  if (s.wrap > 0) {
    s.wrap = -(s.wrap);
  }
  return s.pending !== 0 ? Z_OK : Z_STREAM_END;
};
const deflateEnd = (strm: ZStreamDeflate): number => {
  if (deflateStateCheck(strm) || strm.state === null) {
    return Z_STREAM_ERROR;
  }
  const status = strm.state.status;
  strm.state = null;
  return status === BUSY_STATE ? err(strm, Z_DATA_ERROR) : Z_OK;
};
/* =========================================================================
 * Initializes the compression dictionary from the given byte
 * sequence without producing any compressed output.
 */
const deflateSetDictionary = (strm: ZStreamDeflate, dictionary: Uint8Array): number => {
  const dictLength = dictionary.length;
  if (deflateStateCheck(strm) || !strm.state) {
    return Z_STREAM_ERROR;
  }
  const s = strm.state;
  const wrap = s.wrap;
  if (wrap === 2 || (wrap === 1 && s.status !== INIT_STATE) || s.lookahead) {
    return Z_STREAM_ERROR;
  }
  if (wrap === 1) {
    strm.adler = adler32(strm.adler, dictionary, dictLength, 0);
  }
  s.wrap = 0; // Skip Adler-32 in read_buf
  const w_size = s.w_size;
  if (dictLength >= w_size) {
    if (wrap === 0) {
      // Reset hash state
      zero(s.head);
      s.strstart = 0;
      s.block_start = 0;
      s.insert = 0;
    }
    // Use the last w_size bytes of the dictionary
    const startPos = dictLength - w_size;
    if (dictionary.byteLength >= startPos + w_size) {
      dictionary = dictionary.subarray(startPos, startPos + w_size);
    }
    else {
      // Handle cases where subarray would exceed bounds (though Uint8Array.subarray auto-clamps)
      const tmpDict = new Uint8Array(w_size);
      tmpDict.set(dictionary.subarray(startPos), 0);
      dictionary = tmpDict;
    }
  }
  // Cache variables to minimize property accesses
  const strmAvailIn = strm.avail_in;
  const strmNextIn = strm.next_in;
  const strmInput = strm.input;
  // Temporarily swap input source
  strm.avail_in = dictLength;
  strm.next_in = 0;
  strm.input = dictionary;
  // Inline hash function parameters
  const HASH_SHIFT = s.hash_shift;
  const HASH_MASK = s.hash_mask;
  const MIN_MATCH_MINUS_1 = MIN_MATCH - 1;
  const w_mask = s.w_mask;
  fill_window(s);
  while (s.lookahead >= MIN_MATCH) {
    let str = s.strstart;
    let n = s.lookahead - MIN_MATCH_MINUS_1;
    const window = s.window;
    const prev = s.prev;
    const head = s.head;
    let ins_h = s.ins_h;
    // Optimized hash chain loop
    while (n--) {
      ins_h = ((ins_h << HASH_SHIFT) ^ window[str + MIN_MATCH_MINUS_1]) & HASH_MASK;
      prev[str & w_mask] = head[ins_h];
      head[ins_h] = str;
      str++;
    }
    s.ins_h = ins_h;
    s.strstart = str;
    s.lookahead = MIN_MATCH_MINUS_1;
    fill_window(s);
  }
  // Restore stream state
  s.strstart += s.lookahead;
  s.block_start = s.strstart;
  s.insert = s.lookahead;
  s.lookahead = 0;
  s.match_length = s.prev_length = MIN_MATCH_MINUS_1;
  s.match_available = false;
  strm.next_in = strmNextIn;
  strm.input = strmInput;
  strm.avail_in = strmAvailIn;
  s.wrap = wrap;
  return Z_OK;
};

const flattenChunks = (chunks: Uint8Array[]): Uint8Array =>  {
  const totalLength = chunks.reduce((acc, chunk) => acc + chunk.length, 0);
  const result = new Uint8Array(totalLength);
  let pos = 0;
  for (const chunk of chunks) {
    result.set(chunk, pos);
    pos += chunk.length;
  }
  return result;
};

// import { util } from '@kit.ArkTS';
// String encode/decode helpers
// Quick check if we can use fast array to bin string conversion
//
// - apply(Array) can fail on Android 2.2
// - apply(Uint8Array) can fail on iOS 5.1 Safari
//
let STR_APPLY_UIA_OK = true;
try {
  const arr = Array.from(new Uint8Array(1));
  String.fromCharCode(...arr);
}
catch (__) {
  STR_APPLY_UIA_OK = false;
}
// Table with utf8 lengths (calculated by first byte of sequence)
// Note, that 5 & 6-byte values and some 4-byte values can not be represented in JS,
// because max possible codepoint is 0x10ffff
const _utf8len = new Uint8Array(256);
for (let q = 0; q < 256; q++) {
  _utf8len[q] = (q >= 252 ? 6 : q >= 248 ? 5 : q >= 240 ? 4 : q >= 224 ? 3 : q >= 192 ? 2 : 1);
}
_utf8len[254] = _utf8len[254] = 1; // Invalid sequence start
// convert string to array (typed, when possible)
const string2buf = (str: string): Uint8Array => {
  let textEncoder = new util.TextEncoder();
  if (textEncoder) {
    return textEncoder.encodeInto(str);
  }
  let buf: Uint8Array,
    c: number,
    c2: number,
    m_pos: number,
    i: number,
    str_len: number = str.length,
    buf_len: number = 0;  // count binary size
  for (m_pos = 0; m_pos < str_len; m_pos++) {
    c = str.charCodeAt(m_pos);
    if ((c & 0xfc00) === 0xd800 && (m_pos + 1 < str_len)) {
      c2 = str.charCodeAt(m_pos + 1);
      if ((c2 & 0xfc00) === 0xdc00) {
        c = 0x10000 + ((c - 0xd800) << 10) + (c2 - 0xdc00);
        m_pos++;
      }
    }
    buf_len += c < 0x80 ? 1 : c < 0x800 ? 2 : c < 0x10000 ? 3 : 4;
  }
  // allocate buffer
  buf = new Uint8Array(buf_len);
  // convert
  for (i = 0, m_pos = 0; i < buf_len; m_pos++) {
    c = str.charCodeAt(m_pos);
    if ((c & 0xfc00) === 0xd800 && (m_pos + 1 < str_len)) {
      c2 = str.charCodeAt(m_pos + 1);
      if ((c2 & 0xfc00) === 0xdc00) {
        c = 0x10000 + ((c - 0xd800) << 10) + (c2 - 0xdc00);
        m_pos++;
      }
    }
    if (c < 0x80) {
      /* one byte */
      buf[i++] = c;
    }
    else if (c < 0x800) {
      /* two bytes */
      buf[i++] = 0xC0 | (c >>> 6);
      buf[i++] = 0x80 | (c & 0x3f);
    }
    else if (c < 0x10000) {
      /* three bytes */
      buf[i++] = 0xE0 | (c >>> 12);
      buf[i++] = 0x80 | (c >>> 6 & 0x3f);
      buf[i++] = 0x80 | (c & 0x3f);
    }
    else {
      /* four bytes */
      buf[i++] = 0xf0 | (c >>> 18);
      buf[i++] = 0x80 | (c >>> 12 & 0x3f);
      buf[i++] = 0x80 | (c >>> 6 & 0x3f);
      buf[i++] = 0x80 | (c & 0x3f);
    }
  }
  return buf;
};
// Helper
const buf2binstring= (buf: Uint16Array, len: number): string => {
  if (len < 65534 && STR_APPLY_UIA_OK) {
    const subBuf = buf.length === len ? buf : buf.subarray(0, len);
    return String.fromCharCode(...subBuf);
  }
  else {
    const chars:string[] = new Array(len);
    for (let i = 0; i < len; i++) {
      chars[i] = String.fromCharCode(buf[i]);
    }
    return chars.join('');
  }
};
const buf2string = (buf:Uint8Array, max:number):string => {
  const len = max || buf.length;
  let textDecoder = new util.TextDecoder();
  if (textDecoder) {
    return textDecoder.decodeToString(buf.subarray(0, max));
  }
  let i:number, out:number;
  // Reserve max possible length (2 words per char)
  // NB: by unknown reasons, Array is significantly faster for
  //     String.fromCharCode.apply than Uint16Array.
  const utf16buf = new Uint16Array(len * 2);
  for (out = 0, i = 0; i < len;) {
    let c = buf[i++];
    // quick process ascii
    if (c < 0x80) {
      utf16buf[out++] = c;
      continue;
    }
    let c_len = _utf8len[c];
    // skip 5 & 6 byte codes
    if (c_len > 4) {
      utf16buf[out++] = 0xfffd;
      i += c_len - 1;
      continue;
    }
    // apply mask on first byte
    c &= c_len === 2 ? 0x1f : c_len === 3 ? 0x0f : 0x07;
    // join the rest
    while (c_len > 1 && i < len) {
      c = (c << 6) | (buf[i++] & 0x3f);
      c_len--;
    }
    // terminated by end of string?
    if (c_len > 1) {
      utf16buf[out++] = 0xfffd;
      continue;
    }
    if (c < 0x10000) {
      utf16buf[out++] = c;
    }
    else {
      c -= 0x10000;
      utf16buf[out++] = 0xd800 | ((c >> 10) & 0x3ff);
      utf16buf[out++] = 0xdc00 | (c & 0x3ff);
    }
  }
  return buf2binstring(utf16buf, out);
};
export const utf8border = (buf: Uint8Array, max?: number): number => {
  const length = buf.length;
  max = max !== undefined ? Math.min(max, length) : length;
  if (max <= 0)
    return 0;
  let pos = max - 1;
  while (pos >= 0 && (buf[pos] & 0xC0) === 0x80) {
    pos--;
  }
  if (pos <= 0)
    return max;
  const charLen = _utf8len[buf[pos]];
  return (pos + charLen > max) ? pos : max;
};

/* ===========================================================================*/
enum constants {
  // FlushValues
  Z_NO_FLUSH = 0,
  Z_PARTIAL_FLUSH = 1,
  Z_SYNC_FLUSH = 2,
  Z_FULL_FLUSH = 3,
  Z_FINISH = 4,
  Z_BLOCK = 5,
  Z_TREES = 6,
  // StrategyValues
  Z_FILTERED = 1,
  Z_HUFFMAN_ONLY = 2,
  Z_RLE = 3,
  Z_FIXED = 4,
  Z_DEFAULT_STRATEGY = 0,
  // ReturnCodes
  Z_OK = 0,
  Z_STREAM_END = 1,
  Z_NEED_DICT = 2,
  Z_ERRNO = -1,
  Z_STREAM_ERROR = -2,
  Z_DATA_ERROR = -3,
  Z_BUF_ERROR = -5,
}

type StrategyValues =
  | constants.Z_FILTERED
  | constants.Z_HUFFMAN_ONLY
  | constants.Z_RLE
  | constants.Z_FIXED
  | constants.Z_DEFAULT_STRATEGY;

interface DeflateOptions {
  level?: -1 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 ;
  windowBits?: number;
  memLevel?: number ;
  strategy?: StrategyValues ;
  dictionary?: Uint8Array ;
  raw?: boolean ;
  chunkSize?: number ;
  gzip?: boolean ;
  header?: GZheader ;
  method?: number;
}
function deflate(input: Uint8Array | ArrayBuffer|string, options?: DeflateOptions): Uint8Array {
  const deflator = new Deflate(options);
  deflator.push(input, true);
  if (deflator.err) {
    throw new Error(deflator.msg || record_Messages_1[deflator.err]);
  }
  return deflator.result;
}
function deflateRaw(input: Uint8Array | ArrayBuffer|string, options?: DeflateOptions): Uint8Array {
  const opts = options || {};
  opts.raw = true;
  return deflate(input, opts);
}
function gzip(input: Uint8Array | ArrayBuffer | string, options?: DeflateOptions): Uint8Array {
  options = options || {};
  options.gzip = true;
  return deflate(input, options);
}

interface DeflateOptionsWithoutUndefined {
  level: -1 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 ;
  windowBits: number;
  memLevel: number ;
  strategy: StrategyValues ;
  dictionary?: Uint8Array ;
  raw?: boolean ;
  chunkSize: number ;
  gzip?: boolean ;
  header?: GZheader ;
  method: number;
}


class Deflate {
  options: DeflateOptionsWithoutUndefined;
  err: number;
  msg: string;
  ended: boolean;
  chunks: Uint8Array[];
  strm: ZStreamDeflate;
  _dict_set: boolean = false;
  result: Uint8Array = new Uint8Array;

  constructor(options?: DeflateOptions) {
    this.options = {
      level: options?.level ?? Z_DEFAULT_COMPRESSION,
      method: options?.method ?? Z_DEFLATED,
      chunkSize: options?.chunkSize ??1024 * 64,
      windowBits: options?.windowBits ?? 15,
      memLevel: options?.memLevel ?? 8,
      strategy: options?.strategy ?? Z_DEFAULT_STRATEGY,
      raw: options?.raw,
      gzip: options?.gzip,
      header: options?.header,
      dictionary: options?.dictionary
    };
    let opt = this.options;
    if (opt.raw && (opt.windowBits > 0)) {
      opt.windowBits = -opt.windowBits;
    }
    else if (opt.gzip && (opt.windowBits > 0) && (opt.windowBits < 16)) {
      opt.windowBits += 16;
    }
    this.err = 0; // error code, if happens (0 = Z_OK)
    this.msg = ''; // error message
    this.ended = false; // used to avoid multiple onEnd() calls
    this.chunks = []; // chunks of compressed data
    this.strm = new ZStreamDeflate();
    this.strm.avail_out = 0;
    let status = deflateInit2(this.strm, opt.level, opt.method, opt.windowBits, opt.memLevel, opt.strategy);
    if (status !== Z_OK) {
      throw new Error(record_Messages_1[status]);
    }
    if (opt.header) {
      deflateSetHeader(this.strm, opt.header);
    }
    if (opt.dictionary) {
      let dict: Uint8Array;
      if (typeof opt.dictionary === 'string') {
        dict = string2buf(opt.dictionary);
      }
      else if (opt.dictionary instanceof ArrayBuffer) {
        dict = new Uint8Array(opt.dictionary);
      }
      else {
        dict = opt.dictionary;
      }
      status = deflateSetDictionary(this.strm, dict);
      if (status !== Z_OK) {
        throw new Error(record_Messages_1[status]);
      }
      this._dict_set = true;
    }
  }
  push(data: ArrayBuffer | Uint8Array | string, flush_mode?: number | boolean): boolean {
    const strm = this.strm;
    const chunkSize = this.options.chunkSize;
    let status: number;
    let _flush_mode: number;
    if (this.ended) {
      return false;
    }
    if (flush_mode === ~~Number(flush_mode)) {
      _flush_mode = flush_mode;
    }
    else {
      _flush_mode = flush_mode === true ? Z_FINISH : Z_NO_FLUSH;
    }
    if (typeof data === 'string') {
      strm.input = string2buf(data);
    }
    else if (data instanceof ArrayBuffer) {
      strm.input = new Uint8Array(data);
    }
    else {
      strm.input = data;
    }
    strm.next_in = 0;
    strm.avail_in = strm.input.length;
    for (;;) {
      if (strm.avail_out === 0) {
        strm.output = new Uint8Array((chunkSize));
        strm.next_out = 0;
        strm.avail_out = chunkSize;
      }
      if ((_flush_mode === Z_SYNC_FLUSH || _flush_mode === Z_FULL_FLUSH) && strm.avail_out <= 6) {
        this.onData(strm.output.subarray(0, strm.next_out));
        strm.avail_out = 0;
        continue;
      }
      status = deflate$1(strm, _flush_mode);
      if (status === Z_STREAM_END) {
        if (strm.next_out > 0) {
          this.onData(strm.output.subarray(0, strm.next_out));
        }
        status = deflateEnd(this.strm);
        this.onEnd(status);
        this.ended = true;
        return status === Z_OK;
      }
      if (strm.avail_out === 0) {
        this.onData(strm.output);
        continue;
      }
      if (_flush_mode > 0 && strm.next_out > 0) {
        this.onData(strm.output.subarray(0, strm.next_out));
        strm.avail_out = 0;
        continue;
      }
      if (strm.avail_in === 0)
        break;
    }
    return true;
  }
  onData(chunk: Uint8Array) {
    this.chunks.push(chunk);
  }
  onEnd(status: number) {
    if (status === Z_OK) {
      this.result = flattenChunks(this.chunks);
    }
    this.chunks = [];
    this.err = status;
    this.msg = this.strm.msg;
  }
}

// See state defs from inflate.js
const BAD$1 = 16209; /* got a data error -- remain here until reset */
const TYPE$1 = 16191; /* i: waiting for type bits, including last-flag bit */
const inflate_fast = (strm:ZStreamInflate, start:number) => {
  let _in:number; /* local strm.input */
  let last:number; /* have enough input while in < last */
  let _out:number; /* local strm.output */
  let beg: number; /* inflate()'s initial strm.output */
  let end: number; /* while out < end, enough space available */
  //#ifdef INFLATE_STRICT
  let dmax: number; /* maximum distance from zlib header */
  //#endif
  let wsize:number; /* window size or zero if not using window */
  let whave: number; /* valid bytes in the window */
  let wnext: number; /* window write index */
  // Use `s_window` instead `window`, avoid conflict with instrumentation tools
  let s_window:Uint8Array; /* allocated sliding window, if wsize != 0 */
  let hold:number; /* local strm.hold */
  let bits:number; /* local strm.bits */
  let lcode:Int32Array ; /* local strm.lencode */
  let dcode: Int32Array; /* local strm.distcode */
  let lmask:number; /* mask for first level of length codes */
  let dmask:number; /* mask for first level of distance codes */
  let here:number; /* retrieved table entry */
  let op:number; /* code bits, operation, extra bits, or */
  /*  window position, window bytes to copy */
  let len:number; /* match length, unused bytes */
  let dist:number; /* match distance */
  let from:number; /* where to copy match from */
  let from_source:Uint8Array;
  let input:Uint8Array, output:Uint8Array; // JS specific, because we have no pointers
  /* copy state to local variables */
  const state = strm.state as InflateState;
  //here = state.here;
  _in = strm.next_in;
  input = strm.input;
  last = _in + (strm.avail_in - 5);
  _out = strm.next_out;
  output = strm.output;
  beg = _out - (start - strm.avail_out);
  end = _out + (strm.avail_out - 257);
  //#ifdef INFLATE_STRICT
  dmax = state.dmax;
  //#endif
  wsize = state.wsize;
  whave = state.whave;
  wnext = state.wnext;
  s_window = state.window as Uint8Array;
  hold = state.hold;
  bits = state.bits;
  lcode = state.lencode;
  dcode = state.distcode;
  lmask = (1 << state.lenbits) - 1;
  dmask = (1 << state.distbits) - 1;
  /* decode literals and length/distances until end-of-block or not enough
         input data or output space */
  top: do {
    if (bits < 15) {
      hold += input[_in++] << bits;
      bits += 8;
      hold += input[_in++] << bits;
      bits += 8;
    }
    here = lcode[hold & lmask];
    dolen: for (;;) { // Goto emulation
      op = here >>> 24 /*here.bits*/;
      hold >>>= op;
      bits -= op;
      op = (here >>> 16) & 0xff /*here.op*/;
      if (op === 0) { /* literal */
        //Tracevv((stderr, here.val >= 0x20 && here.val < 0x7f ?
        //        "inflate:         literal '%c'\n" :
        //        "inflate:         literal 0x%02x\n", here.val));
        output[_out++] = here & 0xffff /*here.val*/;
      }
      else if (op & 16) { /* length base */
        len = here & 0xffff /*here.val*/;
        op &= 15; /* number of extra bits */
        if (op) {
          if (bits < op) {
            hold += input[_in++] << bits;
            bits += 8;
          }
          len += hold & ((1 << op) - 1);
          hold >>>= op;
          bits -= op;
        }
        //Tracevv((stderr, "inflate:         length %u\n", len));
        if (bits < 15) {
          hold += input[_in++] << bits;
          bits += 8;
          hold += input[_in++] << bits;
          bits += 8;
        }
        here = dcode[hold & dmask];
        dodist: for (;;) { // goto emulation
          op = here >>> 24 /*here.bits*/;
          hold >>>= op;
          bits -= op;
          op = (here >>> 16) & 0xff /*here.op*/;
          if (op & 16) { /* distance base */
            dist = here & 0xffff /*here.val*/;
            op &= 15; /* number of extra bits */
            if (bits < op) {
              hold += input[_in++] << bits;
              bits += 8;
              if (bits < op) {
                hold += input[_in++] << bits;
                bits += 8;
              }
            }
            dist += hold & ((1 << op) - 1);
            //#ifdef INFLATE_STRICT
            if (dist > dmax) {
              strm.msg = 'invalid distance too far back';
              state.mode = BAD$1;
              break top;
            }
            //#endif
            hold >>>= op;
            bits -= op;
            //Tracevv((stderr, "inflate:         distance %u\n", dist));
            op = _out - beg; /* max distance in output */
            if (dist > op) { /* see if copy from window */
              op = dist - op; /* distance back in window */
              if (op > whave) {
                if (state.sane) {
                  strm.msg = 'invalid distance too far back';
                  state.mode = BAD$1;
                  break top;
                }
                // (!) This block is disabled in zlib defaults,
                // don't enable it for binary compatibility
                //#ifdef INFLATE_ALLOW_INVALID_DISTANCE_TOOFAR_ARRR
                //                if (len <= op - whave) {
                //                  do {
                //                    output[_out++] = 0;
                //                  } while (--len);
                //                  continue top;
                //                }
                //                len -= op - whave;
                //                do {
                //                  output[_out++] = 0;
                //                } while (--op > whave);
                //                if (op === 0) {
                //                  from = _out - dist;
                //                  do {
                //                    output[_out++] = output[from++];
                //                  } while (--len);
                //                  continue top;
                //                }
                //#endif
              }
              from = 0; // window index
              from_source = s_window;
              if (wnext === 0) { /* very common case */
                from += wsize - op;
                if (op < len) { /* some from window */
                  len -= op;
                  do {
                    output[_out++] = s_window[from++];
                  } while (--op);
                  from = _out - dist; /* rest from output */
                  from_source = output;
                }
              }
              else if (wnext < op) { /* wrap around window */
                from += wsize + wnext - op;
                op -= wnext;
                if (op < len) { /* some from end of window */
                  len -= op;
                  do {
                    output[_out++] = s_window[from++];
                  } while (--op);
                  from = 0;
                  if (wnext < len) { /* some from start of window */
                    op = wnext;
                    len -= op;
                    do {
                      output[_out++] = s_window[from++];
                    } while (--op);
                    from = _out - dist; /* rest from output */
                    from_source = output;
                  }
                }
              }
              else { /* contiguous in window */
                from += wnext - op;
                if (op < len) { /* some from window */
                  len -= op;
                  do {
                    output[_out++] = s_window[from++];
                  } while (--op);
                  from = _out - dist; /* rest from output */
                  from_source = output;
                }
              }
              while (len > 2) {
                output[_out++] = from_source[from++];
                output[_out++] = from_source[from++];
                output[_out++] = from_source[from++];
                len -= 3;
              }
              if (len) {
                output[_out++] = from_source[from++];
                if (len > 1) {
                  output[_out++] = from_source[from++];
                }
              }
            }
            else {
              from = _out - dist; /* copy direct from output */
              do { /* minimum length is three */
                output[_out++] = output[from++];
                output[_out++] = output[from++];
                output[_out++] = output[from++];
                len -= 3;
              } while (len > 2);
              if (len) {
                output[_out++] = output[from++];
                if (len > 1) {
                  output[_out++] = output[from++];
                }
              }
            }
          }
          else if ((op & 64) === 0) { /* 2nd level distance code */
            here = dcode[(here & 0xffff) /*here.val*/ + (hold & ((1 << op) - 1))];
            continue dodist;
          }
          else {
            strm.msg = 'invalid distance code';
            state.mode = BAD$1;
            break top;
          }
          break; // need to emulate goto via "continue"
        }
      }
      else if ((op & 64) === 0) { /* 2nd level length code */
        here = lcode[(here & 0xffff) /*here.val*/ + (hold & ((1 << op) - 1))];
        continue dolen;
      }
      else if (op & 32) { /* end-of-block */
        //Tracevv((stderr, "inflate:         end of block\n"));
        state.mode = TYPE$1;
        break top;
      }
      else {
        strm.msg = 'invalid literal/length code';
        state.mode = BAD$1;
        break top;
      }
      break; // need to emulate goto via "continue"
    }
  } while (_in < last && _out < end);
  /* return unused bytes (on entry, bits < 8, so in won't go too far back) */
  len = bits >> 3;
  _in -= len;
  bits -= len << 3;
  hold &= (1 << bits) - 1;
  /* update state and return */
  strm.next_in = _in;
  strm.next_out = _out;
  strm.avail_in = (_in < last ? 5 + (last - _in) : 5 - (_in - last));
  strm.avail_out = (_out < end ? 257 + (end - _out) : 257 - (_out - end));
  state.hold = hold;
  state.bits = bits;
  return;
};

// (C) 1995-2013 Jean-loup Gailly and Mark Adler
// (C) 2014-2017 Vitaly Puzrin and Andrey Tupitsin
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//   claim that you wrote the original software. If you use this software
//   in a product, an acknowledgment in the product documentation would be
//   appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//   misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.
const MAXBITS = 15;
const ENOUGH_LENS$1 = 852;
const ENOUGH_DISTS$1 = 592;
//const ENOUGH = (ENOUGH_LENS+ENOUGH_DISTS);
const CODES$1 = 0;
const LENS$1 = 1;
const DISTS$1 = 2;
const lbase = new Uint16Array([
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
  35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258, 0, 0
]);
const lext = new Uint8Array([
  16, 16, 16, 16, 16, 16, 16, 16, 17, 17, 17, 17, 18, 18, 18, 18,
  19, 19, 19, 19, 20, 20, 20, 20, 21, 21, 21, 21, 16, 72, 78
]);
const dbase = new Uint16Array([
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
  257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
  8193, 12289, 16385, 24577, 0, 0
]);
const dext = new Uint8Array([
  16, 16, 16, 16, 17, 17, 18, 18, 19, 19, 20, 20, 21, 21, 22, 22,
  23, 23, 24, 24, 25, 25, 26, 26, 27, 27,
  28, 28, 29, 29, 64, 64
]);
interface GeneratedTypeLiteralInterface_Inftrees1 {
  bits: number;
}
const inflate_table = (
  type: number,
  lens: Uint16Array,
  lens_index: number,
  codes: number,
  table: Int32Array,
  table_index: number,
  work: Uint16Array,
  opts: GeneratedTypeLiteralInterface_Inftrees1,
): number => {
  const bits = opts.bits;
  let len = 0;
  let sym = 0;
  let min = 0, max = 0;
  let root = 0;
  let curr = 0;
  let drop = 0;
  let left = 0;
  let used = 0;
  let huff = 0;
  let incr: number;
  let fill: number;
  let low: number;
  let mask: number;
  let next: number;
  let base: Uint16Array | null = null;
  let match: number;
  const count = new Uint16Array(MAXBITS + 1);
  const offs = new Uint16Array(MAXBITS + 1);
  let extra: Uint16Array | null = null;
  let here_bits: number, here_op: number, here_val: number;
  for (len = 0; len <= MAXBITS; len++) {
    count[len] = 0;
  }
  for (sym = 0; sym < codes; sym++) {
    count[lens[lens_index + sym]]++;
  }
  root = bits;
  for (max = MAXBITS; max >= 1; max--) {
    if (count[max] !== 0) {
      break;
    }
  }
  if (root > max) {
    root = max;
  }
  if (max === 0) {
    table[table_index++] = (1 << 24) | (64 << 16) | 0;
    table[table_index++] = (1 << 24) | (64 << 16) | 0;
    opts.bits = 1;
    return 0;
  }
  for (min = 1; min < max; min++) {
    if (count[min] !== 0) {
      break;
    }
  }
  if (root < min) {
    root = min;
  }
  left = 1;
  for (len = 1; len <= MAXBITS; len++) {
    left <<= 1;
    left -= count[len];
    if (left < 0) {
      return -1;
    }
  }
  if (left > 0 && (type === CODES$1 || max !== 1)) {
    return -1;
  }
  offs[1] = 0;
  for (len = 1; len < MAXBITS; len++) {
    offs[len + 1] = offs[len] + count[len];
  }
  for (sym = 0; sym < codes; sym++) {
    if (lens[lens_index + sym] !== 0) {
      work[offs[lens[lens_index + sym]]++] = sym;
    }
  }
  if (type === CODES$1) {
    base = extra = work; /* dummy value--not used */
    match = 20;
  }
  else if (type === LENS$1) {
    base = lbase;
    extra = new Uint16Array(lext);
    match = 257;
  }
  else {
    base = dbase;
    extra = new Uint16Array(dext);
    match = 0;
  }
  huff = 0;
  sym = 0;
  len = min;
  next = table_index;
  curr = root;
  drop = 0;
  low = -1;
  used = 1 << root;
  mask = used - 1;
  if ((type === LENS$1 && used > ENOUGH_LENS$1) || (type === DISTS$1 && used > ENOUGH_DISTS$1)) {
    return 1;
  }
  for (;;) {
    here_bits = len - drop;
    if (work[sym] + 1 < match) {
      here_op = 0;
      here_val = work[sym];
    }
    else if (work[sym] >= match && extra && base) {
      here_op = extra[work[sym] - match];
      here_val = base[work[sym] - match];
    }
    else {
      here_op = 32 + 64;
      here_val = 0;
    }
    incr = 1 << (len - drop);
    fill = 1 << curr;
    min = fill;
    do {
      fill -= incr;
      table[next + (huff >> drop) + fill] = (here_bits << 24) | (here_op << 16) | here_val | 0;
    } while (fill !== 0);
    incr = 1 << (len - 1);
    while (huff & incr) {
      incr >>= 1;
    }
    if (incr !== 0) {
      huff &= incr - 1;
      huff += incr;
    }
    else {
      huff = 0;
    }
    sym++;
    if (--count[len] === 0) {
      if (len === max) {
        break;
      }
      len = lens[lens_index + work[sym]];
    }
    if (len > root && (huff & mask) !== low) {
      if (drop === 0) {
        drop = root;
      }
      next += min;
      curr = len - drop;
      left = 1 << curr;
      while (curr + drop < max) {
        left -= count[curr + drop];
        if (left <= 0) {
          break;
        }
        curr++;
        left <<= 1;
      }
      used += 1 << curr;
      if ((type === LENS$1 && used > ENOUGH_LENS$1) || (type === DISTS$1 && used > ENOUGH_DISTS$1)) {
        return 1;
      }
      low = huff & mask;
      table[low] = (root << 24) | (curr << 16) | (next - table_index) | 0;
    }
  }
  if (huff !== 0) {
    table[next + huff] = ((len - drop) << 24) | (64 << 16) | 0;
  }
  opts.bits = root;
  return 0;
};

const CODES = 0;
const LENS = 1;
const DISTS = 2;
/* STATES ====================================================================*/
/* ===========================================================================*/
const HEAD = 16180; /* i: waiting for magic header */
const FLAGS = 16181; /* i: waiting for method and flags (gzip) */
const TIME = 16182; /* i: waiting for modification time (gzip) */
const OS = 16183; /* i: waiting for extra flags and operating system (gzip) */
const EXLEN = 16184; /* i: waiting for extra length (gzip) */
const EXTRA = 16185; /* i: waiting for extra bytes (gzip) */
const NAME = 16186; /* i: waiting for end of file name (gzip) */
const COMMENT = 16187; /* i: waiting for end of comment (gzip) */
const HCRC = 16188; /* i: waiting for header crc (gzip) */
const DICTID = 16189; /* i: waiting for dictionary check value */
const DICT = 16190; /* waiting for inflateSetDictionary() call */
const TYPE = 16191; /* i: waiting for type bits, including last-flag bit */
const TYPEDO = 16192; /* i: same, but skip check to exit inflate on new block */
const STORED = 16193; /* i: waiting for stored size (length and complement) */
const COPY_ = 16194; /* i/o: same as COPY below, but only first time in */
const COPY = 16195; /* i/o: waiting for input or output to copy stored block */
const TABLE = 16196; /* i: waiting for dynamic block table lengths */
const LENLENS = 16197; /* i: waiting for code length code lengths */
const CODELENS = 16198; /* i: waiting for length/lit and distance code lengths */
const LEN_ = 16199; /* i: same as LEN below, but only first time in */
const LEN = 16200; /* i: waiting for length/lit/eob code */
const LENEXT = 16201; /* i: waiting for length extra bits */
const DIST = 16202; /* i: waiting for distance code */
const DISTEXT = 16203; /* i: waiting for distance extra bits */
const MATCH = 16204; /* o: waiting for output space to copy string */
const LIT = 16205; /* o: waiting for output space to write literal */
const CHECK = 16206; /* i: waiting for 32-bit check value */
const LENGTH = 16207; /* i: waiting for 32-bit length (gzip) */
const DONE = 16208; /* finished check, done -- remain here until reset */
const BAD = 16209; /* got a data error -- remain here until reset */
const MEM = 16210; /* got an inflate() memory error -- remain here until reset */
const SYNC = 16211; /* looking for synchronization bytes to restart inflate() */
/* looking for synchronization bytes to restart inflate() */
/* ===========================================================================*/
const ENOUGH_LENS = 852;
const ENOUGH_DISTS = 592;
const zswap32 = (q: number): number => {
  return (((q >>> 24) & 0xff) +
    ((q >>> 8) & 0xff00) +
    ((q & 0xff00) << 8) +
    ((q & 0xff) << 24));
};
class InflateState {
  strm: ZStreamInflate;
  mode: number;
  last: boolean;
  wrap: number;
  havedict: boolean;
  flags: number;
  dmax: number;
  check: number;
  total: number;
  head: GZheader | null;
  wbits: number;
  wsize: number;
  whave: number;
  wnext: number;
  window: Uint8Array | null;
  hold: number;
  bits: number;
  length: number;
  offset: number;
  extra: number;
  lencode: Int32Array;
  distcode: Int32Array;
  lenbits: number;
  distbits: number;
  ncode: number;
  nlen: number;
  ndist: number;
  have: number;
  next: object | null;
  lens: Uint16Array;
  work: Uint16Array;
  lendyn: Int32Array;
  distdyn: Int32Array;
  sane: number = 0;
  back: number = 0;
  was: number = 0;

  constructor() {
    this.sane = 0;
    this.back = 0;
    this.was = 0;
    this.strm = new ZStreamInflate(); /* pointer back to this zlib stream */
    this.mode = 0; /* current inflate mode */
    this.last = false; /* true if processing last block */
    this.wrap = 0; /* bit 0 true for zlib, bit 1 true for gzip,
                                     bit 2 true to validate check value */
    this.havedict = false; /* true if dictionary provided */
    this.flags = 0; /* gzip header method and flags (0 if zlib), or
                                     -1 if raw or no header yet */
    this.dmax = 0; /* zlib header max distance (INFLATE_STRICT) */
    this.check = 0; /* protected copy of check value */
    this.total = 0; /* protected copy of output count */
    // TODO: may be {}
    this.head = null; /* where to save gzip header information */
    /* sliding window */
    this.wbits = 0; /* log base 2 of requested window size */
    this.wsize = 0; /* window size or zero if not using window */
    this.whave = 0; /* valid bytes in the window */
    this.wnext = 0; /* window write index */
    this.window = null; /* allocated sliding window, if needed */
    /* bit accumulator */
    this.hold = 0; /* input bit accumulator */
    this.bits = 0; /* number of bits in "in" */
    /* for string and stored block copying */
    this.length = 0; /* literal or length of data to copy */
    this.offset = 0; /* distance back to copy string from */
    /* for table and code decoding */
    this.extra = 0; /* extra bits needed */
    /* fixed and dynamic code tables */
    this.lencode = new Int32Array; /* starting table for length/literal codes */
    this.distcode = new Int32Array; /* starting table for distance codes */
    this.lenbits = 0; /* index bits for lencode */
    this.distbits = 0; /* index bits for distcode */
    /* dynamic table building */
    this.ncode = 0; /* number of code length code lengths */
    this.nlen = 0; /* number of length code lengths */
    this.ndist = 0; /* number of distance code lengths */
    this.have = 0; /* number of code lengths in lens[] */
    this.next = null; /* next available space in codes[] */
    this.lens = new Uint16Array(320); /* temporary storage for code lengths */
    this.work = new Uint16Array(288); /* work area for code table building */
    /*
         because we don't have pointers in js, we use lencode and distcode directly
         as buffers so we don't need codes
        */
    //this.codes = new Int32Array(ENOUGH);       /* space for code tables */
    this.lendyn = new Int32Array; /* dynamic table for length/literal codes (JS specific) */
    this.distdyn = new Int32Array; /* dynamic table for distance codes (JS specific) */
    this.sane = 0; /* if false, allow invalid distance too far */
    this.back = 0; /* bits back of last unprocessed length/lit */
    this.was = 0; /* initial length of match */
  }
}
const inflateStateCheck = (strm: ZStreamInflate): boolean => {
  if (strm.state === null) {
    return true;
  }
  const state = strm.state;
  if (state.strm !== strm || state.mode < HEAD || state.mode > SYNC) {
    return true;
  }
  return false;
};
const inflateResetKeep = (strm: ZStreamInflate): number => {
  if (inflateStateCheck(strm) || strm.state === null) {
    return Z_STREAM_ERROR;
  }
  const state = strm.state;
  strm.total_in = strm.total_out = state.total = 0;
  strm.msg = '';
  strm.adler = state.wrap & 1;
  state.mode = HEAD;
  state.last = false;
  state.havedict = false;
  state.flags = -1;
  state.dmax = 32768;
  state.head = null /*Z_NULL*/;
  state.hold = 0;
  state.bits = 0;
  //state.lencode = state.distcode = state.next = state.codes;
  state.lencode = state.lendyn = new Int32Array(ENOUGH_LENS);
  state.distcode = state.distdyn = new Int32Array(ENOUGH_DISTS);
  state.sane = 1;
  state.back = -1;
  //Tracev((stderr, "inflate: reset\n"));
  return Z_OK;
};
const inflateReset = (strm: ZStreamInflate): number => {
  if (inflateStateCheck(strm) || strm.state === null) {
    return Z_STREAM_ERROR;
  }
  const state = strm.state;
  state.wsize = 0;
  state.whave = 0;
  state.wnext = 0;
  return inflateResetKeep(strm);
};
const inflateReset2 = (strm: ZStreamInflate, windowBits: number): number => {
  let wrap: number;
  if (inflateStateCheck(strm) || strm.state === null) {
    return Z_STREAM_ERROR;
  }
  const state = strm.state;
  if (windowBits < 0) {
    wrap = 0;
    windowBits = -windowBits;
  }
  else {
    wrap = (windowBits >> 4) + 5;
    if (windowBits < 48) {
      windowBits &= 15;
    }
  }
  if (windowBits < 8 || windowBits > 15) {
    return Z_STREAM_ERROR;
  }
  if (state.window !== null && state.wbits !== windowBits) {
    state.window = null;
  }
  state.wrap = wrap;
  state.wbits = windowBits;
  return inflateReset(strm);
};
const inflateInit2 = (strm: ZStreamInflate, windowBits: number): number => {
  if (!strm) {
    return Z_STREAM_ERROR;
  }
  const state = new InflateState();
  strm.state = state;
  state.strm = strm;
  state.window = null /*Z_NULL*/;
  state.mode = HEAD; /* to pass state test in inflateReset2() */
  const ret = inflateReset2(strm, windowBits);
  if (ret !== Z_OK) {
    strm.state = null /*Z_NULL*/;
  }
  return ret;
};
/*
 Return state with length and distance decoding tables and index sizes set to
 fixed code decoding.  Normally this returns fixed tables from inffixed.h.
 If BUILDFIXED is defined, then instead this routine builds the tables the
 first time it's called, and returns those tables the first time and
 thereafter.  This reduces the size of the code by about 2K bytes, in
 exchange for a little execution time.  However, BUILDFIXED should not be
 used for threaded applications, since the rewriting of the tables and virgin
 may not be thread-safe.
 */
let virgin = true;
let lenfix: Int32Array, distfix: Int32Array;
// We have no pointers in JS, so keep tables separate
const fixedtables = (state: InflateState) => {
  if (virgin) {
    lenfix = new Int32Array(512);
    distfix = new Int32Array(32);
    let sym = 0;
    while (sym < 144) {
      state.lens[sym++] = 8;
    }
    while (sym < 256) {
      state.lens[sym++] = 9;
    }
    while (sym < 280) {
      state.lens[sym++] = 7;
    }
    while (sym < 288) {
      state.lens[sym++] = 8;
    }
    inflate_table(LENS, state.lens, 0, 288, lenfix, 0, state.work, { bits: 9 });
    sym = 0;
    while (sym < 32) {
      state.lens[sym++] = 5;
    }
    inflate_table(DISTS, state.lens, 0, 32, distfix, 0, state.work, { bits: 5 });
    virgin = false;
  }
  state.lencode = lenfix;
  state.lenbits = 9;
  state.distcode = distfix;
  state.distbits = 5;
};
/*
 Update the window with the last wsize (normally 32K) bytes written before
 returning.  If window does not exist yet, create it.  This is only called
 when a window is already in use, or when output has been written during this
 inflate call, but the end of the deflate stream has not been reached yet.
 It is also called to create a window for dictionary data when a dictionary
 is loaded.

 Providing output buffers larger than 32K to inflate() should provide a speed
 advantage, since only the last 32K of output is copied to the sliding window
 upon return from inflate(), and since all distances after the first 32K of
 output will fall in the output data, making match copies simpler and faster.
 The advantage may be dependent on the size of the processor's data caches.
 */
const updatewindow = (strm: ZStreamInflate, src: Uint8Array, end: number, copy: number): number => {
  const state = strm.state as InflateState;
  if (!state.window) {
    state.wsize = 1 << state.wbits;
    state.wnext = 0;
    state.whave = 0;
    state.window = new Uint8Array(state.wsize);
  }
  const wsize = state.wsize;
  const window = state.window;
  let wnext = state.wnext;
  let whave = state.whave;
  if (copy >= wsize) {
    const start = end - wsize;
    window.set(src.subarray(start, end), 0);
    wnext = 0;
    whave = wsize;
  }
  else {
    const firstPart = Math.min(copy, wsize - wnext);
    const srcStart = end - copy;
    window.set(src.subarray(srcStart, srcStart + firstPart), wnext);
    copy -= firstPart;
    if (copy) {
      window.set(src.subarray(end - copy, end), 0);
      wnext = copy;
      whave = wsize;
    }
    else {
      wnext += firstPart;
      if (wnext === wsize) {
        wnext = 0;
      }
      whave = Math.min(whave + firstPart, wsize);
    }
  }
  state.wnext = wnext;
  state.whave = whave;
  return 0;
};
const inflate$1 = (strm: ZStreamInflate, flush: number):number => {
  let state:InflateState;
  let input:Uint8Array, output:Uint8Array; // input/output buffers
  let next:number; /* next input INDEX */
  let put:number; /* next output INDEX */
  let have:number, left:number; /* available input and output */
  let hold:number; /* bit buffer */
  let bits:number; /* bits in bit buffer */
  let _in:number, _out:number; /* save starting available input and output */
  let copy:number; /* number of stored or match bytes to copy */
  let from:number; /* where to copy match bytes from */
  let from_source:Uint8Array;
  let here = 0; /* current decoding table entry */
  let here_bits:number, here_op:number, here_val:number; // paked "here" denormalized (JS specific)
  let last_bits:number, last_op:number, last_val:number; // paked "last" denormalized (JS specific)
  let len:number; /* length to copy for repeats, bits to drop */
  let ret:number; /* return code */
  const hbuf = new Uint8Array(4); /* buffer for gzip header crc calculation */
  let opts:GeneratedTypeLiteralInterface_Inftrees1;
  let n:number; // temporary variable for NEED_BITS
  const order = /* permutation of code lengths */ new Uint8Array([16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]);
  if (inflateStateCheck(strm) || strm.state === null || !strm.output || (!strm.input && strm.avail_in !== 0)) {
    return Z_STREAM_ERROR;
  }
  state = strm.state;
  if (state.mode === TYPE) {
    state.mode = TYPEDO;
  } /* skip check */
  put = strm.next_out;
  output = strm.output;
  left = strm.avail_out;
  next = strm.next_in;
  input = strm.input;
  have = strm.avail_in;
  hold = state.hold;
  bits = state.bits;
  //---
  _in = have;
  _out = left;
  ret = Z_OK;
  inf_leave: for (;;) {
    switch (state.mode) {
      case HEAD:
        if (state.wrap === 0) {
          state.mode = TYPEDO;
          break;
        }
        while (bits < 16) {
          if (have === 0) {
            break inf_leave;
          }
          have--;
          hold += input[next++] << bits;
          bits += 8;
        }
        if ((state.wrap & 2) && hold === 0x8b1f) { /* gzip header */
          if (state.wbits === 0) {
            state.wbits = 15;
          }
          state.check = 0 /*crc32(0L, Z_NULL, 0)*/;
          hbuf[0] = hold & 0xff;
          hbuf[1] = (hold >>> 8) & 0xff;
          state.check = crc32(state.check, hbuf, 2, 0);
          hold = 0;
          bits = 0;
          state.mode = FLAGS;
          break;
        }
        if (state.head) {
          state.head.done = false;
        }
        if (!(state.wrap & 1) || /* check if zlib header allowed */
          (((hold & 0xff) /*BITS(8)*/ << 8) + (hold >> 8)) % 31) {
          strm.msg = 'incorrect header check';
          state.mode = BAD;
          break;
        }
        if ((hold & 0x0f) /*BITS(4)*/ !== Z_DEFLATED) {
          strm.msg = 'unknown compression method';
          state.mode = BAD;
          break;
        }
        hold >>>= 4;
        bits -= 4;
        len = (hold & 0x0f) /*BITS(4)*/ + 8;
        if (state.wbits === 0) {
          state.wbits = len;
        }
        if (len > 15 || len > state.wbits) {
          strm.msg = 'invalid window size';
          state.mode = BAD;
          break;
        }
        state.dmax = 1 << state.wbits;
        state.flags = 0; /* indicate zlib header */
        strm.adler = state.check = 1 /*adler32(0L, Z_NULL, 0)*/;
        state.mode = hold & 0x200 ? DICTID : TYPE;
        hold = 0;
        bits = 0;
        break;
      case FLAGS:
        while (bits < 16) {
          if (have === 0) {
            break inf_leave;
          }
          have--;
          hold += input[next++] << bits;
          bits += 8;
        }
        state.flags = hold;
        if ((state.flags & 0xff) !== Z_DEFLATED) {
          strm.msg = 'unknown compression method';
          state.mode = BAD;
          break;
        }
        if (state.flags & 0xe000) {
          strm.msg = 'unknown header flags set';
          state.mode = BAD;
          break;
        }
        if (state.head) {
          state.head.text = ((hold >> 8) & 1);
        }
        if ((state.flags & 0x0200) && (state.wrap & 4)) {
          hbuf[0] = hold & 0xff;
          hbuf[1] = (hold >>> 8) & 0xff;
          state.check = crc32(state.check, hbuf, 2, 0);
          //===//
        }
        hold = 0;
        bits = 0;
        state.mode = TIME;
      case TIME:
        while (bits < 32) {
          if (have === 0) {
            break inf_leave;
          }
          have--;
          hold += input[next++] << bits;
          bits += 8;
        }
        if (state.head) {
          state.head.time = hold;
        }
        if ((state.flags & 0x0200) && (state.wrap & 4)) {
          hbuf[0] = hold & 0xff;
          hbuf[1] = (hold >>> 8) & 0xff;
          hbuf[2] = (hold >>> 16) & 0xff;
          hbuf[3] = (hold >>> 24) & 0xff;
          state.check = crc32(state.check, hbuf, 4, 0);
          //===
        }
        hold = 0;
        bits = 0;
        state.mode = OS;
      case OS:
        while (bits < 16) {
          if (have === 0) {
            break inf_leave;
          }
          have--;
          hold += input[next++] << bits;
          bits += 8;
        }
        if (state.head) {
          state.head.xflags = (hold & 0xff);
          state.head.os = (hold >> 8);
        }
        if ((state.flags & 0x0200) && (state.wrap & 4)) {
          hbuf[0] = hold & 0xff;
          hbuf[1] = (hold >>> 8) & 0xff;
          state.check = crc32(state.check, hbuf, 2, 0);
          //===//
        }
        hold = 0;
        bits = 0;
        state.mode = EXLEN;
      case EXLEN:
        if (state.flags & 0x0400) {
          while (bits < 16) {
            if (have === 0) {
              break inf_leave;
            }
            have--;
            hold += input[next++] << bits;
            bits += 8;
          }
          state.length = hold;
          if (state.head) {
            state.head.extra_len = hold;
          }
          if ((state.flags & 0x0200) && (state.wrap & 4)) {
            hbuf[0] = hold & 0xff;
            hbuf[1] = (hold >>> 8) & 0xff;
            state.check = crc32(state.check, hbuf, 2, 0);
            //===//
          }
          hold = 0;
          bits = 0;
          //===//
        }
        else if (state.head) {
          state.head.extra = null /*Z_NULL*/;
        }
        state.mode = EXTRA;
      case EXTRA:
        if (state.flags & 0x0400) {
          copy = state.length;
          if (copy > have) {
            copy = have;
          }
          if (copy) {
            if (state.head) {
              len = (state.head.extra_len as number) - state.length;
              if (!state.head.extra) {
                state.head.extra = new Uint8Array(state.head.extra_len as number);
              }
              (state.head.extra as Uint8Array).set(input.subarray(next, next + copy), len);
              //zmemcpy(state.head.extra + len, next,
              //        len + copy > state.head.extra_max ?
              //        state.head.extra_max - len : copy);
            }
            if ((state.flags & 0x0200) && (state.wrap & 4)) {
              state.check = crc32(state.check, input, copy, next);
            }
            have -= copy;
            next += copy;
            state.length -= copy;
          }
          if (state.length) {
            break inf_leave;
          }
        }
        state.length = 0;
        state.mode = NAME;
      case NAME:
        if (state.flags & 0x0800) {
          if (have === 0) {
            break inf_leave;
          }
          copy = 0;
          do {
            len = input[next + copy++];
            if (state.head && len &&
              (state.length < 65536 /*state.head.name_max*/)) {
              state.head.name += String.fromCharCode(len);
            }
          } while (len && copy < have);
          if ((state.flags & 0x0200) && (state.wrap & 4)) {
            state.check = crc32(state.check, input, copy, next);
          }
          have -= copy;
          next += copy;
          if (len) {
            break inf_leave;
          }
        }
        else if (state.head) {
          state.head.name = '';
        }
        state.length = 0;
        state.mode = COMMENT;
      case COMMENT:
        if (state.flags & 0x1000) {
          if (have === 0) {
            break inf_leave;
          }
          copy = 0;
          do {
            len = input[next + copy++];
            if (state.head && len &&
              (state.length < 65536 /*state.head.comm_max*/)) {
              state.head.comment += String.fromCharCode(len);
            }
          } while (len && copy < have);
          if ((state.flags & 0x0200) && (state.wrap & 4)) {
            state.check = crc32(state.check, input, copy, next);
          }
          have -= copy;
          next += copy;
          if (len) {
            break inf_leave;
          }
        }
        else if (state.head) {
          state.head.comment = '';
        }
        state.mode = HCRC;
      case HCRC:
        if (state.flags & 0x0200) {
          while (bits < 16) {
            if (have === 0) {
              break inf_leave;
            }
            have--;
            hold += input[next++] << bits;
            bits += 8;
          }
          if ((state.wrap & 4) && hold !== (state.check & 0xffff)) {
            strm.msg = 'header crc mismatch';
            state.mode = BAD;
            break;
          }
          hold = 0;
          bits = 0;
          //===//
        }
        if (state.head) {
          state.head.hcrc = Boolean((state.flags >> 9) & 1);
          state.head.done = true;
        }
        strm.adler = state.check = 0;
        state.mode = TYPE;
        break;
      case DICTID:
        while (bits < 32) {
          if (have === 0) {
            break inf_leave;
          }
          have--;
          hold += input[next++] << bits;
          bits += 8;
        }
        strm.adler = state.check = zswap32(hold);
        hold = 0;
        bits = 0;
        state.mode = DICT;
      case DICT:
        if (state.havedict === Boolean(0)) {
          strm.next_out = put;
          strm.avail_out = left;
          strm.next_in = next;
          strm.avail_in = have;
          state.hold = hold;
          state.bits = bits;
          return Z_NEED_DICT;
        }
        strm.adler = state.check = 1 /*adler32(0L, Z_NULL, 0)*/;
        state.mode = TYPE;
      case TYPE:
        if (flush === Z_BLOCK || flush === Z_TREES) {
          break inf_leave;
        }
      case TYPEDO:
        if (state.last) {
          hold >>>= bits & 7;
          bits -= bits & 7;
          state.mode = CHECK;
          break;
        }
        while (bits < 3) {
          if (have === 0) {
            break inf_leave;
          }
          have--;
          hold += input[next++] << bits;
          bits += 8;
        }
        state.last = Boolean(hold & 0x01) /*BITS(1)*/;
        hold >>>= 1;
        bits -= 1;
        switch (hold & 0x03 /*BITS(2)*/) {
          case 0 /* stored block */:
            state.mode = STORED;
            break;
          case 1 /* fixed block */:
            fixedtables(state);
            state.mode = LEN_; /* decode codes */
            if (flush === Z_TREES) {
              hold >>>= 2;
              bits -= 2;
              break inf_leave;
            }
            break;
          case 2 /* dynamic block */:
            state.mode = TABLE;
            break;
          case 3:
            strm.msg = 'invalid block type';
            state.mode = BAD;
        }
        hold >>>= 2;
        bits -= 2;
        break;
      case STORED:
        hold >>>= bits & 7;
        bits -= bits & 7;
        while (bits < 32) {
          if (have === 0) {
            break inf_leave;
          }
          have--;
          hold += input[next++] << bits;
          bits += 8;
        }
        if ((hold & 0xffff) !== ((hold >>> 16) ^ 0xffff)) {
          strm.msg = 'invalid stored block lengths';
          state.mode = BAD;
          break;
        }
        state.length = hold & 0xffff;
        hold = 0;
        bits = 0;
        state.mode = COPY_;
        if (flush === Z_TREES) {
          break inf_leave;
        }
      case COPY_:
        state.mode = COPY;
      case COPY:
        copy = state.length;
        if (copy) {
          if (copy > have) {
            copy = have;
          }
          if (copy > left) {
            copy = left;
          }
          if (copy === 0) {
            break inf_leave;
          }
          output.set(input.subarray(next, next + copy), put);
          have -= copy;
          next += copy;
          left -= copy;
          put += copy;
          state.length -= copy;
          break;
        }
        state.mode = TYPE;
        break;
      case TABLE:
        while (bits < 14) {
          if (have === 0) {
            break inf_leave;
          }
          have--;
          hold += input[next++] << bits;
          bits += 8;
        }
        state.nlen = (hold & 0x1f) /*BITS(5)*/ + 257;
        hold >>>= 5;
        bits -= 5;
        state.ndist = (hold & 0x1f) /*BITS(5)*/ + 1;
        hold >>>= 5;
        bits -= 5;
        state.ncode = (hold & 0x0f) /*BITS(4)*/ + 4;
        hold >>>= 4;
        bits -= 4;
        if (state.nlen > 286 || state.ndist > 30) {
          strm.msg = 'too many length or distance symbols';
          state.mode = BAD;
          break;
        }
        state.have = 0;
        state.mode = LENLENS;
      case LENLENS:
        while (state.have < state.ncode) {
          while (bits < 3) {
            if (have === 0) {
              break inf_leave;
            }
            have--;
            hold += input[next++] << bits;
            bits += 8;
          }
          state.lens[order[state.have++]] = (hold & 0x07); //BITS(3);
          hold >>>= 3;
          bits -= 3;
          //---//
        }
        while (state.have < 19) {
          state.lens[order[state.have++]] = 0;
        }
        state.lencode = state.lendyn;
        state.lenbits = 7;
        opts = { bits: state.lenbits };
        ret = inflate_table(CODES, state.lens, 0, 19, state.lencode, 0, state.work, opts);
        state.lenbits = opts.bits;
        if (ret) {
          strm.msg = 'invalid code lengths set';
          state.mode = BAD;
          break;
        }
        state.have = 0;
        state.mode = CODELENS;
      case CODELENS:
        while (state.have < state.nlen + state.ndist) {
          for (;;) {
            here = (state.lencode)[hold & ((1 << state.lenbits) - 1)]; /*BITS(state.lenbits)*/
            here_bits = here >>> 24;
            here_op = (here >>> 16) & 0xff;
            here_val = here & 0xffff;
            if (here_bits <= bits) {
              break;
            }
            if (have === 0) {
              break inf_leave;
            }
            have--;
            hold += input[next++] << bits;
            bits += 8;
            //---//
          }
          if (here_val < 16) {
            hold >>>= here_bits;
            bits -= here_bits;
            state.lens[state.have++] = here_val;
          }
          else {
            if (here_val === 16) {
              n = here_bits + 2;
              while (bits < n) {
                if (have === 0) {
                  break inf_leave;
                }
                have--;
                hold += input[next++] << bits;
                bits += 8;
              }
              hold >>>= here_bits;
              bits -= here_bits;
              if (state.have === 0) {
                strm.msg = 'invalid bit length repeat';
                state.mode = BAD;
                break;
              }
              len = state.lens[state.have - 1];
              copy = 3 + (hold & 0x03); //BITS(2);
              hold >>>= 2;
              bits -= 2;
              //---//
            }
            else if (here_val === 17) {
              n = here_bits + 3;
              while (bits < n) {
                if (have === 0) {
                  break inf_leave;
                }
                have--;
                hold += input[next++] << bits;
                bits += 8;
              }
              hold >>>= here_bits;
              bits -= here_bits;
              len = 0;
              copy = 3 + (hold & 0x07); //BITS(3);
              hold >>>= 3;
              bits -= 3;
              //---//
            }
            else {
              n = here_bits + 7;
              while (bits < n) {
                if (have === 0) {
                  break inf_leave;
                }
                have--;
                hold += input[next++] << bits;
                bits += 8;
              }
              hold >>>= here_bits;
              bits -= here_bits;
              len = 0;
              copy = 11 + (hold & 0x7f); //BITS(7);
              hold >>>= 7;
              bits -= 7;
              //---//
            }
            if (state.have + copy > state.nlen + state.ndist) {
              strm.msg = 'invalid bit length repeat';
              state.mode = BAD;
              break;
            }
            while (copy--) {
              state.lens[state.have++] = len;
            }
          }
        }
        if (state.mode === BAD) {
          break;
        }
        if (state.lens[256] === 0) {
          strm.msg = 'invalid code -- missing end-of-block';
          state.mode = BAD;
          break;
        }
        state.lenbits = 9;
        opts = { bits: state.lenbits };
        ret = inflate_table(LENS, state.lens, 0, state.nlen, state.lencode, 0, state.work, opts);
        state.lenbits = opts.bits;
        if (ret) {
          strm.msg = 'invalid literal/lengths set';
          state.mode = BAD;
          break;
        }
        state.distbits = 6;
        state.distcode = state.distdyn;
        opts = { bits: state.distbits };
        ret = inflate_table(DISTS, state.lens, state.nlen, state.ndist, state.distcode, 0, state.work, opts);
        state.distbits = opts.bits;
        if (ret) {
          strm.msg = 'invalid distances set';
          state.mode = BAD;
          break;
        }
        state.mode = LEN_;
        if (flush === Z_TREES) {
          break inf_leave;
        }
      case LEN_:
        state.mode = LEN;
      case LEN:
        if (have >= 6 && left >= 258) {
          strm.next_out = put;
          strm.avail_out = left;
          strm.next_in = next;
          strm.avail_in = have;
          state.hold = hold;
          state.bits = bits;
          inflate_fast(strm, _out);
          put = strm.next_out;
          output = strm.output;
          left = strm.avail_out;
          next = strm.next_in;
          input = strm.input;
          have = strm.avail_in;
          hold = state.hold;
          bits = state.bits;
          if (state.mode === TYPE) {
            state.back = -1;
          }
          break;
        }
        state.back = 0;
        for (;;) {
          here = (state.lencode)[hold & ((1 << state.lenbits) - 1)]; /*BITS(state.lenbits)*/
          here_bits = here >>> 24;
          here_op = (here >>> 16) & 0xff;
          here_val = here & 0xffff;
          if (here_bits <= bits) {
            break;
          }
          if (have === 0) {
            break inf_leave;
          }
          have--;
          hold += input[next++] << bits;
          bits += 8;
          //---//
        }
        if (here_op && (here_op & 0xf0) === 0) {
          last_bits = here_bits;
          last_op = here_op;
          last_val = here_val;
          for (;;) {
            here = (state.lencode)[last_val + ((hold & ((1 << (last_bits + last_op)) - 1)) /*BITS(last.bits + last.op)*/ >> last_bits)];
            here_bits = here >>> 24;
            here_op = (here >>> 16) & 0xff;
            here_val = here & 0xffff;
            if (last_bits + here_bits <= bits) {
              break;
            }
            if (have === 0) {
              break inf_leave;
            }
            have--;
            hold += input[next++] << bits;
            bits += 8;
            //---//
          }
          hold >>>= last_bits;
          bits -= last_bits;
          state.back += last_bits;
        }
        hold >>>= here_bits;
        bits -= here_bits;
        state.back += here_bits;
        state.length = here_val;
        if (here_op === 0) {
          state.mode = LIT;
          break;
        }
        if (here_op & 32) {
          state.back = -1;
          state.mode = TYPE;
          break;
        }
        if (here_op & 64) {
          strm.msg = 'invalid literal/length code';
          state.mode = BAD;
          break;
        }
        state.extra = here_op & 15;
        state.mode = LENEXT;
      case LENEXT:
        if (state.extra) {
          n = state.extra;
          while (bits < n) {
            if (have === 0) {
              break inf_leave;
            }
            have--;
            hold += input[next++] << bits;
            bits += 8;
          }
          state.length += hold & ((1 << state.extra) - 1) /*BITS(state.extra)*/;
          hold >>>= state.extra;
          bits -= state.extra;
          state.back += state.extra;
        }
        state.was = state.length;
        state.mode = DIST;
      case DIST:
        for (;;) {
          here = (state.distcode)[hold & ((1 << state.distbits) - 1)]; /*BITS(state.distbits)*/
          here_bits = here >>> 24;
          here_op = (here >>> 16) & 0xff;
          here_val = here & 0xffff;
          if (here_bits <= bits) {
            break;
          }
          if (have === 0) {
            break inf_leave;
          }
          have--;
          hold += input[next++] << bits;
          bits += 8;
          //---//
        }
        if ((here_op & 0xf0) === 0) {
          last_bits = here_bits;
          last_op = here_op;
          last_val = here_val;
          for (;;) {
            here = (state.distcode)[last_val + ((hold & ((1 << (last_bits + last_op)) - 1)) /*BITS(last.bits + last.op)*/ >> last_bits)];
            here_bits = here >>> 24;
            here_op = (here >>> 16) & 0xff;
            here_val = here & 0xffff;
            if (last_bits + here_bits <= bits) {
              break;
            }
            if (have === 0) {
              break inf_leave;
            }
            have--;
            hold += input[next++] << bits;
            bits += 8;
            //---//
          }
          hold >>>= last_bits;
          bits -= last_bits;
          state.back += last_bits;
        }
        hold >>>= here_bits;
        bits -= here_bits;
        state.back += here_bits;
        if (here_op & 64) {
          strm.msg = 'invalid distance code';
          state.mode = BAD;
          break;
        }
        state.offset = here_val;
        state.extra = here_op & 15;
        state.mode = DISTEXT;
      case DISTEXT:
        if (state.extra) {
          n = state.extra;
          while (bits < n) {
            if (have === 0) {
              break inf_leave;
            }
            have--;
            hold += input[next++] << bits;
            bits += 8;
          }
          state.offset += hold & ((1 << state.extra) - 1) /*BITS(state.extra)*/;
          hold >>>= state.extra;
          bits -= state.extra;
          state.back += state.extra;
        }
        if (state.offset > state.dmax) {
          strm.msg = 'invalid distance too far back';
          state.mode = BAD;
          break;
        }
        state.mode = MATCH;
      case MATCH:
        if (left === 0) {
          break inf_leave;
        }
        copy = _out - left;
        if (state.offset > copy) {
          copy = state.offset - copy;
          if (copy > state.whave) {
            if (state.sane) {
              strm.msg = 'invalid distance too far back';
              state.mode = BAD;
              break;
            }
            // (!) This block is disabled in zlib defaults,
            // don't enable it for binary compatibility
            //#ifdef INFLATE_ALLOW_INVALID_DISTANCE_TOOFAR_ARRR
            //          Trace((stderr, "inflate.c too far\n"));
            //          copy -= state.whave;
            //          if (copy > state.length) { copy = state.length; }
            //          if (copy > left) { copy = left; }
            //          left -= copy;
            //          state.length -= copy;
            //          do {
            //            output[put++] = 0;
            //          } while (--copy);
            //          if (state.length === 0) { state.mode = LEN; }
            //          break;
            //#endif
          }
          if (copy > state.wnext) {
            copy -= state.wnext;
            from = state.wsize - copy;
          }
          else {
            from = state.wnext - copy;
          }
          if (copy > state.length) {
            copy = state.length;
          }
          from_source = state.window as Uint8Array;
        }
        else {
          from_source = output;
          from = put - state.offset;
          copy = state.length;
        }
        if (copy > left) {
          copy = left;
        }
        left -= copy;
        state.length -= copy;
        do {
          output[put++] = from_source[from++];
        } while (--copy);
        if (state.length === 0) {
          state.mode = LEN;
        }
        break;
      case LIT:
        if (left === 0) {
          break inf_leave;
        }
        output[put++] = state.length;
        left--;
        state.mode = LEN;
        break;
      case CHECK:
        if (state.wrap) {
          while (bits < 32) {
            if (have === 0) {
              break inf_leave;
            }
            have--;
            hold |= input[next++] << bits;
            bits += 8;
          }
          _out -= left;
          strm.total_out += _out;
          state.total += _out;
          if ((state.wrap & 4) && _out) {
            strm.adler = state.check =
              /*UPDATE_CHECK(state.check, put - _out, _out);*/
              (state.flags ? crc32(state.check, output, _out, put - _out) : adler32(state.check, output, _out, put - _out));
          }
          _out = left;
          if ((state.wrap & 4) && (state.flags ? hold : zswap32(hold)) !== state.check) {
            strm.msg = 'incorrect data check';
            state.mode = BAD;
            break;
          }
          hold = 0;
          bits = 0;
          //===//
          //Tracev((stderr, "inflate:   check matches trailer\n"));
        }
        state.mode = LENGTH;
      case LENGTH:
        if (state.wrap && state.flags) {
          while (bits < 32) {
            if (have === 0) {
              break inf_leave;
            }
            have--;
            hold += input[next++] << bits;
            bits += 8;
          }
          if ((state.wrap & 4) && hold !== (state.total & 0xffffffff)) {
            strm.msg = 'incorrect length check';
            state.mode = BAD;
            break;
          }
          hold = 0;
          bits = 0;
          //===//
          //Tracev((stderr, "inflate:   length matches trailer\n"));
        }
        state.mode = DONE;
      case DONE:
        ret = Z_STREAM_END;
        break inf_leave;
      case BAD:
        ret = Z_DATA_ERROR;
        break inf_leave;
      case MEM:
        return Z_MEM_ERROR;
      case SYNC:
      default:
        return Z_STREAM_ERROR;
    }
  }
  strm.next_out = put;
  strm.avail_out = left;
  strm.next_in = next;
  strm.avail_in = have;
  state.hold = hold;
  state.bits = bits;
  if (state.wsize || (_out !== strm.avail_out && state.mode < BAD && (state.mode < CHECK || flush !== Z_FINISH))) {
    if (updatewindow(strm, strm.output, strm.next_out, _out - strm.avail_out)) {
      state.mode = MEM;
      return Z_MEM_ERROR;
    }
  }
  _in -= strm.avail_in;
  _out -= strm.avail_out;
  strm.total_in += _in;
  strm.total_out += _out;
  state.total += _out;
  if ((state.wrap & 4) && _out) {
    strm.adler = state.check = /*UPDATE_CHECK(state.check, strm.next_out - _out, _out);*/
      (state.flags ? crc32(state.check, output, _out, strm.next_out - _out) : adler32(state.check, output, _out, strm.next_out - _out));
  }
  strm.data_type = state.bits + (state.last ? 64 : 0) +
    (state.mode === TYPE ? 128 : 0) +
    (state.mode === LEN_ || state.mode === COPY_ ? 256 : 0);
  if (((_in === 0 && _out === 0) || flush === Z_FINISH) && ret === Z_OK) {
    ret = Z_BUF_ERROR;
  }
  return ret;
};
const inflateEnd = (strm: ZStreamInflate) => {
  if (inflateStateCheck(strm) || strm.state === null) {
    return Z_STREAM_ERROR;
  }
  let state = strm.state;
  if (state.window) {
    state.window = null;
  }
  strm.state = null;
  return Z_OK;
};
const inflateGetHeader = (strm: ZStreamInflate, head: GZheader) => {
  if (inflateStateCheck(strm) || strm.state === null) {
    return Z_STREAM_ERROR;
  }
  const state = strm.state;
  if ((state.wrap & 2) === 0) {
    return Z_STREAM_ERROR;
  }
  state.head = head;
  head.done = false;
  return Z_OK;
};
const inflateSetDictionary = (strm: ZStreamInflate, dictionary: Uint8Array): number => {
  if (inflateStateCheck(strm) || !strm.state) {
    return Z_STREAM_ERROR;
  }
  const state = strm.state;
  if (state.wrap !== 0 && state.mode !== DICT) {
    return Z_STREAM_ERROR;
  }
  if (state.mode === DICT) {
    if (adler32(1, dictionary, dictionary.length, 0) !== state.check) {
      return Z_DATA_ERROR;
    }
  }
  if (updatewindow(strm, dictionary, dictionary.length, dictionary.length)) {
    state.mode = MEM;
    return Z_MEM_ERROR;
  }
  state.havedict = true;
  return Z_OK;
};

// (C) 1995-2013 Jean-loup Gailly and Mark Adler
// (C) 2014-2017 Vitaly Puzrin and Andrey Tupitsin
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//   claim that you wrote the original software. If you use this software
//   in a product, an acknowledgment in the product documentation would be
//   appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//   misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.
class GZheader {
  text?: number = 0;
  time?: number = 0;
  xflags?: number = 0;
  os?: number = 0;
  extra?: number[]|Uint8Array | null = null;
  extra_len?: number = 0;
  name?: string = '';
  comment?: string = '';
  hcrc?: boolean = Boolean(0);
  done?: boolean = false;
}
interface InflateOptions {
  windowBits?: number ;
  dictionary?: Uint8Array ;
  raw?: boolean ;
  to?: string ;
  chunkSize?: number ;
}
interface InflateStrOptions extends InflateOptions{
  to:"string"
}
function inflate(data: Uint8Array | ArrayBuffer, options: InflateStrOptions): string;
function inflate(data: Uint8Array | ArrayBuffer, options?: InflateOptions): Uint8Array;

function inflate(input: Uint8Array | ArrayBuffer, options?: InflateOptions): Uint8Array | string {
  const inflator = new Inflate(options);
  inflator.push(input);
  if (inflator.err) throw new Error(inflator.msg|| record_Messages_1[inflator.err]);
  return inflator.result;
}

function inflateRaw(data: Uint8Array | ArrayBuffer, options: InflateStrOptions): string;
function inflateRaw(data: Uint8Array | ArrayBuffer, options?: InflateOptions): Uint8Array;
function inflateRaw(input: Uint8Array | ArrayBuffer, options?: InflateOptions): Uint8Array | string {
  options = options || {};
  options.raw = true;

  return inflate(input, options);
}
interface InflateOptionsWithoutUndefined {
  windowBits: number ;
  dictionary?: Uint8Array ;
  raw?: boolean ;
  to: string ;
  chunkSize: number ;
}

class Inflate {
  options:InflateOptionsWithoutUndefined;
  err: number;
  msg: string;
  ended: boolean;
  chunksUint8Array: Uint8Array[];
  chunksString: Array<string>;
  strm: ZStreamInflate;
  result: Uint8Array|string = new Uint8Array(0);
  header?:GZheader;
  constructor(options?: InflateOptions) {
    this.options = {
      chunkSize: options?.chunkSize??1024 * 64,
      windowBits: options?.windowBits??15,
      to: options?.to??'',
      dictionary: options?.dictionary,
      raw: options?.raw
    }
    const opt = this.options;
    if (opt.raw && ((opt.windowBits) >= 0) && ((opt.windowBits) < 16)) {
      opt.windowBits = -(opt.windowBits);
      if (opt.windowBits === 0) {
        opt.windowBits = -15;
      }
    }
    if ((opt.windowBits >= 0) && (opt.windowBits < 16) &&
      !(options && options.windowBits)) {
      (opt.windowBits) += 32;
    }
    if (opt.windowBits > 15 && opt.windowBits < 48) {
      if (((opt.windowBits) & 15) === 0) {
        (opt.windowBits) |= 15;
      }
    }
    this.err = 0; // error code, if happens (0 = Z_OK)
    this.msg = ''; // error message
    this.ended = false; // used to avoid multiple onEnd() calls
    this.chunksUint8Array = []; // chunks of compressed data
    this.chunksString = [];
    this.strm = new ZStreamInflate();
    this.strm.avail_out = 0;
    let status = inflateInit2(this.strm, opt.windowBits);
    if (status !== Z_OK) {
      throw new Error(record_Messages_1[status]);
    }
    this.header = new GZheader();
    inflateGetHeader(this.strm, this.header);
    if (opt.dictionary) {
      if (typeof opt.dictionary === 'string') {
        opt.dictionary = string2buf(opt.dictionary);
      }
      else if (opt.dictionary instanceof ArrayBuffer) {
        opt.dictionary = new Uint8Array(opt.dictionary);
      }
      if (opt.raw) {
        status = inflateSetDictionary(this.strm, opt.dictionary);
        if (status !== Z_OK) {
          throw new Error(record_Messages_1[status]);
        }
      }
    }
  }
  push(data: ArrayBuffer | Uint8Array, flush_mode?: number | boolean): boolean {
    const strm = this.strm;
    const chunkSize = this.options.chunkSize;
    const dictionary = this.options.dictionary;
    let status:number, _flush_mode:number, last_avail_out:number;
    if (this.ended)
      return false;
    if (flush_mode === ~~Number(flush_mode))
      _flush_mode = Number(flush_mode);
    else
      _flush_mode = flush_mode === true ? Z_FINISH : Z_NO_FLUSH;
    if (data instanceof ArrayBuffer) {
      strm.input = new Uint8Array(data);
    }
    else {
      strm.input = data;
    }
    strm.next_in = 0;
    strm.avail_in = strm.input.length;
    for (;;) {
      if (strm.avail_out === 0) {
        strm.output = new Uint8Array(chunkSize);
        strm.next_out = 0;
        strm.avail_out = chunkSize;
      }
      status = inflate$1(strm, _flush_mode);
      if (status === Z_NEED_DICT && dictionary) {
        status = inflateSetDictionary(strm, dictionary);
        if (status === Z_OK) {
          status = inflate$1(strm, _flush_mode);
        }
        else if (status === Z_DATA_ERROR) {
          status = Z_NEED_DICT;
        }
      }
      while (strm.avail_in > 0 &&
        status === Z_STREAM_END &&
        (strm.state as InflateState).wrap > 0 &&
        (data as Uint8Array)[strm.next_in] !== 0){
        inflateReset(strm);
        status = inflate$1(strm, _flush_mode);
      }
      switch (status) {
        case Z_STREAM_ERROR:
        case Z_DATA_ERROR:
        case Z_NEED_DICT:
        case Z_MEM_ERROR:
          this.onEnd(status);
          this.ended = true;
          return false;
      }
      last_avail_out = strm.avail_out;
      if (strm.next_out) {
        if (strm.avail_out === 0 || status === Z_STREAM_END) {
          if (this.options.to === 'string') {
            let next_out_utf8 = utf8border(strm.output, strm.next_out);
            let tail = strm.next_out - next_out_utf8;
            let utf8str = buf2string(strm.output, next_out_utf8);
            strm.next_out = tail;
            strm.avail_out = (chunkSize) - tail;
            if (tail)
              strm.output.set(strm.output.subarray(next_out_utf8, next_out_utf8 + tail), 0);
            this.onData(utf8str);
          }
          else {
            this.onData(strm.output.length === strm.next_out ? strm.output : strm.output.subarray(0, strm.next_out));
          }
        }
      }
      if (status === Z_OK && last_avail_out === 0)
        continue;
      if (status === Z_STREAM_END) {
        status = inflateEnd(this.strm);
        this.onEnd(status);
        this.ended = true;
        return true;
      }
      if (strm.avail_in === 0)
        break;
    }
    return true;
  }
  onData(chunk: Uint8Array | string): void {
    if (chunk instanceof Uint8Array) {
      this.chunksUint8Array.push(chunk);
    }
    else {
      this.chunksString.push(chunk);
    }
  }
  onEnd(status: number): void {
    if (status === Z_OK) {
      if (this.options.to === 'string') {
        this.result = this.chunksString.join('');
      }
      else {
        this.result = flattenChunks(this.chunksUint8Array);
      }
    }
    this.chunksString = [];
    this.chunksUint8Array = [];
    this.err = status;
    this.msg = this.strm.msg;
  }
}

export { Deflate, Inflate, varGeneratedObjTypeLiteralInterface_Constants1 as constants, deflate, deflateRaw, gzip, inflate, inflateRaw, inflate as ungzip };
