# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import os
import random
import requests
import requests.exceptions
import ssl
import time

from pathlib import Path
from requests.adapters import HTTPAdapter
from rich.progress import Progress, TextColumn, BarColumn, DownloadColumn, TransferSpeedColumn, TimeRemainingColumn
from rich.text import Text
from urllib.parse import urlparse
from urllib3.util.retry import Retry
from urllib3.exceptions import InsecureRequestWarning

from mpt.file import FileUtils
from mpt.log import RichLogger
from mpt.view import RichPanel, RichTable


# Suppress insecure request warnings
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)


class DownloadHandler:
    """
    Advanced file download handler with robust retry mechanisms and progress tracking.
    """

    # Configuration constants
    MAX_RETRIES = 10
    BACKOFF_FACTOR = 0.1
    STATUS_FORCELIST = [408, 429, 500, 502, 503, 504]  # HTTP status codes that should trigger a retry
    CONNECT_TIMEOUT = 30  # Seconds for connection establishment
    READ_TIMEOUT = 60     # Seconds for server response
    CHUNK_SIZE = 8192 * 10  # 80KB chunks for efficient streaming

    # Class variables to track download state across retries
    _expected_size = None
    _supports_partial = None


    @classmethod
    def download_file(cls, url, file_path, verify_ssl=False):
        """
        Execute a robust file download with comprehensive error handling and resume support.
        """
        # Ensure parent directory exists
        file_path.parent.mkdir(parents=True, exist_ok=True)
        success = False
        retry_count = 0

        # Configure retry strategy
        retry_strategy = Retry(
            total=cls.MAX_RETRIES,
            backoff_factor=cls.BACKOFF_FACTOR,
            status_forcelist=cls.STATUS_FORCELIST,
            allowed_methods=["GET", "HEAD"],
            respect_retry_after_header=True
        )

        # Create HTTP adapter with retry strategy
        adapter = HTTPAdapter(max_retries=retry_strategy)

        with requests.Session() as session:
            # Mount adapters for both HTTP and HTTPS
            session.mount('http://', adapter)
            session.mount('https://', adapter)

            # Reset class variables for new download
            cls._expected_size = None
            cls._supports_partial = None

            # Retry loop
            while retry_count <= cls.MAX_RETRIES and not success:
                progress = None
                task = None
                RichLogger.debug(f"Attempt [bold cyan]{retry_count + 1}[/bold cyan] of "
                             f"[bold cyan]{cls.MAX_RETRIES + 1}[/bold cyan]")

                try:
                    # Get current downloaded size before making request
                    downloaded_size = cls._get_download_size(file_path)

                    # Set up headers for request
                    headers = cls._get_wget_headers()

                    # Add Range header if we have partial content and server supports resume
                    if downloaded_size > 0 and cls._supports_partial:
                        headers["Range"] = f"bytes={downloaded_size}-"
                        if cls._expected_size:
                            headers["Range"] = f"bytes={downloaded_size}-{cls._expected_size}"
                        RichLogger.debug(f"Setting Range header: [bold cyan]{headers['Range']}[/bold cyan]")

                    # Make HTTP GET request with streaming
                    with session.get(
                        url,
                        headers=headers,
                        stream=True,
                        timeout=(cls.CONNECT_TIMEOUT, cls.READ_TIMEOUT),
                        allow_redirects=True,
                        verify=verify_ssl
                    ) as response:
                        cls._supports_partial = cls._is_partial(response)
                        if not cls._supports_partial:
                            if downloaded_size > 0:
                                RichLogger.debug("Deleting partial file due to chunked encoding")
                                FileUtils.delete_file(file_path)
                                # Reset downloaded size after deletion
                                downloaded_size = 0
                        cls._expected_size = cls._get_expected_size(response)
                        response.raise_for_status()
                        file_mode = 'wb'
                        if response.status_code == requests.codes.ok:
                            if downloaded_size > 0:
                                RichLogger.debug(f"Restarting download from beginning. "
                                             f"Existing file size: [bold cyan]{downloaded_size}[/bold cyan] bytes")
                                FileUtils.delete_file(file_path)
                                # Reset downloaded size after deletion
                                downloaded_size = 0
                        elif response.status_code == requests.codes.partial_content:
                            RichLogger.debug(f"Resuming download from position: "
                                         f"[bold cyan]{downloaded_size}[/bold cyan] bytes")
                            file_mode = 'ab'
                        else:
                            RichLogger.warning(f"Unexpected status code: "
                                           f"[bold cyan]{response.status_code}[/bold cyan]")
                            retry_count += 1
                            continue

                        # Create progress bar with accurate starting position
                        progress = cls._create_progress_bar()
                        task = progress.add_task(
                            f"[bold blue]Downloading[/bold blue] [cyan]{Path(url).name}[/cyan]",
                            total=cls._expected_size,
                            completed=downloaded_size  # Start from current downloaded position
                        )
                        progress.start()

                        # Download content with progress tracking
                        success = cls._get_content(
                            response,
                            file_path,
                            file_mode,
                            progress,
                            task,
                            downloaded_size,
                            cls._expected_size
                        )

                        # Verify download size
                        final_size = cls._get_download_size(file_path)
                        if success:
                            if cls._expected_size and final_size != cls._expected_size:
                                RichLogger.warning(f"Download incomplete: expected "
                                               f"[bold cyan]{cls._expected_size}[/bold cyan], "
                                               f"got [bold cyan]{final_size}[/bold cyan]")
                                success = False
                                retry_count += 1
                            else:
                                RichLogger.info("Download completed successfully")
                                break
                        else:
                            retry_count += 1

                except requests.exceptions.HTTPError as e:
                    RichLogger.warning(f"HTTP Error: [bold cyan]{str(e)}[/bold cyan]")
                    retry_count += 1
                except requests.exceptions.ConnectTimeout as e:
                    RichLogger.warning(f"Connect Timeout Error: [bold cyan]{str(e)}[/bold cyan]")
                    retry_count += 1
                except requests.exceptions.ConnectionError as e:
                    RichLogger.warning(f"Connection Error: [bold cyan]{str(e)}[/bold cyan]")
                    retry_count += 1
                except requests.exceptions.Timeout as e:
                    RichLogger.warning(f"Timeout Error: [bold cyan]{str(e)}[/bold cyan]")
                    retry_count += 1
                except requests.exceptions.RequestException as e:
                    RichLogger.warning(f"Request Exception: [bold cyan]{str(e)}[/bold cyan]")
                    retry_count += 1
                except Exception as e:
                    RichLogger.error(f"Unexpected error during download attempt: {str(e)}")
                    retry_count += 1
                finally:
                    # Ensure progress bar is stopped after each attempt
                    if progress:
                        progress.stop()

                # Add wait time before next retry
                if retry_count <= cls.MAX_RETRIES and not success:
                    wait_time = random.randint(2, 6)
                    RichLogger.info(f"Retrying in [bold cyan]{wait_time}[/bold cyan] seconds "
                                f"(attempt [bold cyan]{retry_count}[/bold cyan]/"
                                f"[bold cyan]{cls.MAX_RETRIES}[/bold cyan])")
                    time.sleep(wait_time)

        if not success:
            RichLogger.error(f"Failed to download [bold cyan]{file_path.name}[/bold cyan]")
        return success

    @classmethod
    def _get_expected_size(cls, response):
        # If chunked encoding is used, cannot determine total file size
        if 'Transfer-Encoding' in response.headers and response.headers.get('Transfer-Encoding', '').lower() == 'chunked':
            RichLogger.debug("Chunked encoding detected, cannot determine total file size")
            return None

        # Try to get size from Content-Range if available
        if 'Content-Range' in response.headers:
            # see https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Range
            # syntax:
            #  Content-Range: <unit> <range-start>-<range-end>/<size>
            #  Content-Range: <unit> <range-start>-<range-end>/*
            #  Content-Range: <unit> */<size>
            # e.g. Content-Range: bytes 14204624-31962046/31962047
            try:
                content_range = response.headers['Content-Range']
                RichLogger.debug(f"Found Content-Range header: [bold cyan]{content_range}[/bold cyan]")
                # Format: bytes 0-999/1000
                if '/' in content_range:
                    total_size = content_range.split('/')[-1]
                    if total_size != '*':
                        size = int(total_size)
                        RichLogger.debug(f"Parsed size from Content-Range: [bold cyan]{size}[/bold cyan] bytes")
                        return size
            except (ValueError, TypeError, IndexError) as e:
                RichLogger.debug(f"Failed to parse Content-Range: [bold cyan]{e}[/bold cyan]")

        # Try to get Content-Length
        if 'Content-Length' in response.headers:
            try:
                size = int(response.headers['Content-Length'])
                RichLogger.debug(f"Found Content-Length header: [bold cyan]{size}[/bold cyan] bytes")
                return size
            except (ValueError, TypeError) as e:
                RichLogger.debug(f"Failed to parse Content-Length: [bold cyan]{e}[/bold cyan]")

        # Try alternative headers
        for header in ['X-Goog-Stored-Content-Length', 'x-amz-meta-size']:
            if header in response.headers:
                try:
                    size = int(response.headers[header])
                    RichLogger.debug(f"Found {header} header: [bold cyan]{size}[/bold cyan] bytes")
                    return size
                except (ValueError, TypeError) as e:
                    RichLogger.debug(f"Failed to parse {header}: [bold cyan]{e}[/bold cyan]")

        RichLogger.debug("No file size information found in response headers")
        return None


    @classmethod
    def _is_partial(cls, response):
        """
        Determine if the server supports partial content requests (byte ranges).
        """
        # Check Transfer-Encoding: if it's chunked, partial content is not supported
        if 'Transfer-Encoding' in response.headers and response.headers.get('Transfer-Encoding', '').lower() == 'chunked':
            RichLogger.debug("Server uses chunked encoding, partial content not supported")
            return False

        # Check Accept-Ranges header
        supports_partial = ("Accept-Ranges" in response.headers and
                            response.headers.get('Accept-Ranges') == "bytes")

        # Additional check: if Content-Range header is present, it indicates partial content support
        if 'Content-Range' in response.headers:
            supports_partial = True

        RichLogger.debug(f"Server supports partial content: [bold cyan]{supports_partial}[/bold cyan]")
        return supports_partial


    @classmethod
    def _get_download_size(cls, file_path):
        """
        Retrieve the current size of a partially downloaded file.
        """
        if file_path.exists():
            size = file_path.stat().st_size
            RichLogger.debug(f"Existing file size: [bold cyan]{size}[/bold cyan] bytes")
            return size
        RichLogger.debug("File does not exist, starting from 0 bytes")
        return 0


    @classmethod
    def _get_content(cls, response, file_path, file_mode, progress, task, resume_position, expected_size):
        """
        Stream and save HTTP response content with progress tracking and validation.
        """
        downloaded = 0
        with open(file_path, file_mode) as file:
            # Use raw stream to avoid automatic decompression
            for chunk in response.raw.stream(cls.CHUNK_SIZE, decode_content=False):
                if chunk:
                    file.write(chunk)
                    downloaded += len(chunk)
                    # Update progress bar with accurate position
                    current_position = resume_position + downloaded
                    progress.update(task, completed=current_position)

        # Ensure progress bar reaches 100% when download completes
        if expected_size is not None:
            progress.update(task, completed=expected_size)
        return True


    @classmethod
    def _get_wget_headers(cls):
        """
        Generate HTTP headers that mimic the wget command-line tool behavior.
        """
        headers = {
            'User-Agent': "Wget/1.21.4",
            'Accept': "*/*",
            'Accept-Encoding': "identity",
            'Connection': "Keep-Alive",
        }
        return headers


    @classmethod
    def _create_progress_bar(cls):
        """
        Create a visually appealing progress bar for download tracking.
        """
        return Progress(
            "[progress.percentage]{task.percentage:>3.0f}%",
            BarColumn(
                bar_width=None,  # Use full available width
                style="bright_black on bright_black",  # Set both foreground and background to same color
                complete_style="bold bright_green on bright_green",  # Solid green for completed part
                finished_style="bold bright_green on bright_green"   # Solid green for finished
            ),
            "•",
            DownloadColumn(),
            "•",
            TransferSpeedColumn(),
            expand=True,
            transient=True
        )
