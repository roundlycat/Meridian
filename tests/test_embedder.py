import unittest

from services.embedder.__main__ import _band, render_text


class EmbedderTests(unittest.TestCase):
	def test_band_returns_expected_ranges(self):
		self.assertEqual("cold", _band(10, [16, 22, 26], ["cold", "cool", "warm", "hot"]))
		self.assertEqual("warm", _band(24, [16, 22, 26], ["cold", "cool", "warm", "hot"]))
		self.assertEqual("hot", _band(30, [16, 22, 26], ["cold", "cool", "warm", "hot"]))
		self.assertIsNone(_band(None, [16], ["cold", "hot"]))

	def test_environmental_render_is_factual_and_banded(self):
		text = render_text("environmental_field", {"temperature": 24.2, "humidity": 63.0, "lux": 20})

		self.assertIn("Temperature 24.2C (warm).", text)
		self.assertIn("Humidity 63% (humid).", text)
		self.assertIn("Light 20 lux (dim).", text)

	def test_unknown_domain_renders_all_channels(self):
		text = render_text("custom", {"signal": 3.14, "state": "on"})

		self.assertEqual("custom reading. signal 3.14. state on.", text)


if __name__ == "__main__":
	unittest.main()
