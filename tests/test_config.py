import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from services.common.config import _parse_env_file, load_config


class ConfigTests(unittest.TestCase):
	def test_parse_env_file_ignores_comments_and_blank_lines(self):
		with tempfile.TemporaryDirectory() as directory:
			path = Path(directory) / "meridian.env"
			path.write_text("# comment\n\nMQTT_PORT = 1884\nINVALID\n", encoding="utf-8")

			self.assertEqual({"MQTT_PORT": "1884"}, _parse_env_file(path))

	def test_environment_overrides_environment_file(self):
		with tempfile.TemporaryDirectory() as directory:
			path = Path(directory) / "meridian.env"
			path.write_text("DATABASE_URL=postgresql://from-file\nMQTT_PORT=1884\n", encoding="utf-8")
			environment = {"MERIDIAN_ENV": str(path), "DATABASE_URL": "postgresql://from-process"}

			with patch.dict(os.environ, environment, clear=True):
				config = load_config()

		self.assertEqual("postgresql://from-process", config.database_url)
		self.assertEqual(1884, config.mqtt_port)
		self.assertEqual(768, config.embedding_dim)

	def test_database_url_is_required(self):
		with patch.dict(os.environ, {}, clear=True), patch("services.common.config._candidate_paths", return_value=[]):
			with self.assertRaisesRegex(KeyError, "DATABASE_URL"):
				load_config()


if __name__ == "__main__":
	unittest.main()
