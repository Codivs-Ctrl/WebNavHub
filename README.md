# CodiFelix NavHub

一个单文件（`index.html`）的浏览器导航主页：搜索聚合、快捷站点、备忘录、最近搜索、自定义背景。

站点数据存放在 `data/sites.js`，可提交到 GitHub 永久保存，换浏览器、换设备都不会丢。

**在线地址**：https://navhub.codivs.com

- 零依赖、零构建，双击 `index.html` 即可运行
- 站点的增删改与排序全部在页面上完成，改动自动保存
- 数据可选云同步到自己的 GitHub 仓库，无需自建后端
- 自带备份 / 恢复、备忘录邮件备份、公网 IP 与设备信息

---

## 快速开始

无需构建、无依赖安装，直接用浏览器打开 `index.html` 即可运行。

如需本地起服务（推荐，避免 `file://` 下的个别限制）：

```powershell
# 任选其一
python -m http.server 5500
npx serve .
```

### 环境要求

| 项目 | 要求 |
|---|---|
| 浏览器 | Chrome / Edge 88+、Firefox 89+、Safari 15+ |
| 服务器 | 任意静态托管；本地直接双击 `index.html` 也能运行 |
| 网络 | 需联网加载 Sortable.js（CDN）与站点图标；离线时仅拖拽排序不可用，其余功能正常 |

> 数据文件特意命名为 `.js` 而非 `.json`：浏览器在 `file://` 协议下会拦截 `fetch` 读取本地 `.json`，而 `<script src>` 不受此限制。

## 目录结构

```
WebNavHub/
├── index.html                # 全部逻辑（HTML + CSS + JS 内联）
├── data/
│   └── sites.js              # 站点数据（永久保存的站点列表）
├── tools/
│   ├── sync-local.ps1        # 可选：Windows 下的数据文件与云端互同步脚本
│   ├── sync-local.sh         # 可选：Linux / macOS / 树莓派 版同上
│   └── deploy-pi.sh          # 可选：一键部署到树莓派（systemd 常驻 + 定时拉取）
├── image0.webp               # 默认背景
├── alimail.webp              # 阿里邮箱图标
├── google-brand-color.webp   # Google Logo
├── baidu-brand-color.webp    # Baidu Logo
├── BingOct2020logo.svg       # Bing Logo
└── README.md
```

## 功能

| 功能 | 说明 |
|---|---|
| 搜索聚合 | 支持 Google / Bing / Baidu，回车搜索，`Alt + S` 循环切换；桌面端新标签打开，移动端当前页跳转 |
| 快捷站点 | 全部站点均可增删改、拖拽排序（需进入「⚙️ 管理」模式），改动自动保存 |
| 最近搜索 | 自动记录（最多 100 条，按名称去重），可重新搜索、删除、一键固定到快捷导航 |
| 备忘录 | 输入后自动保存到 localStorage，支持复制、清空、发送到邮箱 |
| 自定义背景 | 支持本地上传、网络图片 URL、纯色三种方式，可恢复默认 |
| 备份 / 恢复 | 导出 / 导入完整配置（含站点、背景、备忘录、搜索历史） |
| 设备信息 | 显示系统、电量、加载耗时、备忘录字数、公网 IP 与归属地 |

### 快捷键

| 按键 | 作用 |
|---|---|
| `Enter` | 在搜索框内回车，使用当前搜索引擎搜索 |
| `Alt + S` | 循环切换 Google → Bing → Baidu |

### 顶部按钮

| 按钮 | 作用 |
|---|---|
| `+ 添加站点` | 新增一个快捷站点 |
| `🖼️ 背景` | 设置背景（本地上传 / 网络图片 / 纯色 / 恢复默认） |
| `🔄 云同步` | 配置 GitHub 令牌并绑定本机 `data/sites.js`，开启站点数据永久保存 |
| `💾 备份` | 导出全部配置为 JSON 文件 |
| `📂 恢复` | 从备份文件导入配置 |
| `⚙️ 管理` | 进入编辑模式，显示站点的编辑 / 删除按钮，并启用拖拽排序 |

## 站点数据如何永久保存

站点的唯一数据源是 `data/sites.js`，三种保存方式任选：

