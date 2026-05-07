#!/usr/bin/env python3
"""Shared helpers for ZenMux image generation scripts."""

from __future__ import annotations

import argparse
import base64
import os
import pathlib
import re
import sys
import urllib.request
from dataclasses import dataclass

GEMINI_PREFIX = "google/"
OPENAI_IMAGE_MODELS = {
    "openai/gpt-image-2",
    "openai/gpt-image-1.5",
    "gpt-image-2",
    "gpt-image-1.5",
}
ZENMUX_BASE_URL = "https://zenmux.ai/api/vertex-ai"
ZENMUX_OPENAI_BASE_URL = "https://zenmux.ai/api/v1"


def slugify(value: str, max_len: int = 40) -> str:
    """Filesystem-safe slug derived from a model name."""
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", value).strip("-")
    return slug[:max_len] or "image"


def load_prompt(path: pathlib.Path) -> str:
    """Read a prompt file and strip the human metadata header if present."""
    text = path.read_text(encoding="utf-8")
    parts = re.split(r"(?m)^---\s*$", text, maxsplit=1)
    body = parts[1] if len(parts) == 2 else parts[0]
    body = body.strip()
    if not body:
        raise SystemExit(f"Error: prompt file '{path}' is empty after stripping metadata.")
    return body


_MIME_BY_EXT = {
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "webp": "image/webp",
    "heic": "image/heic",
    "heif": "image/heif",
    "gif": "image/gif",
    "bmp": "image/bmp",
}


@dataclass(frozen=True)
class ReferenceImage:
    raw: str
    data: bytes
    mime_type: str


def _local_reference_path(raw: str) -> pathlib.Path:
    lower = raw.lower()
    if lower.startswith("file://"):
        raw = raw[7:]
        if not raw.startswith("/") and "/" in raw:
            raw = "/" + raw.split("/", 1)[1]

    path = pathlib.Path(raw).expanduser()
    if not path.is_absolute():
        path = (pathlib.Path.cwd() / path).resolve()
    return path


def fetch_reference_image(ref: str, *, allow_data_url: bool = False) -> ReferenceImage:
    """Load reference-image bytes from a local path, file URL, data URL, or URL."""
    raw = ref.strip().strip('"').strip("'")
    lower = raw.lower()

    if allow_data_url and lower.startswith("data:image/"):
        header, _, b64_data = raw.partition(",")
        mime = header.removeprefix("data:").split(";", 1)[0] or "image/png"
        try:
            data = base64.b64decode(b64_data)
        except Exception as exc:  # noqa: BLE001 - script entrypoint needs a clear error
            raise SystemExit(f"Error: invalid data URL reference image: {exc}") from exc
        if not data:
            raise SystemExit("Error: data URL reference image is empty.")
        return ReferenceImage(raw=raw, data=data, mime_type=mime)

    if lower.startswith("http://") or lower.startswith("https://"):
        try:
            with urllib.request.urlopen(raw, timeout=30) as resp:  # noqa: S310
                data = resp.read()
                mime = resp.headers.get_content_type() or "image/png"
        except Exception as exc:  # noqa: BLE001 - any network/parse failure is user-actionable
            raise SystemExit(
                f"Error: failed to download reference image '{raw}': {exc}\n"
                f"Hint: confirm the URL is reachable and returns an image."
            ) from exc
        if not data:
            raise SystemExit(f"Error: reference URL returned 0 bytes: {raw}")
        return ReferenceImage(raw=raw, data=data, mime_type=mime)

    path = _local_reference_path(raw)
    if not path.exists():
        raise SystemExit(
            f"Error: reference image not found: {ref}\n"
            f"Resolved to: {path}\n"
            f"Hint: pass an absolute path, an http(s) URL, or a path relative to {pathlib.Path.cwd()}."
        )
    if not path.is_file():
        raise SystemExit(f"Error: reference path is not a regular file: {path}")

    suffix = path.suffix.lower().lstrip(".")
    mime = _MIME_BY_EXT.get(suffix, "image/png")
    if suffix and suffix not in _MIME_BY_EXT:
        sys.stderr.write(
            f"Warning: unknown image extension '.{suffix}' for {path}; "
            f"sending as image/png. Convert to PNG/JPEG/WebP if the model rejects it.\n"
        )

    try:
        data = path.read_bytes()
    except OSError as exc:
        raise SystemExit(f"Error: cannot read reference image {path}: {exc}") from exc
    if not data:
        raise SystemExit(f"Error: reference file is empty: {path}")
    return ReferenceImage(raw=ref, data=data, mime_type=mime)


