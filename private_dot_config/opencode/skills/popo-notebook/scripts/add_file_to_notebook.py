#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把本地文件添加到 POPO 知识本。

本脚本只直接 HTTP PUT 文件二进制到上传地址。所有知识本接口都必须通过
``popo-cli popo`` 调用，以复用 popo-cli 的登录态、网关和鉴权：

1. ``popo-cli popo notebook_file_upload_url``：申请预签名 PUT 地址
2. HTTP PUT：把文件二进制上传到外部存储服务
3. ``popo-cli popo notebook_file_confirm``：确认上传并取得下载地址
4. ``popo-cli popo notebook_add_attachment``：按 attachment 类型添加到知识本

支持多文件批量：所有文件均完成上传和确认后，再一次性添加文章。任一文件失败则
不执行最后的批量入库。

脚本不在本地限制文件数量、扩展名、MIME 类型或大小；这些规则由服务端决定。
脚本会根据文件扩展名识别 MIME 类型；未知扩展名回退为 `application/octet-stream`，仍然交给服务端决定是否支持。
服务端或 popo-cli 出错时，脚本保留错误内容并结构化输出，交给加载本 Skill 的模型
解释后再向用户反馈，不在脚本中猜测错误含义。

仅依赖 Python3 标准库（3.8+），无需 pip 安装。

直接运行（用于本地调试）
------------------------
python add_file_to_notebook.py --kb-id 123456 --file "D:\\docs\\需求设计文档.pdf"
python add_file_to_notebook.py --kb-id 123456 --file a.pdf --file b.docx
python add_file_to_notebook.py --params-file params.json
python add_file_to_notebook.py --kb-id 123456 --file a.pdf --dry-run

生产环境由 skill 直接唤起本脚本；不要把
服务地址、用户 ID 或 token 写入脚本。popo-cli 负责这些配置。

参数文件格式（直接运行脚本调试，UTF-8 无 BOM）
-----------------------------------------------
{
  "knowledgeBaseId": 123456,
  "files": [
    {"path": "D:\\docs\\需求设计文档.pdf", "title": "需求设计文档"},
    {"path": "D:\\docs\\会议纪要.docx"}
  ]
}

