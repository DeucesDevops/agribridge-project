"""Coverage must map to the right component and fail rather than disappear."""
import importlib.util
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location("coverage_preparation", Path(__file__).with_name("prepare-coverage.py"))
coverage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(coverage)


class CoveragePathsTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        for component in ("api", "frontend"):
            source = self.root / component / "src/example.js"
            source.parent.mkdir(parents=True)
            source.write_text("export const example = 1;\n")

    def test_relative_rooted_and_absolute_paths_keep_coverage_records(self):
        for component in ("api", "frontend"):
            for source in ("src/example.js", f"{component}/src/example.js",
                           str(self.root / component / "src/example.js")):
                with self.subTest(component=component, source=source):
                    report = f"SF:{source}\nDA:1,2\nend_of_record\n"
                    self.assertEqual(coverage.normalize_report(report, component, self.root),
                                     f"SF:{component}/src/example.js\nDA:1,2\nend_of_record\n")

    def test_missing_empty_and_cross_component_sources_fail(self):
        for source in ("src/missing.js", "../frontend/src/example.js", ""):
            with self.subTest(source=source), self.assertRaises(ValueError):
                coverage.normalize_report(f"SF:{source}\nend_of_record\n", "api", self.root)
        with self.assertRaisesRegex(ValueError, "no source records"):
            coverage.normalize_report("", "api", self.root)

    def test_combines_both_components(self):
        for component in ("api", "frontend"):
            report = self.root / component / "coverage/lcov.info"
            report.parent.mkdir()
            report.write_text("SF:src/example.js\nDA:1,1\nend_of_record\n")
        coverage.main(self.root)
        output = (self.root / ".runtime/sonarqube/lcov.info").read_text()
        self.assertIn("SF:api/src/example.js\n", output)
        self.assertIn("SF:frontend/src/example.js\n", output)
        self.assertEqual(output.count("end_of_record"), 2)

    def test_missing_report_does_not_produce_partial_coverage(self):
        report = self.root / "api/coverage/lcov.info"
        report.parent.mkdir()
        report.write_text("SF:src/example.js\nDA:1,1\nend_of_record\n")
        with self.assertRaisesRegex(ValueError, "Missing frontend/coverage/lcov.info"):
            coverage.main(self.root)
        self.assertFalse((self.root / ".runtime/sonarqube/lcov.info").exists())


if __name__ == "__main__":
    unittest.main()