def reference_bytes(refs: list[ReferenceImage]) -> list[tuple[bytes, str]]:
    return [(ref.data, ref.mime_type) for ref in refs]


def ensure_output_dir(path: pathlib.Path) -> pathlib.Path:
    path.mkdir(parents=True, exist_ok=True)
    return path


def make_filename(model: str, ext: str, idx: int, run_ts: str) -> str:
    return f"{slugify(model)}-{run_ts}-{idx:02d}.{ext}"


def ext_from_mime(mime: str | None, default: str = "png") -> str:
    if not mime:
        return default
    return {
        "image/png": "png",
        "image/jpeg": "jpg",
        "image/webp": "webp",
    }.get(mime.lower(), default)


def openai_output_format(output_format: str | None) -> str | None:
    if not output_format:
        return None
    return {
        "image/png": "png",
        "image/jpeg": "jpeg",
        "image/webp": "webp",
    }.get(output_format, output_format)


def mime_from_openai_format(output_format: str | None) -> str:
    fmt = openai_output_format(output_format) or "png"
    return {
        "png": "image/png",
        "jpeg": "image/jpeg",
        "jpg": "image/jpeg",
        "webp": "image/webp",
    }.get(fmt, "image/png")


def is_openai_image_model(model: str) -> bool:
    return model in OPENAI_IMAGE_MODELS


def add_common_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--model", required=True, help="ZenMux model id.")
    parser.add_argument(
        "--prompt-file",
        required=True,
        type=pathlib.Path,
        help="Path to a prompt file. Metadata above a standalone '---' is stripped.",
    )
    parser.add_argument("--output-dir", required=True, type=pathlib.Path, help="Directory to save images.")
    parser.add_argument("--n", type=int, default=4, help="Number of images to generate, 1-10.")
    parser.add_argument("--size", default=None, help="Image size, e.g. 1024x1024 or 1536x1024.")
    parser.add_argument("--quality", default=None, choices=["low", "medium", "high", "auto"])
    parser.add_argument(
        "--output-format",
        default=None,
        choices=["image/png", "image/jpeg", "image/webp"],
        help="Output MIME type. Defaults to the provider/model default.",
    )
    parser.add_argument("--compression", type=int, default=None, help="Compression quality 0-100.")
    parser.add_argument(
        "--reference-image",
        action="append",
        default=[],
        help="Path, URL, or data URL to a reference image. Repeat for multiple references.",
    )
    parser.add_argument("--mask-image", default=None, help="Optional mask image path or URL for image edits.")
    parser.add_argument(
        "--api-key-env",
        default="ZENMUX_API_KEY",
        help="Environment variable holding the ZenMux API key.",
    )


def require_api_key(env_name: str) -> str:
    api_key = os.environ.get(env_name)
    if not api_key:
        raise SystemExit(
            f"Error: environment variable {env_name} is not set.\n"
            f"Export your ZenMux API key:  export {env_name}=..."
        )
    return api_key


def validate_n(n: int) -> None:
    if n < 1 or n > 10:
        raise SystemExit("Error: --n must be between 1 and 10 (inclusive).")


def validate_compression(value: int | None) -> None:
    if value is not None and (value < 0 or value > 100):
        raise SystemExit("Error: --compression must be between 0 and 100.")


def print_saved(saved: list[pathlib.Path]) -> None:
    if not saved:
        raise SystemExit("Error: no images were saved.")
    print(f"\nSaved {len(saved)} image(s):")
    for path in saved:
        print(f"  {path}")
