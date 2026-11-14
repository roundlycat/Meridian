import unittest

import numpy as np

from services.promotion.__main__ import _content_key, _normalize, _parse_vec, _vec_literal


class PromotionTests(unittest.TestCase):
	def test_vector_literal_round_trip(self):
		source = np.array([1.0, -2.5, 3.25], dtype=np.float32)

		result = _parse_vec(_vec_literal(source))

		np.testing.assert_allclose(source, result)

	def test_normalize_handles_zero_vectors(self):
		result = _normalize(np.array([[3.0, 4.0], [0.0, 0.0]], dtype=np.float32))

		np.testing.assert_allclose([0.6, 0.8], result[0])
		np.testing.assert_allclose([0.0, 0.0], result[1])

	def test_content_key_is_stable_for_equivalent_centroids(self):
		first = np.array([0.1234, 0.5678], dtype=np.float32)
		second = np.array([0.1231, 0.5681], dtype=np.float32)

		self.assertEqual(_content_key(first), _content_key(second))


if __name__ == "__main__":
	unittest.main()