| 方式 | 说明 | 适用场景 |
|---|---|---|
| **云同步（推荐）** | 页面右上角「🔄 云同步」填入 GitHub 令牌，之后添加/编辑/删除/排序站点都会自动提交到仓库 | 日常使用，多设备共享 |
| **手动复制代码** | 云同步弹窗底部「改为手动复制代码保存」，复制生成的内容覆盖 `data/sites.js` | 不想使用令牌 |
| **直接改文件** | 用编辑器直接修改 `data/sites.js` 并提交 | 批量整理站点 |

三种方式都指向同一个文件，因此换浏览器、换设备、清缓存都不会丢数据。

> 数据文件也可由服务端动态生成（例如 PHP/Node 输出同样的 `window.NAV_SITES = {...};`），这样即使不配置令牌，也能实现跨设备共享。

### 开启云同步

1. 打开 https://github.com/settings/personal-access-tokens/new
2. **Repository access** 只选 `Codivs-Ctrl/WebNavHub`
3. **Permissions → Repository permissions → Contents** 设为 **Read and write**（其余全部保持 No access）
4. 生成后复制令牌，粘贴到页面「🔄 云同步」中，点「测试连接」确认可用后保存

令牌只保存在本机浏览器的 localStorage，不会写入代码、不会提交到仓库，也不会随「备份」文件导出。

同步行为说明：

- 页面加载时优先从 GitHub 拉取最新数据（保证跨设备一致），失败则回退本地缓存与打包文件。
- 提交遇到 `409`（别处刚改过）会自动读取远端并合并后重试，不会覆盖掉别的设备新增的站点。
- 同步失败时数据仍会保存在本机，底部提示「⚠️ 同步失败，已存本地」，不会丢改动。

### 让本机 `data/sites.js` 也一起更新

云同步只负责仓库里的文件；**本机的 `data/sites.js` 不会自动跟着变**。有两种办法让两边同时更新：

**方式一：页面里绑定本机文件（推荐，实时双写）**

1. 用 Chrome / Edge（88+）打开页面。建议先用 `python -m http.server 5500` 起个本地服务，再访问 `http://localhost:5500`——`file://` 下浏览器会禁用本地文件写入能力。
2. 打开「🔄 云同步」→ 下方「💾 本机文件同步」→ 点「📎 绑定本机 data/sites.js」。
3. 在文件选择框里选中本仓库的 `data/sites.js`，浏览器会请求一次写入权限，允许即可。
4. 勾选「站点改动时自动写入本机文件」（授权成功时默认已勾选）。可点「✍️ 立即写入本机」把当前数据立刻写一次。

之后每次「添加 / 编辑 / 删除 / 拖拽排序」站点都会**同时**提交仓库并写入本机文件，底部状态会显示「☁️💾 已同步到仓库与本机 data/sites.js」。

说明：

- 本机文件写入使用 File System Access API，仅 Chrome / Edge 88+ 支持；Firefox / Safari 下该区块会提示不可用，其余功能不受影响。
- 文件句柄保存在浏览器 IndexedDB 中，刷新页面会自动恢复；若浏览器要求重新授权，点「🔓 授权写入」即可。
- 页面加载时若发现云端有更新，也会把最新数据一并写回已绑定的本机文件。
- 只写本机文件、不配令牌也可以（仅勾选本机文件同步）。

**方式二：用 `tools/sync-local.ps1` 从云端拉回（兜底）**

适合浏览器不支持、或希望无人值守同步的场景：

```powershell
# 拉回一次（本机文件会被云端覆盖，旧文件自动备份为 data/sites.js.bak）
powershell -ExecutionPolicy Bypass -File .\tools\sync-local.ps1

# 每 30 秒检查一次，云端有更新就写回本机（前台常驻，Ctrl+C 退出）
powershell -ExecutionPolicy Bypass -File .\tools\sync-local.ps1 -Watch

# 反向：本机文件有改动时提交并推送到仓库
powershell -ExecutionPolicy Bypass -File .\tools\sync-local.ps1 -Push

# 私有仓库需带令牌（Contents: Read and write），也可用环境变量 NAVHUB_TOKEN
powershell -ExecutionPolicy Bypass -File .\tools\sync-local.ps1 -Token github_pat_xxx
```

> 页面里的「本机文件同步」与脚本是两套独立通道，按需二选一即可；同时开启也不会冲突。

### `data/sites.js` 格式

