**write a web server in python that can accept HTTP GET requests from web clients**
Run on smallest possible VM
run this webserver on a VM instance for which you have configured a static IP address
start this web server automatically upon VM creation
VM runs as a special service account that has only the necessary privileges and nothing more

For thsi server use Base HTTP server (https://docs.python.org/3/library/http.server.html)

**Code for web server**
respond to requests for the files in your gcloud bucket that you created in homework 2 and return the contents of the requested file along with a 200-OK status
Requests for non-existent files should return a 404-not found status.  Such erroneous requests should be logged to cloud logging, with severity WARNING.
Requests for other HTTP methods (PUT, POST, DELETE, HEAD, CONNECT, OPTIONS, TRACE, PATCH) should return a 501-not implemented status.  Such erroneous requests should be logged to cloud logging, with severity WARNING.
log banned countries errors into cloud logging with severity critical, and communicate such “forbidden” requests to the second app which should print an appropriate error message to its standard output


**Logging info**

'from google.cloud import logging as cloud_logging
client = cloud_logging.Client()
client.setup_logging()
import logging'

might have to use pip install google-cloud-logging