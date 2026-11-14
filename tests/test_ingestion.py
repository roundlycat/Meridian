import sys
from unittest.mock import MagicMock
import unittest

sys.modules.setdefault("aiomqtt", MagicMock())

from services.ingestion.__main__ import _node_id_from_topic


class IngestionTests(unittest.TestCase):
	def test_extracts_node_id_from_valid_field_topic(self):
		self.assertEqual("pod-a4c138", _node_id_from_topic("meridian/field/pod-a4c138/readings"))

	def test_rejects_invalid_topics(self):
		self.assertIsNone(_node_id_from_topic("meridian/field/pod-a4c138/readings/extra"))
		self.assertIsNone(_node_id_from_topic("other/field/pod-a4c138/readings"))
		self.assertIsNone(_node_id_from_topic("meridian/field/readings"))


if __name__ == "__main__":
	unittest.main()
