"""Data-adapter regression tests: python -m unittest discover -s scripts."""
import csv
import io
import unittest
import zipfile

from import_japan_post import convert


def archive(rows):
    text = io.StringIO(newline='')
    csv.writer(text).writerows(rows)
    data = io.BytesIO()
    with zipfile.ZipFile(data, 'w') as z:
        z.writestr('utf_ken_all.csv', '\ufeff' + text.getvalue())
    return data.getvalue()


def row(postal='0010001', town='試験町', split='0'):
    return ['01101', '001', postal, 'カナ', 'カナ', 'カナ', 'A県', 'B市', town, split, '0', '0', '0', '0', '0']


class ImportTests(unittest.TestCase):
    def test_bom_leading_zero_quoted_comma_and_dedup(self):
        rows, metadata = convert(archive([row(town='町,域'), row(town='町,域')]))
        self.assertEqual(rows, [('JP', '0010001', 'A県', 'B市', '町,域', 'exact')])
        self.assertEqual(metadata['source_rows'], 2)
        self.assertEqual(metadata['unique_rows'], 1)

    def test_fallback_and_range_towns_stay_unverified(self):
        rows, _ = convert(archive([row(town='以下に掲載がない場合'), row(town='試験村一円'), row(town='町（１丁目）'), row(split='1')]))
        self.assertEqual([r[5] for r in rows], ['unspecified', 'unspecified', 'conditional', 'conditional'])

    def test_multi_town_flag_does_not_discard_records(self):
        first, second = row(town='東町'), row(town='西町')
        first[12] = second[12] = '1'
        rows, _ = convert(archive([first, second]))
        self.assertEqual(len(rows), 2)
        self.assertTrue(all(r[5] == 'exact' for r in rows))

    def test_bad_shape_flags_retired_and_control_rows_rejected(self):
        bad_flags, retired = row(), row()
        bad_flags[9] = '2'
        retired[13] = '2'
        for fields in [row(postal='123'), row(postal='１２３４５６７'), row(town='bad\ttown'), row()[:-1], bad_flags, retired]:
            with self.subTest(fields=fields), self.assertRaises(ValueError):
                convert(archive([fields]))


if __name__ == '__main__':
    unittest.main()
