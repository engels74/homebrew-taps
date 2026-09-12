"""Failure evidence must survive the disposable app home."""

import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "gui_smoke", Path(__file__).resolve().parents[1] / "gui-smoke.py"
)
gui_smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gui_smoke)


class GuiEvidenceTests(unittest.TestCase):
    def test_early_exit_preserves_full_log_and_still_fails(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch)
            app = root / "failed-app"
            # More than the exception's tail: the complete diagnostic must survive.
            output = "first diagnostic\n" + "detail\n" * 1000
            app.write_text("#!/bin/sh\ncat <<'LOG'\n" + output + "LOG\nexit 7\n")
            app.chmod(0o755)
            artifacts = root / "artifacts"
            with patch.object(gui_smoke.shutil, "which", return_value=str(app)), patch.dict(
                os.environ, {"GUI_TEST_ARTIFACTS": str(artifacts)}
            ):
                with self.assertRaisesRegex(RuntimeError, r"exited \(7\)"):
                    gui_smoke.run_app("fcast-sender", "wayland")
            self.assertEqual(
                (artifacts / "fcast-sender-wayland-window.log").read_text(), output
            )


if __name__ == "__main__":
    unittest.main()
