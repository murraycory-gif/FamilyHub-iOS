import unittest

from recipe_catalog.licenses import license_is_commercially_reusable


class LicenseTests(unittest.TestCase):
    def test_allowed(self):
        for parts in (
            ("CC BY-SA 2.5", "Creative Commons Attribution-Share Alike 2.5", "cc-by-sa-2.5"),
            ("CC BY 4.0", "", "cc-by-4.0"),
            ("CC0", "Creative Commons Zero", "cc0"),
            ("Public domain", "", "pd"),
            ("GFDL and CC BY-SA 4.0", "", "gfdl|cc-by-sa-4.0"),
        ):
            ok, label = license_is_commercially_reusable(*parts)
            self.assertTrue(ok, parts)
            self.assertTrue(label, parts)

    def test_rejected(self):
        for parts in (
            ("CC BY-NC-SA 2.0", "", "cc-by-nc-sa-2.0"),
            ("CC BY-ND 2.0", "", "cc-by-nd-2.0"),
            ("GFDL", "GNU Free Documentation License", "gfdl"),
            ("Fair use", "", ""),
            ("", "", ""),
        ):
            ok, _label = license_is_commercially_reusable(*parts)
            self.assertFalse(ok, parts)


if __name__ == "__main__":
    unittest.main()
