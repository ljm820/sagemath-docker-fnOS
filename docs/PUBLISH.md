# 发布到 GitHub（PAT 认证）

本项目通过 GitHub **Personal Access Token (PAT)** 推送到私人仓库：

```
仓库地址 : https://github.com/ljm820/sagemath-docker-fnOS
认证方式 : PAT (fine-grained 或 classic, 需要 repo 写权限)
```

> 安全提示：PAT 属于敏感凭据。请勿将其写入任何会被提交的文件
> （`.env`、脚本、文档）。仅用于推送命令或本机 git 凭据存储。

## 1. 创建私人仓库（GitHub 网页或 API）

在 GitHub 新建私有仓库 `sagemath-docker-fnOS`（不要勾选添加 README，避免冲突）。

或使用 API 创建：

```bash
curl -s -X POST -H "Authorization: Bearer $PAT" \
  -d '{"name":"sagemath-docker-fnOS","private":true}' \
  https://api.github.com/user/repos
```

## 2. 本地推送（PAT 方式）

```bash
# 2.1 进入项目目录
cd sagemath-docker-fnOS

# 2.2 配置提交身份（第一次）
git config user.name "ljm820"
git config user.email "ljmjjy0820@126.com"

# 2.3 添加远程仓库（用 PAT 作为密码, 或使用凭据助手）
git remote add origin https://github.com/ljm820/sagemath-docker-fnOS.git

# 2.4 推荐：使用 git 凭据助手, 避免 token 明文出现在仓库配置中
# 方式 A（一次性, token 不进仓库文件）:
git -c credential.helper="!f() { echo username=ljm820; echo password=$PAT; }; f" \
  push -u origin main

# 方式 B（使用 GitHub CLI 登录）:
# gh auth login --with-token <<< "$PAT" && gh repo create ljm820/sagemath-docker-fnOS --private --source . --push
```

> `main` 为默认分支名；如仓库默认分支为 `master`，把 `-u origin main` 改为
> `-u origin master`。

## 3. 验证发布

```bash
# 本地确认远程状态
git status
git log --oneline -5

# 远程确认
curl -s -H "Authorization: Bearer $PAT" \
  https://api.github.com/repos/ljm820/sagemath-docker-fnOS \
  | grep -E '"private"|"default_branch"|"html_url"'
```

浏览器确认：https://github.com/ljm820/sagemath-docker-fnOS

## 4. 后续更新流程

```bash
git add -A
git commit -m "feat: ..."
git push
```

## 5. 秘钥泄漏应急

若 PAT 意外泄漏（发送到聊天、提交到仓库），立即到 GitHub
Settings -> Developer settings -> Personal access tokens 撤销并重新生成，
然后更新本机凭据。