```js
window.NAV_SITES = {
    "updatedAt": "2026-09-15T12:54:18.305Z",
    "categories": null,
    "sites": [
        { "id": 1001, "name": "Gemini", "url": "https://gemini.google.com", "icon": "", "remark": "Google 官方 AI 助手" }
    ]
};
```

- `id`：唯一编号，重复时页面会自动重新分配
- `icon`：可选，留空则自动获取站点图标
- `remark`：可选，鼠标悬停显示的备注
- `updatedAt`：由页面自动维护；手工改文件时建议一并修改，页面才能识别到变更

手工新增站点时，直接追加一项即可：

```js
{ "id": 2001, "name": "示例", "url": "https://example.com", "icon": "", "remark": "" }
```

> 手工编辑文件时请保持 JSON 语法正确（键用双引号、项之间用逗号）。若页面加载后发现站点没变化，检查 `updatedAt` 是否已更新。

## 配置（重要）

所有需要替换的参数都集中在 `index.html` 里 `<script>` 开头的 `CONFIG` 对象：

```js
const CONFIG = {
    // ipinfo.io 的 Access Token；留空则改用免鉴权接口（仅显示 IP，无归属地）
    // 申请：https://ipinfo.io/signup
    ipinfoToken: 'e529fa187290a6',

    // EmailJS；留空则自动隐藏「发送到邮箱」入口
    emailjs: {
        publicKey:   '3P1oxXvgHXRlgdSHu',   // Account → API Keys
        serviceId:   'service_erqf5v7',       // Email Services → Service ID
        templateId:  'template_9hmy1gr',      // Email Templates → Template ID
        targetEmail: '7533153@qq.com'         // 接收备忘录的邮箱
    },

    // GitHub 云同步默认仓库；令牌不写在这里，由页面「🔄 云同步」单独填写并保存在本机
    sync: {
        repo: 'Codivs-Ctrl/WebNavHub',
        branch: 'main',
        path: 'data/sites.js'
    }
};
```

> ⚠️ **前端代码无法真正保密**，上述 key 与收件邮箱对所有访客可见。务必完成下面两项：

1. **开启浏览器端 API 访问**
   EmailJS 后台 → `Account` → `Security` → 打开 *Allow API access from browser*（关闭时会返回 `403 API access from non-browser environments is currently disabled`）。

2. **配置域名白名单**
   同一页面 → `Allowed origins`，填入 `https://navhub.codivs.com`。这是 public key 暴露后唯一有效的防线。

若希望隐藏收件邮箱，需要改为后端代发（Cloudflare Worker / 云函数），前端只调用自己的接口。

## 数据结构

站点数据保存在 `data/sites.js`（见上文），其余数据保存在浏览器 localStorage：

| Key | 内容 |
|---|---|
| `cfg_vfinal_sites` | 站点缓存（与数据文件保持一致，供离线使用） |
| `cfg_vfinal_hist` | 最近搜索 `[{ id, name, url }]` |
| `cfg_vfinal_memo` | 备忘录 `{ content, lastModified }` |
| `cfg_vfinal_bg` / `cfg_vfinal_bg_type` | 自定义背景值 / 类型（`img` \| `color`） |
| `nav_usage_map` | 站点点击次数 `{ url: count }` |
| `cfg_github_sync` | 云同步配置 `{ repo, branch, token }`（令牌仅存本机） |
| `cfg_local_file_sync` | 本机文件同步开关与文件名 `{ enabled, name }`（文件句柄存于 IndexedDB） |
| `cfg_data_file_ts` | 已加载数据文件的时间戳，用于识别文件被手工改动 |

站点 id 建议保持唯一；`newId()` 生成的是 1e12 起的随机数，手工新增站点时沿用同样的量级即可避免冲突。

最近搜索、备忘器等本地数据换浏览器或清理缓存会丢失，建议定期用「💾 备份」导出。

## 常见问题

**Q：添加的站点显示「已存本地（云同步与本机文件同步均未开启）」，会丢吗？**

不会立刻丢，但**换浏览器、换设备或清理浏览器数据后会消失**，因为数据只在本机。要永久保存，按上面的「开启云同步」配置一次即可。

**Q：云同步里的改动确实进了仓库，为什么本机 `data/sites.js` 没变？**

云同步只写仓库文件，不会去动你磁盘上的文件（浏览器也没有这个权限）。要本机文件同时更新，见上文「让本机 `data/sites.js` 也一起更新」：在「🔄 云同步」里绑定本机文件，或用 `tools/sync-local.ps1` 拉回。

