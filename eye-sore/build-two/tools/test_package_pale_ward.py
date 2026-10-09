"""Bounded checks for package failure handling and portable archive integrity."""
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import package_pale_ward as package


class PackageChecks(unittest.TestCase):
    def test_smoke_requires_exit_markers_and_clean_output(self):
        clean = "\n".join(package.MARKERS)
        for code, output, fails in [(0, clean, False), (1, clean, True),
                                    (0, package.MARKERS[0], True),
                                    (0, clean + "\nERROR: Broken asset", True),
                                    (0, clean + "\nWARNING: Broken setting", True)]:
            with self.subTest(code=code, output=output):
                with patch.object(subprocess, "run", return_value=subprocess.CompletedProcess(["fake"], code, output)):
                    if fails:
                        with self.assertRaises(package.PackagingError):
                            package.checked(["fake"], cwd=Path("/tmp"), markers=package.MARKERS)
                    else:
                        self.assertEqual(package.checked(["fake"], cwd=Path("/tmp"), markers=package.MARKERS), clean)

    def test_deterministic_archive_verifies_hashes_and_executable_mode(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stage = root / "stage"
            stage.mkdir()
            executable = stage / "eyesore.x86_64"
            executable.write_bytes(b"fixture executable")
            executable.chmod(0o755)
            readme = stage / "README.txt"
            readme.write_text("fixture readme\n")
            (stage / "SHA256SUMS").write_text("".join(f"{package.sha256(path)}  {path.name}\n" for path in (readme, executable)))
            first, second = root / "first.tar.gz", root / "second.tar.gz"
            package.create_archive(stage, first, 1700000000)
            executable.touch()
            package.create_archive(stage, second, 1700000000)
            self.assertEqual(package.sha256(first), package.sha256(second))
            package.verify_archive(first, executable.name, package.sha256(executable))
            with self.assertRaises(package.PackagingError):
                package.verify_archive(first, executable.name, "0" * 64)
            executable.chmod(0o644)
            package.create_archive(stage, second, 1700000000)
            with self.assertRaises(package.PackagingError):
                package.verify_archive(second, executable.name, package.sha256(executable))
            executable.chmod(0o755)
            readme.write_text("tampered payload")
            package.create_archive(stage, second, 1700000000)
            with self.assertRaises(package.PackagingError):
                package.verify_archive(second, executable.name, package.sha256(executable))

    def test_existing_executable_refused_before_git_or_export(self):
        with tempfile.TemporaryDirectory() as directory:
            existing = Path(directory) / "eyesore.x86_64"
            existing.write_bytes(b"accepted")
            args = package.arguments(["--build-dir", directory, "--executable-name", existing.name, "--dry-run"])
            with patch.object(package, "git", side_effect=AssertionError("should stop before Git")):
                with self.assertRaisesRegex(package.PackagingError, "Refusing to overwrite"):
                    package.package(args)
            self.assertEqual(existing.read_bytes(), b"accepted")

    def test_executable_path_and_output_collisions_refused(self):
        for name in ("../eyesore", "a/b", "eyesore;rm", "BUILD.json", "smoke.log", "provenance"):
            with self.subTest(name=name):
                args = package.arguments(["--build-dir", "/tmp/unused-package-test", "--executable-name", name, "--dry-run"])
                with self.assertRaises(package.PackagingError):
                    package.package(args)


if __name__ == "__main__":
    unittest.main()
