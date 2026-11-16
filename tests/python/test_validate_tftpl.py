"""Unit tests for scripts/lib/validate_tftpl.py (standard library only).

Run: python3 -m unittest discover -s tests/python -q
"""

import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts" / "lib"))

import validate_tftpl as vt  # noqa: E402


class ExtractVariablesTests(unittest.TestCase):
    def test_plain_placeholders(self):
        found = vt.extract_tftpl_variables("host: ${ingress_host}\nport: ${grpc_port}")
        self.assertEqual(found, {"ingress_host", "grpc_port"})

    def test_no_placeholders(self):
        self.assertEqual(vt.extract_tftpl_variables("a: 1\nb: two\n"), set())

    def test_builtins_and_literals_ignored(self):
        found = vt.extract_tftpl_variables('x: ${jsonencode(keys(model_routes))}\ny: ${upper("literal")}')
        self.assertEqual(found, {"model_routes"})

    def test_if_directive(self):
        found = vt.extract_tftpl_variables(
            '%{ if postgres_image_name != "" ~}\nimage: ${postgres_image_name}\n%{ endif ~}'
        )
        self.assertEqual(found, {"postgres_image_name"})

    def test_for_directive(self):
        text = "%{ for agent, model in model_routes ~}\n- ${agent}: ${model}\n%{ endfor ~}"
        self.assertEqual(vt.extract_tftpl_variables(text), {"model_routes"})


class MainTfCallTests(unittest.TestCase):
    def test_extracts_keys(self):
        main_tf = (
            'locals {\n  v = templatefile("${path.module}/values.yaml.tftpl", {\n'
            "    ingress_host = var.ingress_host\n    grpc_port    = 7233\n  })\n}\n"
        )
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "main.tf"
            path.write_text(main_tf, encoding="utf-8")
            calls = vt.extract_main_tf_template_calls(path)
        self.assertEqual(calls, {"values.yaml.tftpl": {"ingress_host", "grpc_port"}})

    def test_no_calls(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "main.tf"
            path.write_text('resource "x" "y" {}\n', encoding="utf-8")
            self.assertEqual(vt.extract_main_tf_template_calls(path), {})


class RenderTests(unittest.TestCase):
    def test_placeholders_replaced(self):
        rendered = vt.render_tftpl_for_yaml_check("host: ${ingress_host}\nport: ${grpc_port}\n")
        self.assertEqual(rendered, "host: service.localhost\nport: 7233\n")
        self.assertNotIn("${", rendered)

    def test_for_loop_expanded(self):
        rendered = vt.render_tftpl_for_yaml_check(
            "%{ for agent, model in model_routes ~}\n- ${agent}: ${model}\n%{ endfor ~}\n"
        )
        self.assertEqual(rendered, "- pm-agent: gemma4:12b\n")


class RepoTests(unittest.TestCase):
    def test_current_templates_validate(self):
        # Needs yq on PATH, like `task lint`.
        self.assertEqual(vt.validate_all(), 0)


if __name__ == "__main__":
    unittest.main()
