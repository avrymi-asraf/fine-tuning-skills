---
description: Install and initialize Google Cloud SDK (gcloud) on Linux
---
1. **Choose installation method** – interactive installer (recommended), apt repository, or manual archive.
   // turbo
   ```bash
   curl https://sdk.cloud.google.com | bash
   ```
2. **Restart shell** to load the new PATH.
   ```bash
   exec -l $SHELL
   ```
3. **Initialize the SDK** – authenticate and set default project/region.
   ```bash
   gcloud init
   ```
4. **Verify installation** – check version.
   ```bash
   gcloud version
   ```
5. **Optional: Install additional components** (e.g., beta, gsutil).
   ```bash
   gcloud components install beta gsutil
   ```
6. **Run a quick command** to confirm authentication.
   ```bash
   gcloud auth list
   ```
