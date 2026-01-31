from botasaurus.browser import browser, Driver
import sys
import json

# Botasaurus Cloudflare Bypass Scraper
# This script is specifically for bypassing Cloudflare protection (e.g. UCars)


@browser(
    headless=False,
    reuse_driver=True,
    block_images_and_css=False,
    close_on_crash=True,
    max_retry=3,
)
def scrape(driver: Driver, url):
    """
    Scrapes the target URL using Google Referrer and Cloudflare Bypass.
    """
    try:
        # Visit using Google Referrer and Cloudflare Bypass
        driver.google_get(url, bypass_cloudflare=True)

        # Wait for potential Cloudflare challenge or page load
        driver.long_random_sleep()

        # Check if still blocked
        page_html = driver.page_html
        if "Just a moment" in page_html or "cf-" in page_html.lower():
            driver.sleep(10)
            page_html = driver.page_html

        return {
            "url": url,
            "status": 200,  # If we got here, we assume success
            "title": driver.title,
            "html": page_html,
        }
    except Exception as e:
        return {"error": str(e)}


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No URL provided"}))
        sys.exit(1)

    url = sys.argv[1]

    try:
        # Run the scraper
        result = scrape(url)
        print(json.dumps(result, default=str))
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)
