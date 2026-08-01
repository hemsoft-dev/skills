from __future__ import annotations

import importlib.util
import pathlib
import unittest


SCRIPT_PATH = pathlib.Path(__file__).parents[1] / "scripts" / "slack_dm.py"
POWERSHELL_SCRIPT_PATH = (
    pathlib.Path(__file__).parents[1] / "scripts" / "Send-SlackDm.ps1"
)
SPEC = importlib.util.spec_from_file_location("slack_dm", SCRIPT_PATH)
assert SPEC and SPEC.loader
slack_dm = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(slack_dm)


class SlackDmTests(unittest.TestCase):
    def test_powershell_helper_keeps_utf8_bom(self) -> None:
        self.assertTrue(
            POWERSHELL_SCRIPT_PATH.read_bytes().startswith(b"\xef\xbb\xbf")
        )

    def test_fallback_begins_with_three_line_contract(self) -> None:
        fallback = slack_dm.build_fallback(
            "codexbar-ios",
            "PR #102 — Add saved-reset selection — merged",
            "The squash merge passed review and CI gates.",
            "merged",
            [],
            None,
        )

        self.assertEqual(
            fallback.splitlines()[:3],
            [
                "✅ PR #102 — Add saved-reset selection — merged",
                "📦 codexbar-ios",
                "The squash merge passed review and CI gates.",
            ],
        )

    def test_issue_or_pr_task_requires_id_title_and_result(self) -> None:
        invalid_tasks = [
            "PR117 merged",
            "PR #117 merged",
            "Issue #72 blocked",
            "Merged pull request #117",
        ]

        for task in invalid_tasks:
            with self.subTest(task=task):
                with self.assertRaisesRegex(ValueError, "exact title"):
                    slack_dm.clean_task(task)

        self.assertEqual(
            slack_dm.clean_task(
                "Issue #72 — Fix dashboard ordering — completed"
            ),
            "Issue #72 — Fix dashboard ordering — completed",
        )

    def test_details_render_as_table_rows(self) -> None:
        payload = slack_dm.build_message(
            "D123",
            "codexbar-ios",
            "PR #102 — Add saved-reset selection — merged",
            "The squash merge passed review and CI gates.",
            "merged",
            [
                ("Inventory", "Added saved-reset selection"),
                ("Quality", "Added accessibility tests"),
            ],
            "https://github.com/HemSoft/codexbar-ios/pull/102",
        )

        self.assertEqual(
            [block["type"] for block in payload["blocks"]],
            ["section", "header", "section", "section", "table"],
        )
        self.assertIn(
            "PR #102 — Add saved-reset selection",
            payload["blocks"][0]["text"]["text"],
        )
        table = payload["blocks"][-1]
        self.assertEqual(len(table["rows"]), 3)
        self.assertEqual(table["rows"][1][0]["text"], "Inventory")
        self.assertEqual(table["rows"][2][1]["text"], "Added accessibility tests")

    def test_summary_rejects_more_than_two_lines(self) -> None:
        with self.assertRaisesRegex(ValueError, "no more than two"):
            slack_dm.clean_summary("One\nTwo\nThree")

    def test_detail_requires_area_result_separator(self) -> None:
        with self.assertRaisesRegex(ValueError, "Area=Result"):
            slack_dm.parse_detail("Missing separator")

    def test_url_rejects_non_http_scheme(self) -> None:
        with self.assertRaisesRegex(ValueError, "http or https"):
            slack_dm.validate_url("file:///tmp/report")


if __name__ == "__main__":
    unittest.main()
