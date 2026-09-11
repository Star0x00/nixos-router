#!/usr/bin/env node
// 从 Sub-Store 订阅生成 sing-box base 配置里的地区节点组(outbounds)。
//
// 只重写目标 JSON 的 `outbounds` 字段, 其余部分(dns / route / rule_set /
// experimental ...)原样保留, 所以可以直接对现有 base.json 反复运行。
//
// 生成结构:
//   🎯 Direct      selector  [direct, block]
//   🚀 节点选择    selector  [🚀 Google, 🚀 Cloudflare, <每个地区组>]
//   <地区>         urltest   该地区全部节点 (按延迟自动选, 和 JP 一样)
//   🚀 Google      urltest   全部节点 (gstatic 测速)
//   🚀 Cloudflare  urltest   全部节点 (cloudflare 测速)
//   direct / block
//
// 用法:
//   node gen-singbox-base.mjs <subscription-url|node.json> [template.json] [output.json]
//
//   <源>        订阅 URL, 或已下载的 node.json 本地路径
//   template    静态 base (只取其 dns/route/... , outbounds 会被重写), 默认 singbox-b-base.json
//   output      输出文件, 默认与 template 相同(就地重写)
//
// 例(仓库根目录执行):
//   node hosts/router/assets/gen-singbox-base.mjs \
//     'http://10.10.10.1:3001/qwerhyy123/download/jiuxiang?target=sing-box' \
//     hosts/router/assets/singbox-b-base.json
//
// 路由器每日更新时:
//   node gen-singbox-base.mjs /etc/singbox-b/node.json \
//     <store>/singbox-b-base.json /etc/singbox-b/base.json

import { readFileSync, writeFileSync, rmSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));

// 地区 -> emoji + 排序权重. 只有表内的地区会生成组, 其它一律忽略.
const REGIONS = {
  香港: { flag: "🇭🇰", order: 10 },
  新加坡: { flag: "🇸🇬", order: 20 },
  日本: { flag: "🇯🇵", order: 30 },
  美国: { flag: "🇺🇸", order: 40 },
  韩国: { flag: "🇰🇷", order: 50 },
  越南: { flag: "🇻🇳", order: 60 },
  土耳其: { flag: "🇹🇷", order: 70 },
  法国: { flag: "🇫🇷", order: 80 },
  德国: { flag: "🇩🇪", order: 90 },
  英国: { flag: "🇬🇧", order: 100 },
  泰国: { flag: "🇹🇭", order: 110 },
};

// 旧组名 -> 新组名, 用于同步 route 里已经写死的 outbound 引用.
const LEGACY = {
  "🚀 JP": "🇯🇵 日本",
};

const TEST_URL = "https://cp.cloudflare.com/generate_204";
const GOOGLE_TEST_URL = "https://www.gstatic.com/generate_204";
const INTERVAL = "1m";
const TOLERANCE = 50;

const args = process.argv.slice(2);
if (args.length < 1) {
  console.error(
    "用法: node gen-singbox-base.mjs <subscription-url|node.json> [template.json] [output.json]",
  );
  process.exit(2);
}
const source = args[0];
const template = resolve(args[1] ?? resolve(HERE, "singbox-b-base.json"));
const target = resolve(args[2] ?? template);

// 取 tag 开头的中文作为地区名, 信息条目(无 "|")会被排除:
//   "香港1|AnyTLS[1x]"   -> "香港"   (B)
//   "香港A02 | IEPL"      -> "香港"   (A)
//   "到期:2026-...;剩余.." -> 无 "|" 排除
function regionOf(tag) {
  if (!tag || !tag.includes("|")) return null;
  const m = /^(\p{Script=Han}+)/u.exec(tag);
  return m ? m[1] : null;
}

function regionTag(region) {
  const flag = REGIONS[region]?.flag ?? "";
  return `${flag} ${region}`.trim();
}

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
const nodes = (sub.outbounds ?? []).filter(
  (o) => o.tag && !["selector", "urltest", "direct", "block"].includes(o.type),
);

const groups = new Map();
for (const node of nodes) {
  const region = regionOf(node.tag);
  if (!region) continue;
  if (!groups.has(region)) groups.set(region, []);
  groups.get(region).push(node.tag);
}
if (groups.size === 0) {
  console.error("没有从订阅里解析出任何地区节点, 订阅结构可能变了");
  process.exit(1);
}

const regionNames = [...groups.keys()]
  // 只保留白名单里的地区, 避免生成 "台湾" 这种没有 flag 的杂组
  .filter((r) => REGIONS[r])
  .sort((a, b) => {
    const oa = REGIONS[a]?.order ?? 1e9;
    const ob = REGIONS[b]?.order ?? 1e9;
    return oa - ob || a.localeCompare(b);
  });
if (regionNames.length === 0) {
  console.error("订阅里的地区都不在 REGIONS 白名单内");
  process.exit(1);
}
const allNodes = regionNames.flatMap((r) => groups.get(r));

const regionGroups = regionNames.map((r) => ({
  type: "urltest",
  tag: regionTag(r),
  interrupt_exist_connections: true,
  outbounds: groups.get(r),
  url: TEST_URL,
  interval: INTERVAL,
  tolerance: TOLERANCE,
}));

const outbounds = [
  {
    type: "selector",
    tag: "🎯 Direct",
    interrupt_exist_connections: true,
    outbounds: ["direct", "block"],
  },
  {
    type: "selector",
    tag: "🚀 节点选择",
    interrupt_exist_connections: true,
    outbounds: ["🚀 Google", "🚀 Cloudflare", ...regionGroups.map((g) => g.tag)],
  },
  ...regionGroups,
  {
    type: "urltest",
    tag: "🚀 Google",
    interrupt_exist_connections: true,
    outbounds: allNodes,
    url: GOOGLE_TEST_URL,
    interval: INTERVAL,
    tolerance: TOLERANCE,
  },
  {
    type: "urltest",
    tag: "🚀 Cloudflare",
    interrupt_exist_connections: true,
    outbounds: allNodes,
    url: TEST_URL,
    interval: INTERVAL,
    tolerance: TOLERANCE,
  },
  { type: "direct", tag: "direct" },
  { type: "block", tag: "block" },
];

const base = JSON.parse(readFileSync(template, "utf8"));
base.outbounds = outbounds;
for (const rule of base.route?.rules ?? []) {
  if (rule.outbound && LEGACY[rule.outbound]) rule.outbound = LEGACY[rule.outbound];
}
// target 可能是指向 nix store 的只读软链, 先删掉再写.
rmSync(target, { force: true });
writeFileSync(target, JSON.stringify(base, null, 2) + "\n");

// 自检: route 里引用的 outbound 必须都存在.
const tags = new Set(outbounds.map((o) => o.tag));
let bad = 0;
for (const rule of base.route?.rules ?? []) {
  if (rule.outbound && !tags.has(rule.outbound)) {
    console.error(`警告: route 引用了不存在的 outbound: ${rule.outbound}`);
    bad++;
  }
}

console.log(`已写入 ${target}`);
console.log(
  `地区组(${regionGroups.length}): ` +
    regionGroups.map((g) => `${g.tag}[${g.outbounds.length}]`).join(" "),
);
console.log(`🚀 Google / 🚀 Cloudflare: ${allNodes.length} 个节点`);
if (bad) process.exit(1);
