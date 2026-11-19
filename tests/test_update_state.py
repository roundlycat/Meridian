import importlib.util
import unittest
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parent.parent / "deploy" / "update_state.py"
_spec = importlib.util.spec_from_file_location("update_state", _SCRIPT)
update_state = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(update_state)


class UpdateStateTests(unittest.TestCase):
    def test_parse_lesson_reads_title_and_wrapped_status(self):
        text = "# Slice B — test\n\n**Status:** result established;\ncoarsening in progress.\n**ADR:** 2\n"

        title, status = update_state.parse_lesson(text)

        self.assertEqual("Slice B — test", title)
        self.assertEqual("result established; coarsening in progress.", status)

    def test_parse_lesson_without_status(self):
        self.assertEqual(("Notes", "no status line"), update_state.parse_lesson("# Notes\n\nbody\n"))

    def test_parse_porcelain_separates_modified_and_untracked(self):
        modified, untracked = update_state.parse_porcelain(" M a.py\nM  b.py\n?? tests/\n")

        self.assertEqual(["a.py", "b.py"], modified)
        self.assertEqual(["tests/"], untracked)

    def test_replace_block_only_touches_marked_region(self):
        old_block = update_state.BEGIN + "\nold\n" + update_state.END
        document = "# Title\n\nwritten by hand\n\n" + old_block + "\n\nalso by hand\n"
        new_block = update_state.BEGIN + "\nnew\n" + update_state.END

        result = update_state.replace_block(document, new_block)

        self.assertEqual("# Title\n\nwritten by hand\n\n" + new_block + "\n\nalso by hand\n", result)

    def test_replace_block_appends_when_no_markers(self):
        block = update_state.BEGIN + "\nnew\n" + update_state.END

        result = update_state.replace_block("# Title\n", block)

        self.assertEqual("# Title\n\n" + block + "\n", result)

    def test_replace_block_is_idempotent(self):
        block = update_state.BEGIN + "\nnew\n" + update_state.END
        once = update_state.replace_block("# Title\n", block)

        self.assertEqual(once, update_state.replace_block(once, block))


if __name__ == "__main__":
    unittest.main()