**Q：点「📎 绑定本机 data/sites.js」没有反应 / 提示浏览器不支持？**

需要 Chrome / Edge 88+，并且通过 `http://localhost` 或 `https://` 访问页面。若以 `file://` 双击打开，浏览器会禁掉本地文件写入能力——用 `python -m http.server 5500` 起个服务再访问即可；也可直接用 `tools/sync-local.ps1` 替代。

**Q：刷新页面后本机文件同步变成了「需重新绑定」？**

浏览器为安全起见会收回持久权限。点「🔓 授权写入」重新授权即可，文件句柄本身仍保存在浏览器中，无需重新选文件。

**Q：配置了云同步，但改动没进仓库？**

按提示排查：

| 提示 | 原因 | 处理 |
|---|---|---|
| ❌ 令牌无效（401） | 令牌复制不全或已过期 | 重新生成令牌 |
| ❌ 权限不足（403） | 令牌缺少 Contents 写权限 | 编辑令牌，Contents 设为 Read and write |
| ❌ 找不到文件（404） | 仓库名 / 分支名错误，或 `data/sites.js` 尚未推送 | 核对配置，先把 `data/` 推送到仓库 |
| ⚠️ 同步失败，已存本地 | 网络问题或接口异常 | 检查网络后，随便改一个站点再触发一次同步 |

**Q：手机上改了站点，电脑上能看到吗？**

能。页面加载时会先从仓库拉取最新数据。若两端同时修改，提交时会自动合并，不会覆盖对方新增的站点。

**Q：换设备后站点乱了 / 想恢复出厂设置？**

打开浏览器控制台（F12），执行：

```js
localStorage.clear(); location.reload();
```

页面会重新从 `data/sites.js` 载入。注意这会同时清掉备忘录与搜索历史，建议先用「💾 备份」导出。

**Q：不想用 GitHub 令牌，还能跨设备共享吗？**

可以。点「🔄 云同步」→ 底部「改为手动复制代码保存」，把生成的内容覆盖 `data/sites.js` 并提交即可。另外，数据文件也可以由服务端动态生成（PHP / Node 输出同样的 `window.NAV_SITES = {...};`），这样无需令牌也能共享。

**Q：站点图标显示不出来？**

默认使用 Google favicon 服务，部分站点不支持或需代理。可在站点编辑框的「图标URL」里填自己的图片地址（支持 `https://`、站内相对路径、`data:image`），加载失败时会自动降级为站点名首字母。

**Q：站点最多能放多少个？**

实测 5000 个（约 837KB）可正常同步。GitHub API 单文件上限 100MB，日常使用无需担心。

## 想改哪里？

| 需求 | 位置 |
|---|---|
| 站点列表 | `data/sites.js` |
| 搜索引擎、`CONFIG` 配置、渲染逻辑 | `index.html` 的 `<script>` 部分 |
| 页面样式（配色、尺寸、响应式） | `index.html` 的 `<style>` 部分 |
| 页面结构（顶部按钮、弹窗） | `index.html` 的 `<body>` 部分 |
| 默认背景图 | 替换 `image0.webp` |

修改后刷新页面即可生效，无需构建。

## 开发约定

- 所有渲染内容必须经过 `escapeHtml()`，图标走 `sanitizeIconUrl()`，网址走 `normalizeUrl()`（拒绝 `javascript:` 等协议）。
- 事件统一使用 `data-action` + 事件委托，**不要写内联 `onclick`**（避免字符串拼接导致的 XSS 与引号转义问题）。
- 读取 localStorage 一律通过 `readJSON(key, fallback)`，保证数据损坏时页面仍可渲染。
- 站点改动统一走 `persistSites()`（先写本地缓存，再尝试云端同步），不要直接操作 `localStorage`。
- 拖拽排序仅在 `body.edit-mode` 下启用。

## 部署

纯静态站点，将仓库推送到任意静态托管即可（Cloudflare Pages / Vercel / Netlify / GitHub Pages）。无需环境变量与构建命令。

> ⚠️ 部署时必须包含 `data/` 目录，否则页面会提示「未找到站点数据」。若使用 Cloudflare Pages，注意不要用 `.gitignore` 排除该目录。

### 部署到树莓派（自建服务器）

