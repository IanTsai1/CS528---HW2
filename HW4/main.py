from google.cloud import logging as cloud_logging
client = cloud_logging.Client()
client.setup_logging()

import logging
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs
from google.cloud import storage
from google.cloud import pubsub_v1

PROJECT = "cs528-485121"
BUCKET_NAME = "iantsai-hw2"

storage_client = storage.Client()
publisher = pubsub_v1.PublisherClient()

BANNED_COUNTRIES = {
    "North Korea", "Iran", "Cuba", "Myanmar",
    "Iraq", "Libya", "Sudan", "Zimbabwe", "Syria"
}


class FileHandler(BaseHTTPRequestHandler):

    def do_GET(self):
        country = self.headers.get("X-Country")
        if country in BANNED_COUNTRIES:
            logging.critical(f"Forbidden request from banned country: {country}")
            topic_path = publisher.topic_path(PROJECT, "forbidden-topic")
            future = publisher.publish(topic_path, f"Forbidden request from {country}".encode("utf-8"))
            future.result()
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"Permission denied")
            return

        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)
        filename = params.get("file", [None])[0]

        if not filename:
            logging.warning("Request missing 'file' query parameter")
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"Missing file parameter")
            return

        try:
            bucket = storage_client.bucket(BUCKET_NAME)
            blob = bucket.blob(filename)

            if not blob.exists():
                logging.warning(f"File not found in bucket: {filename}")
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b"File not found")
                return ("File not found", 404)

            content = blob.download_as_bytes()
            self.send_response(200)
            self.end_headers()
            self.wfile.write(content)

        except Exception as e:
            logging.error(f"Internal error serving file '{filename}': {e}")
            self.send_response(500)
            self.end_headers()
            self.wfile.write(b"Internal error")

    def _not_implemented(self):
        logging.warning(f"Unsupported HTTP method: {self.command}")
        self.send_response(501)
        self.end_headers()
        self.wfile.write(b"Not implemented")
        return ("Unsupported HTTP method", 404)

    # rest of these operations like post, put, etc. will go to not_implemented func
    do_POST = do_PUT = do_DELETE = do_HEAD = \
        do_OPTIONS = do_TRACE = do_CONNECT = do_PATCH = _not_implemented



if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 8080), FileHandler)
    logging.info("Server started on port 8080")
    server.serve_forever()
