import unittest

from update_production_images import ImageUpdateError, update_images


SAMPLE = """# hostname must match terraform output production_hostname.
hostname: production.agribridge.deuces.dev
api:
  repository: docker.io/macroni607/agribridge-api
  tag: local
  replicas: 2
web:
  repository: docker.io/macroni607/agribridge-web
  tag: local
  replicas: 2
backup:
  enabled: true
  prefix: production
"""


class UpdateProductionImagesTest(unittest.TestCase):
    def test_replaces_both_images_and_leaves_the_rest(self):
        updated = update_images(
            SAMPLE,
            "docker.io/example/agribridge-api",
            "docker.io/example/agribridge-web",
            "abc123",
        )
        self.assertIn("repository: docker.io/example/agribridge-api\n", updated)
        self.assertIn("repository: docker.io/example/agribridge-web\n", updated)
        self.assertEqual(updated.count("tag: abc123\n"), 2)
        self.assertIn("replicas: 2\n", updated)
        self.assertIn("prefix: production\n", updated)
        self.assertIn("hostname: production.agribridge.deuces.dev\n", updated)
        self.assertNotIn("tag: local", updated)

    def test_is_idempotent(self):
        once = update_images(SAMPLE, "docker.io/macroni607/agribridge-api", "docker.io/macroni607/agribridge-web", "abc123")
        twice = update_images(once, "docker.io/macroni607/agribridge-api", "docker.io/macroni607/agribridge-web", "abc123")
        self.assertEqual(once, twice)

    def test_missing_tag_is_an_error(self):
        broken = SAMPLE.replace("  tag: local\n", "", 1)
        with self.assertRaises(ImageUpdateError):
            update_images(broken, "repo/api", "repo/web", "abc123")


if __name__ == "__main__":
    unittest.main()