想在树莓派上跑这个导航页，可用 `tools/deploy-pi.sh` 一键部署：它会把仓库克隆到 `/opt/WebNavHub`，起一个静态服务，并注册 systemd 服务实现**开机自启 + 定时从 GitHub 拉取更新 + 崩溃自重启**。

**一键部署**

```bash
# 在树莓派上执行
cd ~
git clone https://github.com/Codivs-Ctrl/WebNavHub.git navhub-setup
cd navhub-setup
chmod +x tools/deploy-pi.sh
./tools/deploy-pi.sh
```

看到 `✅ 部署完成！` 后会打印访问地址，通常是 `http://<树莓派IP>:8080/`。常用参数：

```bash
./tools/deploy-pi.sh --port 80              # 换端口（80 需额外授权，见下）
./tools/deploy-pi.sh --dir ~/WebNavHub      # 换安装目录（默认 /opt/WebNavHub）
./tools/deploy-pi.sh --pull-interval 60     # 每 60 秒 git pull 一次（默认 300）
./tools/deploy-pi.sh --no-service           # 只准备文件，不装 systemd 服务
```

**它做了什么**

| 项目 | 说明 |
|---|---|
| 代码目录 | `/opt/WebNavHub`（已存在且是 git 仓库时自动更新，不会重复克隆） |
| 静态服务 | `python3 -m http.server 8080 --bind 0.0.0.0`，systemd 守护，`Restart=always` |
| 自动更新 | `navhub-pull.timer` 定时执行 `git pull --rebase --autostash`，网页上同步进仓库的改动会自动落到树莓派 |
| 开机自启 | 两个单元都已 `enable` |

**管理命令**

```bash
sudo systemctl status  navhub              # 查看服务状态
sudo systemctl restart navhub              # 重启
sudo journalctl -u navhub -f               # 实时日志

systemctl list-timers navhub-pull.timer    # 查看下次拉取时间
sudo systemctl start navhub-pull.service   # 立刻手动拉取一次
```

**端口与访问**

- 想让别的设备访问，树莓派防火墙需放行端口：`sudo ufw allow 8080/tcp`（或用 `sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT`）。
- 建议在路由器上给树莓派设**固定 IP**（或在 `raspi-config` 里配静态 IP），否则重启后地址可能变化。
- 想直接用 `http://<树莓派IP>/`（80 端口）访问，需要给 python 绑定低端口的权限：

  ```bash
  sudo setcap 'cap_net_bind_service=+ep' "$(readlink -f "$(command -v python3)")"
  ./tools/deploy-pi.sh --port 80
  ```

**提示**：树莓派上访问页面时，`http://<IP>:8080` 也是 `http://` 环境，所以「本机文件同步」可用——但请注意，此时写入的「本机文件」是**树莓派上**的 `data/sites.js`，与浏览器所在电脑的文件无关。

### 只同步数据文件（不做部署）

树莓派上已有一份代码，只想让它跟着仓库更新数据文件：

```bash
chmod +x tools/sync-local.sh

./tools/sync-local.sh                  # 拉取一次（旧文件备份为 data/sites.js.bak）
./tools/sync-local.sh --watch          # 每 30 秒检查一次
./tools/sync-local.sh --watch -i 10    # 自定义间隔（秒）
./tools/sync-local.sh --push           # 反向：本机改动提交并推送到仓库
NAVHUB_TOKEN=github_pat_xxx ./tools/sync-local.sh   # 私有仓库需带令牌
```

配合 cron 每 5 分钟拉一次（无需常驻进程）：

```bash
crontab -e
# 追加一行（路径换成你的实际路径）
*/5 * * * * cd /home/pi/WebNavHub && ./tools/sync-local.sh >> /tmp/navhub-sync.log 2>&1
```

| 变量 | 说明 | 默认值 |
|---|---|---|
| `NAVHUB_REPO` | 仓库 `owner/repo` | `Codivs-Ctrl/WebNavHub` |
| `NAVHUB_BRANCH` | 分支 | `main` |
| `NAVHUB_PATH` | 仓库内路径 | `data/sites.js` |
| `NAVHUB_LOCAL_FILE` | 本机写入路径 | 脚本上一级目录的 `data/sites.js` |
| `NAVHUB_TOKEN` | 私有仓库令牌（Contents 读权限即可） | 空 |