输出
----
统一输出单行 JSON，与 popo-cli 的响应约定对齐。失败时保留 `rawError`，供 Skill 加载后的
模型理解并转换为用户可读的语义，不要直接把原始错误原样展示给用户：
成功 {"status": 1, "message": "ok", "data": [{"articleId":.., "title":.., "url":.., "file":..}]}
失败 {"status": 0, "message": "...", "stage": "...", "file": "...", "rawError": "..."}
成功退出码 0，失败退出码 1。
"""

import argparse
import json
import mimetypes
import os
import re
import shutil
import ssl
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

# popo-cli 内部命令。它们对应知识本服务的上传地址、确认和 attachment 入库接口。
UPLOAD_URL_TOOL = "notebook_file_upload_url"
CONFIRM_TOOL = "notebook_file_confirm"
ADD_ATTACHMENT_TOOL = "notebook_add_attachment"

# 本地文件没有浏览器 File.type，按扩展名提供与前端一致的 MIME 识别结果。
# 这只是请求元信息推断，不是支持类型白名单；未收录的扩展名继续走 mimetypes/二进制兜底并交给服务端判断。
EXTENSION_MIME_MAP = {
    "md": "text/markdown",
    "markdown": "text/markdown",
    "mdown": "text/markdown",
    "mkd": "text/markdown",
    "txt": "text/plain",
    "text": "text/plain",
    "log": "text/plain",
    "srt": "application/x-subrip",
    "csv": "text/csv",
    "tsv": "text/tab-separated-values",
    "rtf": "application/rtf",
    "html": "text/html",
    "htm": "text/html",
    "css": "text/css",
    "js": "application/javascript",
    "mjs": "application/javascript",
    "json": "application/json",
    "xml": "application/xml",
    "svg": "image/svg+xml",
    "yaml": "text/yaml",
    "yml": "text/yaml",
    "toml": "application/toml",
    "pdf": "application/pdf",
    "doc": "application/msword",
    "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "xls": "application/vnd.ms-excel",
    "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "ppt": "application/vnd.ms-powerpoint",
    "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "png": "image/png",
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "gif": "image/gif",
    "webp": "image/webp",
    "bmp": "image/bmp",
    "ico": "image/x-icon",
    "tiff": "image/tiff",
    "tif": "image/tiff",
    "mp3": "audio/mpeg",
    "wav": "audio/wav",
    "ogg": "audio/ogg",
    "flac": "audio/flac",
    "aac": "audio/aac",
    "m4a": "audio/mp4",
    "wma": "audio/x-ms-wma",
    "mp4": "video/mp4",
    "webm": "video/webm",
    "avi": "video/x-msvideo",
    "mov": "video/quicktime",
    "mkv": "video/x-matroska",
    "wmv": "video/x-ms-wmv",
    "zip": "application/zip",
    "gz": "application/gzip",
    "tar": "application/x-tar",
    "rar": "application/vnd.rar",
    "7z": "application/x-7z-compressed",
    "py": "text/x-python",
    "rb": "text/x-ruby",
    "java": "text/x-java-source",
    "c": "text/x-c",
    "cpp": "text/x-c++src",
    "h": "text/x-c",
    "go": "text/x-go",
    "rs": "text/x-rustsrc",
    "ts": "text/typescript",
    "tsx": "text/tsx",
    "jsx": "text/jsx",
    "sh": "application/x-sh",
    "sql": "application/sql",
    "php": "application/x-httpd-php",
}

CLI_TIMEOUT_SECONDS = 60
UPLOAD_TIMEOUT_SECONDS = 600
RETRY_TIMES = 1
RETRY_INTERVAL_SECONDS = 2


class SkillError(Exception):
    """带阶段信息的可读错误，直接映射为脚本输出。"""

    def __init__(self, message, stage, file=None, raw_error=None):
        super().__init__(message)
        self.message = message
        self.stage = stage
        self.file = file
        self.raw_error = raw_error or message


def resolve_popo_cli(args):
    """定位 popo-cli；Windows 下兼容 PATH 中的 popo-cli.ps1。"""
    configured = args.popo_cli or os.environ.get("POPO_CLI_BIN", "popo-cli")
    candidates = [configured]
    if os.name == "nt" and not Path(configured).suffix:
        candidates.extend([configured + ".ps1", configured + ".cmd", configured + ".exe"])

    for candidate in candidates:
        resolved = shutil.which(candidate)
        if resolved:
            path = Path(resolved)
            if path.suffix.lower() == ".ps1":
                return [
                    "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(path)
                ]
            return [str(path)]

        direct = Path(candidate).expanduser()
        if direct.is_file():
            if direct.suffix.lower() == ".ps1":
                return [
                    "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(direct)
                ]
            return [str(direct)]

    raise SkillError(
        "找不到 popo-cli：请确认 popo-cli 已安装并已加入 PATH，或设置 POPO_CLI_BIN",
        "preflight",
    )


def run_popo_tool(cli_command, tool, params, stage, file=None):
    """通过 popo-cli 调用知识本接口，不直接请求知识本 HTTP API。"""
    with tempfile.TemporaryDirectory(prefix="popo_nb_") as temp_dir:
        argv = list(cli_command) + ["popo", tool]
        for key, value in params.items():
            argv.append("%s=%s" % (key, encode_cli_value(key, value, Path(temp_dir))))

        try:
            completed = subprocess.run(
                argv,
                capture_output=True,
                timeout=CLI_TIMEOUT_SECONDS,
                check=False,
            )
        except FileNotFoundError:
            raise SkillError("无法启动 popo-cli，请确认其已安装并已加入 PATH", "preflight", file)
        except subprocess.TimeoutExpired:
            raise SkillError("popo-cli 调用超时: %s" % tool, stage, file)
        except OSError as exc:
            raise SkillError("启动 popo-cli 失败: %s" % exc, stage, file)

        stdout = decode_cli_output(completed.stdout)
        stderr = decode_cli_output(completed.stderr)
        response = parse_cli_response(stdout)

        if completed.returncode != 0:
            detail = collect_message(response) if isinstance(response, dict) else None
            detail = detail or stderr.strip() or stdout.strip() or "无错误详情"
            raw_error = json.dumps(response, ensure_ascii=False) if response else (stderr or stdout)
            raise SkillError(detail, stage, file, raw_error=raw_error.strip() or detail)

        if not isinstance(response, dict):
            detail = "popo-cli 未返回合法 JSON: (empty)"
            raise SkillError(detail, stage, file, raw_error=stdout.strip() or detail)

        raw_error = json.dumps(response, ensure_ascii=False)
        if response.get("ok") is False:
            detail = collect_message(response) or "popo-cli 返回失败"
            raise SkillError(detail, stage, file, raw_error=raw_error)

        payload = extract_business_payload(response)
        if payload is None:
            detail = collect_message(response) or "popo-cli 响应缺少业务结果"
            raise SkillError(detail, stage, file, raw_error=raw_error)
        if payload.get("status") != 1:
            detail = payload.get("message") or collect_message(response) or "popo-cli 返回失败"
            raise SkillError(detail, stage, file, raw_error=raw_error)
        return payload.get("data")


def extract_business_payload(response):
    """popo-cli 会把下游响应层层包在 data 里，向内找到带 status 的业务体。

    实际输出形如：
    {"ok":true,"code":"FABRIC_OK","data":{"code":..,"data":{"code":..,"message":..,
      "data":{"status":1,"message":"成功","data":{...}}}}}
    """
    node = response
    for _ in range(10):
        if not isinstance(node, dict):
            return None
        if isinstance(node.get("status"), int):
            return node
        node = node.get("data")
    return None


def collect_message(response):
    """从嵌套响应里取最内层的可读错误信息。"""
    message = None
    node = response
    for _ in range(10):
        if not isinstance(node, dict):
            break
        if isinstance(node.get("message"), str) and node["message"].strip():
            message = node["message"].strip()
        node = node.get("data")
    return message


def decode_cli_output(raw):
    """优先 UTF-8，兼容 Windows PowerShell/native CLI 的系统编码输出。"""
    if isinstance(raw, str):
        return raw
    for encoding in ("utf-8", "gb18030", "mbcs"):
        try:
            return raw.decode(encoding)
        except (UnicodeDecodeError, LookupError):
            continue
    return raw.decode("utf-8", "replace")


def encode_cli_value(key, value, temp_dir):
    """按 popo-cli 约定编码参数，避免 shell 引号和中文路径问题。"""
    if isinstance(value, (list, dict)):
        path = temp_dir / ("%s.json" % key)
        path.write_text(json.dumps(value, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        return "@file:%s" % path

    # filename 可能包含中文、空格或特殊字符，使用 @text: 让 popo-cli 原样读取。
    if key in {"filename", "title"}:
        path = temp_dir / ("%s.txt" % key)
        path.write_text(str(value), encoding="utf-8")
        return "@text:%s" % path

    return str(value)


def parse_cli_response(raw):
    """解析 popo-cli 输出，兼容 stdout 中夹带少量日志的情况。"""
    text = raw.strip()
    if not text:
        return None

    candidates = [text]
    candidates.extend(reversed([line.strip() for line in text.splitlines() if line.strip()]))
    decoder = json.JSONDecoder()
    for candidate in candidates:
        try:
            value = json.loads(candidate)
            if isinstance(value, dict):
                return value
        except ValueError:
            pass

    # 兼容日志前缀 + 多行 JSON。
    for match in re.finditer(r"[\[{]", text):
        try:
            value, _ = decoder.raw_decode(text[match.start():])
            if isinstance(value, dict):
                return value
        except ValueError:
            continue
    return None


def put_file(upload_url, path, mime_type, size, file):
    """仅将文件二进制 PUT 到外部存储预签名地址。

    每次尝试都重新打开文件；直接复用同一个流会在重试时读到 EOF，导致上传空内容。
    """
    def build_request():
        stream = path.open("rb")
        return urllib.request.Request(
            upload_url,
            data=stream,
            method="PUT",
            headers={"Content-Type": mime_type, "Content-Length": str(size)},
        ), stream

    send_external_http(build_request, UPLOAD_TIMEOUT_SECONDS, file)


def build_ssl_context():
    """构造 HTTPS 上下文。

    macOS 自带/官方安装的 Python 常缺少根证书，默认上下文会报
    CERTIFICATE_VERIFY_FAILED。优先使用 certifi 提供的 CA bundle；
    也允许通过 POPO_CA_BUNDLE 指定，或 POPO_SKIP_SSL_VERIFY=1 跳过校验。
    """
    if os.environ.get("POPO_SKIP_SSL_VERIFY") == "1":
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        return context

    ca_bundle = os.environ.get("POPO_CA_BUNDLE")
    if not ca_bundle:
        try:
            import certifi  # noqa: PLC0415 - 可选依赖，缺失时回退默认上下文
            ca_bundle = certifi.where()
        except ImportError:
            ca_bundle = None

    if ca_bundle and Path(ca_bundle).is_file():
        try:
            return ssl.create_default_context(cafile=ca_bundle)
        except OSError:
            pass
    return ssl.create_default_context()


def send_external_http(build_request, timeout, file):
    """向外部存储服务发 HTTP 请求；不用于任何知识本接口。"""
    context = build_ssl_context()
    last_error = None
    for attempt in range(RETRY_TIMES + 1):
        request, stream = build_request()
        try:
            with urllib.request.urlopen(request, timeout=timeout, context=context) as response:
                return response.read()
        except urllib.error.HTTPError as exc:
            detail = _read_error_body(exc)
            last_error = "HTTP %s %s" % (exc.code, detail)
            if exc.code < 500:
                break
        except urllib.error.URLError as exc:
            last_error = "网络异常: %s" % exc.reason
        except OSError as exc:
            last_error = "IO 异常: %s" % exc
        finally:
            if stream is not None:
                stream.close()
        if attempt < RETRY_TIMES:
            time.sleep(RETRY_INTERVAL_SECONDS)
    raise SkillError(last_error or "请求失败", "upload", file, raw_error=last_error)


def _read_error_body(exc):
    try:
        return exc.read().decode("utf-8", "replace")[:500]
    except Exception:  # noqa: BLE001 - 读取错误体失败不应掩盖原始 HTTP 错误
        return exc.reason


def preflight(entries):
    """校验本地路径并准备文件元信息；数量、类型、大小交给服务端校验。"""
    if not entries:
        raise SkillError("至少需要一个文件：用 --file 指定，或用 --params-file 提供 files", "preflight")

    prepared = []
    for entry in entries:
        raw_path = entry.get("path", "")
        if not str(raw_path).strip():
            raise SkillError("文件路径不能为空", "preflight")

        path = Path(os.path.expandvars(str(raw_path))).expanduser()
        display = str(path)
        if not path.exists():
            raise SkillError("文件不存在: %s" % display, "preflight", display)
        if not path.is_file():
            raise SkillError("不是文件: %s" % display, "preflight", display)

        size = path.stat().st_size
        mime_type = resolve_mime_type(path, display)
        title = entry.get("title")
        prepared.append({
            "path": path,
            "display": display,
            "filename": path.name,
            "fileSize": size,
            "mimeType": mime_type,
            "title": title.strip() if isinstance(title, str) and title.strip() else path.name,
        })
    return prepared


def resolve_mime_type(path, display):
    """识别 MIME，不用本地白名单限制文件类型。"""
    extension = path.suffix.lower().lstrip(".")
    if extension in EXTENSION_MIME_MAP:
        return EXTENSION_MIME_MAP[extension]
    guessed, _ = mimetypes.guess_type(path.name, strict=False)
    return guessed or "application/octet-stream"


def load_params(args):
    """合并参数文件与命令行参数，命令行参数优先。"""
    kb_id = args.kb_id
    entries = [{"path": item, "title": None} for item in (args.file or [])]

    if args.params_file:
        params_path = Path(args.params_file).expanduser()
        if not params_path.is_file():
            raise SkillError("参数文件不存在: %s" % params_path, "preflight")
        try:
            params = json.loads(params_path.read_text(encoding="utf-8"))
        except ValueError as exc:
            raise SkillError("参数文件不是合法 JSON: %s" % exc, "preflight")
        if not isinstance(params, dict):
            raise SkillError("参数文件根节点必须是 JSON 对象", "preflight")

        kb_id = kb_id or params.get("knowledgeBaseId")
        for item in params.get("files") or []:
            if isinstance(item, str):
                entries.append({"path": item, "title": None})
            elif isinstance(item, dict):
                entries.append({"path": item.get("path"), "title": item.get("title")})
            else:
                raise SkillError("files 元素必须是字符串或对象", "preflight")

    if kb_id is None:
        raise SkillError("缺少知识本 ID：传 --kb-id 或在参数文件中提供 knowledgeBaseId", "preflight")
    try:
        kb_id = int(kb_id)
    except (TypeError, ValueError):
        raise SkillError("知识本 ID 必须是整数，当前为 %r" % kb_id, "preflight")
    return kb_id, entries


def run(args):
    kb_id, entries = load_params(args)
    files = preflight(entries)
    if args.dry_run:
        return [{
            "file": item["display"],
            "filename": item["filename"],
            "fileSize": item["fileSize"],
            "mimeType": item["mimeType"],
            "title": item["title"],
        } for item in files]

    cli_command = resolve_popo_cli(args)
    attachments = []

    # 上传地址和确认都走 popo-cli；只有 PUT 文件二进制走外部 HTTP。
    for item in files:
        upload = run_popo_tool(
            cli_command,
            UPLOAD_URL_TOOL,
            {
                "knowledgeBaseId": kb_id,
                "filename": item["filename"],
                "fileSize": item["fileSize"],
                "mimeType": item["mimeType"],
            },
            "upload-url",
            item["display"],
        ) or {}

        upload_url = upload.get("uploadUrl")
        object_key = upload.get("objectKey")
        if not upload_url or not object_key:
            raise SkillError("上传地址响应缺少 uploadUrl/objectKey", "upload-url", item["display"])

        put_file(upload_url, item["path"], item["mimeType"], item["fileSize"], item["display"])

        confirmed = run_popo_tool(
            cli_command,
            CONFIRM_TOOL,
            {
                "knowledgeBaseId": kb_id,
                "objectKey": object_key,
                "filename": item["filename"],
                "fileSize": item["fileSize"],
                "mimeType": item["mimeType"],
            },
            "confirm",
            item["display"],
        ) or {}

        download_url = confirmed.get("downloadUrl")
        if not download_url:
            raise SkillError("文件确认响应缺少 downloadUrl", "confirm", item["display"])
        attachments.append({
            "url": download_url,
            "name": item["title"],
            "mimeType": confirmed.get("mimeType") or item["mimeType"],
            "fileSize": confirmed.get("fileSize") or item["fileSize"],
            "linkType": "attachment",
        })

    articles = run_popo_tool(
        cli_command,
        ADD_ATTACHMENT_TOOL,
        {"knowledgeBaseId": kb_id, "items": attachments},
        "ingest",
    ) or []

    results = []
    for index, article in enumerate(articles):
        entry = dict(article)
        if index < len(files):
            entry["file"] = files[index]["display"]
        results.append(entry)
    return results


def build_parser():
    parser = argparse.ArgumentParser(
        description="把本地文件添加到 POPO 知识本（popo-cli 申请/确认/入库，HTTP PUT 文件）")
    parser.add_argument("--kb-id", type=int, help="知识本 ID")
    parser.add_argument("--file", action="append", help="本地文件路径，可重复传入实现批量")
    parser.add_argument("--params-file", help="JSON 参数文件路径，支持自定义标题")
    parser.add_argument("--popo-cli", help="popo-cli 可执行文件路径，覆盖 POPO_CLI_BIN")
    parser.add_argument("--dry-run", action="store_true", help="只做本地预检，不发起任何网络请求")
    return parser


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    args = build_parser().parse_args()
    try:
        data = run(args)
    except SkillError as exc:
        payload = {"status": 0, "message": exc.message, "stage": exc.stage, "rawError": exc.raw_error}
        if exc.file:
            payload["file"] = exc.file
        print(json.dumps(payload, ensure_ascii=False))
        return 1

    print(json.dumps({"status": 1, "message": "ok", "data": data}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
