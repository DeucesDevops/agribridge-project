import tempfile
import unittest
from pathlib import Path

from junit_summary import render


class JunitSummaryTest(unittest.TestCase):
    def test_names_the_failed_test(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "junit-unit.xml"
            report.write_text(
                """<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="pricing" tests="2" failures="1">
    <testcase classname="pricing.test" name="accepts a whole naira price"/>
    <testcase classname="pricing.test" name="rejects a zero price">
      <failure message="expected throw">AssertionError: expected throw</failure>
    </testcase>
  </testsuite>
</testsuites>
""",
                encoding="utf-8",
            )
            summary = render([directory])

        self.assertIn("junit-unit.xml", summary)
        self.assertIn("pricing.test rejects a zero price", summary)
        self.assertIn("expected throw", summary)
        self.assertNotIn("All published tests passed.", summary)

    def test_empty_directory_says_nothing_was_produced(self):
        with tempfile.TemporaryDirectory() as directory:
            summary = render([directory])
        self.assertIn("No JUnit files were produced.", summary)


if __name__ == "__main__":
    unittest.main()
