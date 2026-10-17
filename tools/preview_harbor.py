"""Serve only the local evidence directory, with byte ranges for MP4 seeking."""
import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import re

EVIDENCE = Path(__file__).resolve().parents[1] / "Artifacts"


class EvidenceHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(EVIDENCE), **kwargs)

    def end_headers(self):
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def send_head(self):
        self.range_remaining = None
        requested = self.headers.get("Range")
        target = Path(self.translate_path(self.path))
        if not requested or not target.is_file():
            return super().send_head()
        total = target.stat().st_size
        match = re.fullmatch(r"bytes=(\d*)-(\d*)", requested)
        if not match or not any(match.groups()):
            self.send_error(416, "Invalid range")
            return None
        low, high = match.groups()
        if low:
            start = int(low)
            end = min(int(high), total - 1) if high else total - 1
        else:
            start, end = max(0, total - int(high)), total - 1
        if start > end or start >= total:
            self.send_response(416)
            self.send_header("Content-Range", f"bytes */{total}")
            self.end_headers()
            return None
        source = target.open("rb")
        source.seek(start)
        self.range_remaining = end - start + 1
        self.send_response(206)
        self.send_header("Content-Type", self.guess_type(str(target)))
        self.send_header("Content-Range", f"bytes {start}-{end}/{total}")
        self.send_header("Content-Length", str(self.range_remaining))
        self.end_headers()
        return source

    def copyfile(self, source, outputfile):
        try:
            if self.range_remaining is None:
                return super().copyfile(source, outputfile)
            while self.range_remaining:
                block = source.read(min(self.range_remaining, 128 * 1024))
                if not block:
                    break
                outputfile.write(block)
                self.range_remaining -= len(block)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass  # Normal when the browser seeks to a different part of the video.


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8374)
    args = parser.parse_args()
    print(f"Harbor review: http://127.0.0.1:{args.port}/Harbor-v02/20261009-final/", flush=True)
    ThreadingHTTPServer(("127.0.0.1", args.port), EvidenceHandler).serve_forever()
