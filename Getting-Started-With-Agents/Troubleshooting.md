
Error message:
```
httpx.HTTPStatusError: Client error '401 Unauthorized' for url 'https://cloud.uipath.com/[tenant]/studio_/...'
```
Your auth token likely timed out, run this command:
```bash
uipath auth
```
