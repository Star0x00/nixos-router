#!/usr/bin/env node
// 从 Sub-Store 订阅(目标格式 sing-box)生成 sing-box 配置里的 outbounds。
//
// 只重写目标 JSON 的 `outbounds` 字段, 其余部分(log / dns / ntp / inbounds /
// route / services / experimental)原样保留, 所以可以对同一份 base 反复运行。
//
// 生成结构:
//   🚀 节点选择    selector  [🚀 Cloudflare, ♻️ 自动选择, <每个节点>]  默认 🚀 Cloudflare
//   🚀 Cloudflare  urltest   全部节点 (cp.cloudflare.com 测速)
//   ♻️ 自动选择    urltest   全部节点 (gstatic 测速)
//   direct / block
//
// 分流全部由 dae 负责: dae 只把该走代理的流量丢给本地 SOCKS5,
// sing-box 内部不再按 Google / Cloudflare / 地区 / 直连分支出站;
// 这几个组只决定「用哪个节点」, 可在 dashboard (0.0.0.0:9090) 里手动切换。
//
// 用法:
//   node gen-singbox-base.mjs <subscription-url|node.json> [template.json] [output.json]
//
//   <源>      订阅 URL, 或已下载的 node.json 本地路径
//   template  静态 base(只取其 outbounds 以外的部分), 默认 ../singbox/base.json
//   output    输出文件, 默认与 template 相同(就地重写; 运行时务必显式给 output)
//
// 路由器上的调用(见 bin/sing-box-update.sh):
//   node gen-singbox-base.mjs /etc/sing-box/node.json \
//     /usr/share/router/singbox/base.json /etc/sing-box/config.json

import { readFileSync, writeFileSync, rmSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));

const PROXY_TAG = "🚀 节点选择";
const CF_TAG = "🚀 Cloudflare";
const AUTO_TAG = "♻️ 自动选择";
const TEST_URL = "https://cp.cloudflare.com/generate_204";
const AUTO_TEST_URL = "https://www.gstatic.com/generate_204";
const INTERVAL = "1m";
const TOLERANCE = 50;

// 订阅里除真实节点外的出站类型, 生成时必须丢掉(否则会嵌套引用旧组)。
const NON_NODE_TYPES = new Set(["selector", "urltest", "direct", "block", "dns"]);

// 订阅尾部常见的非节点文本行(如 "剩余流量: ...", "套餐到期: ...")。
const JUNK_TAG = /剩余|到期/;

const args = process.argv.slice(2);
if (args.length < 1) {
  console.error(
    "用法: node gen-singbox-base.mjs <subscription-url|node.json> [template.json] [output.json]",
  );
  process.exit(2);
}
const source = args[0];
const template = resolve(args[1] ?? resolve(HERE, "../singbox/base.json"));
const target = resolve(args[2] ?? template);

let sub;
if (/^https?:\/\//.test(source)) {
  const res = await fetch(source);
  if (!res.ok) {
    console.error(`下载订阅失败: HTTP ${res.status} ${res.statusText}`);
    process.exit(1);
  }
  sub = JSON.parse(await res.text());
} else {
  sub = JSON.parse(readFileSync(source, "utf8"));
}

const nodes = [
  ...new Set(
    (sub.outbounds ?? [])
      .filter((o) => o?.tag && !NON_NODE_TYPES.has(o.type) && !JUNK_TAG.test(o.tag))
      .map((o) => o.tag),
  ),
];
if (nodes.length === 0) {
  console.error("订阅里没有任何节点, 订阅结构可能变了");
  process.exit(1);
}

const urltest = (tag, url) => ({
  type: "urltest",
  tag,
  interrupt_exist_connections: true,
  outbounds: nodes,
  url,
  interval: INTERVAL,
  tolerance: TOLERANCE,
});

const outbounds = [
  {
    type: "selector",
    tag: PROXY_TAG,
    default: CF_TAG,
    interrupt_exist_connections: true,
    outbounds: [CF_TAG, AUTO_TAG, ...nodes],
  },
  urltest(CF_TAG, TEST_URL),
  urltest(AUTO_TAG, AUTO_TEST_URL),
  { type: "direct", tag: "direct" },
  { type: "block", tag: "block" },
];

const base = JSON.parse(readFileSync(template, "utf8"));
base.outbounds = outbounds;
if (base.route) base.route.final = PROXY_TAG;

// target 可能是指向只读位置的软链, 先删掉再写。
rmSync(target, { force: true });
writeFileSync(target, JSON.stringify(base, null, 2) + "\n");

// 自检: route 里引用的出站必须都存在。
const tags = new Set(outbounds.map((o) => o.tag));
let bad = 0;
for (const rule of base.route?.rules ?? []) {
  if (rule.outbound && !tags.has(rule.outbound)) {
    console.error(`警告: route 引用了不存在的 outbound: ${rule.outbound}`);
    bad++;
  }
}
if (base.route?.final && !tags.has(base.route.final)) {
  console.error(`警告: route.final 引用了不存在的 outbound: ${base.route.final}`);
  bad++;
}

console.log(`已写入 ${target}`);
console.log(`${PROXY_TAG}: 默认 ${CF_TAG}`);
console.log(`${CF_TAG}: ${nodes.length} 个节点 (${TEST_URL})`);
console.log(`${AUTO_TAG}: ${nodes.length} 个节点 (${AUTO_TEST_URL})`);
if (bad) process.exit(1);
