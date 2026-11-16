"""Unit tests for scripts/lib/temporal_grpc.py (standard library only).

Run: python3 -m unittest discover -s tests/python -q
"""

import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts" / "lib"))

import temporal_grpc as tg  # noqa: E402


class VarintTests(unittest.TestCase):
    def test_round_trip(self):
        for val in [0, 1, 127, 128, 300, 16384, 2**32 - 1]:
            enc = tg.encode_varint(val)
            dec, pos = tg.decode_varint(enc, 0)
            self.assertEqual((dec, pos), (val, len(enc)), f"varint mismatch for {val}")

    def test_known_encodings(self):
        self.assertEqual(tg.encode_varint(0), b"\x00")
        self.assertEqual(tg.encode_varint(127), b"\x7f")
        self.assertEqual(tg.encode_varint(128), b"\x80\x01")
        self.assertEqual(tg.encode_varint(300), b"\xac\x02")

    def test_negative_rejected(self):
        with self.assertRaises(ValueError):
            tg.encode_varint(-1)

    def test_truncated_rejected(self):
        with self.assertRaises(ValueError):
            tg.decode_varint(b"\x80", 0)
        with self.assertRaises(ValueError):
            tg.decode_varint(b"", 0)

    def test_overflow_rejected(self):
        with self.assertRaises(ValueError):
            tg.decode_varint(b"\xff" * 11, 0)

    def test_decode_from_offset(self):
        self.assertEqual(tg.decode_varint(b"\x01\xac\x02", 1), (300, 3))


class FrameTests(unittest.TestCase):
    def test_pack_unpack_and_token_extraction(self):
        fake_token = b"temporal-task-token-12345"
        poll_resp = tg.field_bytes(1, fake_token) + tg.field_varint(4, 42)
        unpacked = tg.unpack_grpc_frame(tg.pack_grpc_frame(poll_resp))
        self.assertEqual(unpacked, poll_resp)
        self.assertEqual(tg.extract_task_token(unpacked), fake_token)

    def test_frame_layout(self):
        self.assertEqual(tg.pack_grpc_frame(b"abc"), b"\x00\x00\x00\x00\x03abc")
        self.assertEqual(tg.pack_grpc_frame(b""), b"\x00\x00\x00\x00\x00")

    def test_short_frame_rejected(self):
        with self.assertRaises(ValueError):
            tg.unpack_grpc_frame(b"\x00\x00\x00")

    def test_compressed_frame_rejected(self):
        with self.assertRaises(ValueError):
            tg.unpack_grpc_frame(b"\x01\x00\x00\x00\x01x")

    def test_truncated_frame_rejected(self):
        with self.assertRaises(ValueError):
            tg.unpack_grpc_frame(b"\x00\x00\x00\x00\x09abc")

    def test_trailing_bytes_ignored(self):
        self.assertEqual(tg.unpack_grpc_frame(b"\x00\x00\x00\x00\x01xjunk"), b"x")


class ProtobufTests(unittest.TestCase):
    def test_field_encoders(self):
        self.assertEqual(tg.field_varint(1, 150), b"\x08\x96\x01")
        self.assertEqual(tg.field_bytes(2, "hi"), b"\x12\x02hi")
        self.assertEqual(tg.field_bytes(2, b"hi"), tg.field_bytes(2, "hi"))

    def test_token_missing_returns_empty(self):
        self.assertEqual(tg.extract_task_token(b""), b"")
        self.assertEqual(tg.extract_task_token(tg.field_varint(4, 42)), b"")

    def test_token_skips_other_wire_types(self):
        fixed64 = tg.encode_varint((2 << 3) | 1) + b"\x00" * 8
        fixed32 = tg.encode_varint((3 << 3) | 5) + b"\x00" * 4
        other = tg.field_bytes(5, b"other")
        msg = tg.field_varint(9, 7) + fixed64 + fixed32 + other + tg.field_bytes(1, b"tok")
        self.assertEqual(tg.extract_task_token(msg), b"tok")

    def test_token_unsupported_wire_type(self):
        with self.assertRaises(ValueError):
            tg.extract_task_token(tg.encode_varint((1 << 3) | 3))

    def test_poll_request_contains_inputs(self):
        req = tg.build_poll_workflow_task_request("default", "smoke-queue", "worker-1")
        for part in (b"default", b"smoke-queue", b"worker-1"):
            self.assertIn(part, req)

    def test_complete_request(self):
        token = b"temporal-task-token-12345"
        req = tg.build_complete_workflow_task_request("default", token, "worker-1", '{"ok":true}')
        self.assertIn(token, req)
        self.assertIn(b'{"ok":true}', req)
        self.assertIn(b"json/plain", req)
        self.assertIn(b"default", req)


class StatusTests(unittest.TestCase):
    def test_error_status(self):
        status, msg = tg.parse_grpc_status(
            "HTTP/2 200\r\ngrpc-status: 3\r\ngrpc-message: Context timeout is not set.\r\n"
        )
        self.assertEqual(status, 3)
        self.assertIn("Context timeout", msg)

    def test_no_status_means_ok(self):
        self.assertEqual(tg.parse_grpc_status("HTTP/2 200\r\n"), (0, ""))

    def test_last_status_wins(self):
        text = "grpc-status: 0\r\ngrpc-status: 14\r\ngrpc-message: unavailable\r\n"
        self.assertEqual(tg.parse_grpc_status(text), (14, "unavailable"))

    def test_header_names_case_insensitive(self):
        self.assertEqual(tg.parse_grpc_status("Grpc-Status: 5\r\nGRPC-Message: nope\r\n"), (5, "nope"))


if __name__ == "__main__":
    unittest.main()
