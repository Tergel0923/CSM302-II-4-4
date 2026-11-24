"""BD2 regression: replays the peer reviewer's main table (A1-A10) and boundary cases
through the real HTTP server (demo backend). Run: python3 -m unittest tests.test_review_regression"""
import json, sys, threading, unittest, urllib.request, urllib.error
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'src/ui'))
import server  # noqa: E402

PORT = 8791


class ReviewRegression(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        threading.Thread(target=server.serve, args=('demo', PORT), daemon=True).start()
        import time
        for _ in range(50):
            try:
                cls.page = urllib.request.urlopen(f'http://127.0.0.1:{PORT}/').read().decode(); break
            except OSError:
                time.sleep(.1)
        cls.token = cls.page.split("const token='")[1].split("'")[0]

    def post(self, data, token=None, origin=True):
        h = {'Content-Type': 'application/json', 'X-KDS-Token': token or self.token}
        if origin: h['Origin'] = f'http://127.0.0.1:{PORT}'
        req = urllib.request.Request(f'http://127.0.0.1:{PORT}/api/command', json.dumps(data).encode(), h)
        try:
            with urllib.request.urlopen(req) as r: return r.status, json.loads(r.read())
        except urllib.error.HTTPError as e: return e.code, json.loads(e.read())

    def test_A1_to_A6_colors(self):
        s, b = self.post({'action': 'RESET'}); c = b['colors']
        self.assertEqual((len(c['nodes']), c['head']), (4, {'next': 1, 'prev': 4}))              # A1
        s, b = self.post({'action': 'ADD', 'r': 10, 'g': 20, 'b': 30}); c = b['colors']
        self.assertEqual((len(c['nodes']), c['head']['prev']), (5, 5))                            # A2
        s, b = self.post({'action': 'SEARCH', 'r': 10, 'g': 20, 'b': 30}); self.assertEqual(b['colors']['found'], 5)  # A3
        s, b = self.post({'action': 'DELETE', 'id': 5}); c = b['colors']
        self.assertEqual((len(c['nodes']), c['head']['prev'], c['nodes'][-1]['next']), (4, 4, 0))  # A4
        s, b = self.post({'action': 'SEARCH', 'r': 10, 'g': 20, 'b': 30}); self.assertEqual(b['colors']['found'], 0)  # A5
        s, b = self.post({'action': 'CLEAR'}); self.assertEqual(b['colors']['head'], {'next': 0, 'prev': 0})          # A6

    def test_A7_to_A10_collatz(self):
        for start, n in ((1, 1), (15, 18), (25, 24), (27, 112)):
            s, b = self.post({'action': 'COLLATZ', 'start': str(start)}); self.assertEqual(s, 200, b)
            nodes = b['collatz']['nodes']; self.assertEqual((len(nodes), nodes[-1]['value']), (n, '1'))

    def test_boundaries(self):
        self.post({'action': 'RESET'})
        for bad in (-1, 256, 'abc', '', 1.5):
            s, b = self.post({'action': 'ADD', 'r': bad, 'g': 0, 'b': 0}); self.assertEqual(s, 400, bad)
        self.assertEqual(len(self.post({'action': 'RESET'})[1]['colors']['nodes']), 4)       # state kept
        for _ in range(124): self.assertEqual(self.post({'action': 'ADD', 'r': 1, 'g': 1, 'b': 1})[0], 200)
        s, b = self.post({'action': 'ADD', 'r': 1, 'g': 1, 'b': 1}); self.assertEqual(s, 400)  # 129th
        for start in ('0', str(2**64 - 1)):
            self.assertEqual(self.post({'action': 'COLLATZ', 'start': start})[0], 400, start)
        self.post({'action': 'RESET'})

    def test_403_cases(self):
        self.assertEqual(self.post({'action': 'RESET'}, token='wrong')[0], 403)
        self.assertEqual(self.post({'action': 'RESET'}, origin=False)[0], 403)

    def test_ui_contains_review_fixes(self):   # static guards for reviewer items 3, 4, 5
        self.assertIn('id="colorControls"', self.page); self.assertIn('colorControls\').hidden=type!==\'colors\'', self.page)
        self.assertIn('Ctrl+R', self.page); self.assertIn('Math.min(8,', self.page)


if __name__ == '__main__':
    unittest.main()
