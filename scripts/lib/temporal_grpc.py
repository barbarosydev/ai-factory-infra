#!/usr/bin/env python3
"""Minimal, zero-dependency Temporal gRPC worker helper over HTTP/2 (h2c).

Used by `tests/smoke/temporal.sh` (`task smoke:temporal` and `task doctor`) to poll
a workflow task on `localhost:7233` from the Mac and complete it with a JSON payload,
without requiring an external Python virtualenv or the `temporalio` / `grpcio` wheels.

Standard library only ( plus `curl --http2-prior-knowledge` for h2c transport).
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile

SERVICE_PATH = "temporal.api.workflowservice.v1.WorkflowService"
COMMAND_TYPE_COMPLETE_WORKFLOW_EXECUTION = 4
TASK_QUEUE_KIND_NORMAL = 1


def encode_varint(n: int) -> bytes:
    """Encode a non-negative integer as a Protobuf base-128 varint."""
    if n < 0:
        raise ValueError(f"varint must be non-negative, got {n}")
    out = bytearray()
    while n > 0x7F:
        out.append((n & 0x7F) | 0x80)
        n >>= 7
    out.append(n)
    return bytes(out)


def decode_varint(buf: bytes, pos: int = 0) -> tuple[int, int]:
    """Decode a Protobuf varint starting at `pos`, returning `(value, next_pos)`."""
    val = 0
    shift = 0
    while pos < len(buf):
        b = buf[pos]
        pos += 1
        val |= (b & 0x7F) << shift
        if not (b & 0x80):
            return val, pos
        shift += 7
        if shift >= 64:
            raise ValueError("varint overflow")
    raise ValueError("truncated varint")


def field_varint(field_num: int, val: int) -> bytes:
    """Encode a Protobuf varint field (wire type 0)."""
    return encode_varint((field_num << 3) | 0) + encode_varint(val)


def field_bytes(field_num: int, data: bytes | str) -> bytes:
    """Encode a length-delimited Protobuf field (wire type 2)."""
    raw = data.encode("utf-8") if isinstance(data, str) else data
    return encode_varint((field_num << 3) | 2) + encode_varint(len(raw)) + raw


def pack_grpc_frame(message: bytes) -> bytes:
    """Wrap a serialized Protobuf message in a 5-byte uncompressed gRPC frame."""
    return b"\x00" + len(message).to_bytes(4, "big") + message


def unpack_grpc_frame(frame: bytes) -> bytes:
    """Extract the serialized Protobuf message from a 5-byte gRPC frame."""
    if len(frame) < 5:
        raise ValueError(f"gRPC frame too short ({len(frame)} bytes)")
    compressed = frame[0]
    if compressed != 0:
        raise ValueError(f"compressed gRPC frames not supported (flag={compressed})")
    msg_len = int.from_bytes(frame[1:5], "big")
    if len(frame) < 5 + msg_len:
        raise ValueError(f"truncated gRPC frame: expected {5 + msg_len} bytes, got {len(frame)}")
    return frame[5 : 5 + msg_len]


def build_poll_workflow_task_request(namespace: str, task_queue: str, identity: str) -> bytes:
    """Build `PollWorkflowTaskQueueRequest` (namespace=1, task_queue=2, identity=3)."""
    tq_msg = field_bytes(1, task_queue) + field_varint(2, TASK_QUEUE_KIND_NORMAL)
    return field_bytes(1, namespace) + field_bytes(2, tq_msg) + field_bytes(3, identity)


def extract_task_token(poll_response: bytes) -> bytes:
    """Extract field 1 (`task_token`) from `PollWorkflowTaskQueueResponse`."""
    pos = 0
    while pos < len(poll_response):
        tag, pos = decode_varint(poll_response, pos)
        field_num, wire_type = tag >> 3, tag & 7
        if wire_type == 0:
            _, pos = decode_varint(poll_response, pos)
        elif wire_type == 1:
            pos += 8
        elif wire_type == 2:
            ln, pos = decode_varint(poll_response, pos)
            val = poll_response[pos : pos + ln]
            pos += ln
            if field_num == 1:
                return val
        elif wire_type == 5:
            pos += 4
        else:
            raise ValueError(f"unsupported protobuf wire type {wire_type}")
    return b""


def build_complete_workflow_task_request(
    namespace: str,
    task_token: bytes,
    identity: str,
    result_json: str,
) -> bytes:
    """Build `RespondWorkflowTaskCompletedRequest` with `COMPLETE_WORKFLOW_EXECUTION`."""
    meta = field_bytes(1, "encoding") + field_bytes(2, "json/plain")
    payload = field_bytes(1, meta) + field_bytes(2, result_json)
    payloads = field_bytes(1, payload)
    complete_attrs = field_bytes(1, payloads)
    cmd = field_varint(1, COMMAND_TYPE_COMPLETE_WORKFLOW_EXECUTION) + field_bytes(4, complete_attrs)
    return (
        field_bytes(1, task_token)
        + field_bytes(2, cmd)
        + field_bytes(3, identity)
        + field_bytes(9, namespace)
    )


def parse_grpc_status(headers_text: str) -> tuple[int, str]:
    """Parse `grpc-status` and `grpc-message` from HTTP/2 response headers/trailers."""
    status_matches = re.findall(r"(?im)^grpc-status:\s*(\d+)", headers_text)
    msg_matches = re.findall(r"(?im)^grpc-message:\s*(.+)$", headers_text)
    status = int(status_matches[-1]) if status_matches else 0
    message = msg_matches[-1].strip() if msg_matches else ""
    return status, message


def grpc_call(address: str, method: str, payload: bytes, timeout_sec: int = 15) -> bytes:
    """Invoke a unary gRPC method over cleartext HTTP/2 (`h2c`) using `curl`."""
    frame = pack_grpc_frame(payload)
    url = f"http://{address}/{SERVICE_PATH}/{method}"
    with tempfile.NamedTemporaryFile() as req_file, tempfile.NamedTemporaryFile() as hdr_file:
        req_file.write(frame)
        req_file.flush()
        proc = subprocess.run(
            [
                "curl",
                "-sS",
                "--noproxy",
                "*",
                "--http2-prior-knowledge",
                "--max-time",
                str(timeout_sec + 5),
                "-D",
                hdr_file.name,
                "-H",
                "Content-Type: application/grpc",
                "-H",
                "TE: trailers",
                "-H",
                f"grpc-timeout: {timeout_sec}S",
                "-H",
                "Expect:",
                "--data-binary",
                f"@{req_file.name}",
                url,
            ],
            capture_output=True,
            check=True,
        )
        headers = hdr_file.read().decode("utf-8", errors="replace")

    status, message = parse_grpc_status(headers)
    if status != 0:
        raise RuntimeError(f"gRPC {method} failed with status {status}: {message}")
    return unpack_grpc_frame(proc.stdout)


def complete_one_workflow_task(
    address: str,
    namespace: str,
    task_queue: str,
    identity: str,
    result_json: str,
) -> None:
    """Poll one workflow task from `task_queue` and mark the workflow completed."""
    poll_req = build_poll_workflow_task_request(namespace, task_queue, identity)
    poll_resp = grpc_call(address, "PollWorkflowTaskQueue", poll_req)
    task_token = extract_task_token(poll_resp)
    if not task_token:
        raise RuntimeError(f"PollWorkflowTaskQueue on {task_queue} returned an empty task_token")

    comp_req = build_complete_workflow_task_request(namespace, task_token, identity, result_json)
    grpc_call(address, "RespondWorkflowTaskCompleted", comp_req)


def main() -> None:
    parser = argparse.ArgumentParser(description="Minimal Temporal gRPC worker helper.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_comp = sub.add_parser("complete-one", help="Poll and complete one workflow task.")
    p_comp.add_argument("--address", default="localhost:7233", help="Temporal frontend gRPC host:port")
    p_comp.add_argument("--namespace", default="default", help="Temporal namespace")
    p_comp.add_argument("--task-queue", required=True, help="Task queue name to poll")
    p_comp.add_argument("--identity", default="mac-smoke-worker", help="Worker identity")
    p_comp.add_argument(
        "--result",
        default='{"status":"ok","worker":"mac-host"}',
        help="JSON payload returned as the workflow result",
    )

    args = parser.parse_args()
    if args.cmd == "complete-one":
        complete_one_workflow_task(
            address=args.address,
            namespace=args.namespace,
            task_queue=args.task_queue,
            identity=args.identity,
            result_json=args.result,
        )


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001
        print(f"temporal_grpc error: {exc}", file=sys.stderr)
        sys.exit(1)
