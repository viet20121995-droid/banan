# Banan — production deployment guide

End-to-end recipe for taking your local Banan stack to a live URL with a
custom domain, real Postgres, and a CDN-backed customer web app. The
hybrid Google-Cloud-Run + Cloudflare-Pages + Neon approach below costs
about **$10/yr + $0–5/mo** at low traffic and scales to thousands of
customers without re-architecting.

## What you'll have when you're done

- **`https://banan.yourdomain.com`** — customer web app
- **`https://merchant.banan.yourdomain.com`** — merchant web app
- **`https://kitchen.banan.yourdomain.com`** — kitchen web app
- **`https://api.banan.yourdomain.com`** — REST + WebSocket backend
- Managed Postgres database with daily backups
- Free SSL on every subdomain (auto-renewing)
- Fast Vietnam-region CDN in front of everything

## Time and cost budget

| Step | Time | Cost |
|------|------|------|
| Buy domain | 5 min | $10/yr |
| Google Cloud account + billing | 10 min | $0 to start ($300 free credit) |
| Neon Postgres signup | 5 min | $0 |
| Cloudflare account | 5 min | $0 |
| Deploy backend to Cloud Run | 30 min | $0–5/mo |
| Deploy 3 Flutter sites to Cloudflare Pages | 20 min | $0 |
| DNS + custom domains wired | 15 min | included |
| **Total: ~90 min, ~$10/yr + $5/mo** | | |

---

## Step 1 — Buy your domain (5 min)

Use **Cloudflare Registrar** — they sell at cost (~$10/yr .com) and the DNS
is already integrated.

1. Sign up at https://dash.cloudflare.com/sign-up (no credit card to browse)
2. Once in: **Domain Registration → Register Domains**
3. Search for `yourbakery.com` (or `.vn` if you want Vietnamese TLD — different registrar needed for `.vn`; use Mat Bao or PA Vietnam for those)
4. Buy with credit card. **Save the email confirmation.**
5. Cloudflare DNS is automatic — you'll add records in Step 7.

**If you want `.vn`:** Use https://matbao.net or https://pavietnam.vn. After buying, change the nameservers to Cloudflare's (Cloudflare gives you two NS records when you "Add a site"). All other instructions still apply.

---

## Step 2 — Google Cloud setup (10 min)

1. Go to https://console.cloud.google.com → sign in with any Google account
2. **Create a project**: dropdown top-left → **New project** → name it `banan-prod`
3. **Enable billing**: bottom-left → **Billing** → **Link a billing account** → add credit card. Google gives **$300 free credit valid 90 days**, more than enough to fully launch and run for the first quarter.
4. **Enable APIs you'll need** (this batches them):
   ```pwsh
   gcloud services enable run.googleapis.com `
     artifactregistry.googleapis.com `
     cloudbuild.googleapis.com `
     secretmanager.googleapis.com
   ```
   Or do it in the Console: **APIs & Services → Library** → search and enable each.
5. **Install gcloud CLI**: https://cloud.google.com/sdk/docs/install (Windows installer)
6. **Authenticate**:
   ```pwsh
   gcloud auth login
   gcloud config set project banan-prod
   gcloud config set run/region asia-southeast1   # Singapore — closest to Vietnam
   ```

---

## Step 3 — Set up Postgres on Neon (5 min)

You can use Cloud SQL inside Google Cloud, but the **cheapest tier is $10/mo
even when idle**. Neon's free tier is 0.5 GB with auto-suspend — enough for a
small bakery to run for years.

1. Sign up at https://neon.tech (use the same email as Google for tidiness)
2. **Create project** → name it `banan-prod` → region **Singapore (ap-southeast-1)**
3. After creation, copy the **Pooled connection string** — looks like:
   ```
   postgresql://user:pwd@ep-xxx.ap-southeast-1.aws.neon.tech/banan?sslmode=require
   ```
   Save this somewhere safe — it's your `DATABASE_URL`.
4. **Apply migrations** locally before deploying:
   ```pwsh
   cd backend
   $env:DATABASE_URL = "<paste-neon-url-here>"
   pnpm prisma migrate deploy
   pnpm prisma db seed   # optional, gives you sample data
   ```

(Alternative if you really want all-Google: use **Cloud SQL** with a `db-f1-micro` instance and 10 GB storage — ~$10/mo. Same `DATABASE_URL` shape, just point at the Cloud SQL public IP with `?sslmode=require`.)

---

## Step 4 — Deploy backend to Cloud Run (15 min)

Your `backend/Dockerfile` already exists — Cloud Run reads it directly.

```pwsh
cd C:\dev\Banan\backend

# Build + push to Google's Artifact Registry, then deploy to Cloud Run.
gcloud run deploy banan-api `
  --source . `
  --region asia-southeast1 `
  --allow-unauthenticated `
  --port 3000 `
  --memory 512Mi `
  --cpu 1 `
  --min-instances 0 `
  --max-instances 5 `
  --timeout 300 `
  --set-env-vars "NODE_ENV=production,CORS_ORIGINS=https://banan.yourdomain.com,https://merchant.banan.yourdomain.com,https://kitchen.banan.yourdomain.com" `
  --set-secrets "DATABASE_URL=banan-database-url:latest,JWT_ACCESS_SECRET=banan-jwt-access:latest,JWT_REFRESH_SECRET=banan-jwt-refresh:latest,VNPAY_TMN_CODE=banan-vnpay-tmn:latest,VNPAY_HASH_SECRET=banan-vnpay-hash:latest"
```

But first, **store the secrets in Secret Manager**:

```pwsh
# DATABASE_URL — from Neon (Step 3)
"YOUR-NEON-URL" | gcloud secrets create banan-database-url --data-file=-

# JWT secrets — generate fresh ones
$jwtAccess = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | % {[char]$_})
$jwtRefresh = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | % {[char]$_})
$jwtAccess | gcloud secrets create banan-jwt-access --data-file=-
$jwtRefresh | gcloud secrets create banan-jwt-refresh --data-file=-

# VNPay (from your sandbox email earlier)
"STC2HT80" | gcloud secrets create banan-vnpay-tmn --data-file=-
"G669C7FNYQGPVO872NNBOD0Y1GFBWYEK" | gcloud secrets create banan-vnpay-hash --data-file=-
```

Grant Cloud Run access to those secrets:

```pwsh
$project = gcloud config get-value project
$svcAccount = "$project-compute@developer.gserviceaccount.com"
foreach ($s in @("banan-database-url","banan-jwt-access","banan-jwt-refresh","banan-vnpay-tmn","banan-vnpay-hash")) {
  gcloud secrets add-iam-policy-binding $s --member="serviceAccount:$svcAccount" --role="roles/secretmanager.secretAccessor"
}
```

Re-run the `gcloud run deploy` command above. You'll get a URL like
`https://banan-api-xxxxx-as.a.run.app`. **Test it**:

```pwsh
curl https://banan-api-xxxxx-as.a.run.app/api/v1/health
# → {"data":{"ok":true,"environment":"production",...}}
```

---

## Step 5 — Deploy 3 Flutter web sites to Cloudflare Pages (15 min)

Each Flutter app builds to a static folder. Cloudflare Pages serves them
free with built-in CDN and SSL.

### 5a — Build each app locally with production URLs

```pwsh
$apiUrl = "https://banan-api-xxxxx-as.a.run.app/api/v1"  # use your Cloud Run URL
$wsUrl  = "wss://banan-api-xxxxx-as.a.run.app"

# Customer
cd C:\dev\Banan\apps\banan_customer
flutter build web --release `
  --dart-define=BANAN_API_BASE_URL=$apiUrl `
  --dart-define=BANAN_WS_URL=$wsUrl `
  --dart-define=BANAN_ENV=prod

# Merchant
cd C:\dev\Banan\apps\banan_merchant
flutter build web --release `
  --dart-define=BANAN_API_BASE_URL=$apiUrl `
  --dart-define=BANAN_WS_URL=$wsUrl `
  --dart-define=BANAN_ENV=prod `
  --dart-define=BANAN_CUSTOMER_APP_URL=https://banan.yourdomain.com

# Kitchen
cd C:\dev\Banan\apps\banan_kitchen
flutter build web --release `
  --dart-define=BANAN_API_BASE_URL=$apiUrl `
  --dart-define=BANAN_WS_URL=$wsUrl `
  --dart-define=BANAN_ENV=prod
```

### 5b — Push to Cloudflare Pages

Install Wrangler if you haven't: `npm install -g wrangler`, then `wrangler login`.

```pwsh
cd C:\dev\Banan\apps\banan_customer
wrangler pages deploy build/web --project-name=banan-customer

cd C:\dev\Banan\apps\banan_merchant
wrangler pages deploy build/web --project-name=banan-merchant

cd C:\dev\Banan\apps\banan_kitchen
wrangler pages deploy build/web --project-name=banan-kitchen
```

You'll get three `*.pages.dev` URLs. Test them.

---

## Step 6 — Wire up your custom domain (15 min)

### 6a — Move the domain's DNS to Cloudflare (if you bought elsewhere)

If you bought from Cloudflare Registrar, skip — it's already there.
Otherwise: **Cloudflare → Websites → Add a site** → enter `yourdomain.com`
→ free plan → Cloudflare gives you two nameservers like `arya.ns.cloudflare.com`. Go to your registrar (Mat Bao, PA Vietnam, etc.), change the
nameservers to those two. Wait 1–24 hours for propagation.

### 6b — Add the Cloud Run domain mapping

```pwsh
# Map api.banan.yourdomain.com → banan-api Cloud Run service
gcloud beta run domain-mappings create `
  --service banan-api `
  --domain api.banan.yourdomain.com `
  --region asia-southeast1
```

It prints a `CNAME` record value (e.g., `ghs.googlehosted.com`). Open
Cloudflare → **DNS** → **Add record**:

- Type: `CNAME`
- Name: `api.banan`
- Target: `ghs.googlehosted.com`
- Proxy status: **DNS only** (gray cloud — Cloud Run handles SSL)

### 6c — Attach the three Cloudflare Pages projects to subdomains

In Cloudflare dashboard → **Pages** → click each project → **Custom domains**
→ **Set up a custom domain**:

| Project | Custom domain |
|---|---|
| `banan-customer` | `banan.yourdomain.com` |
| `banan-merchant` | `merchant.banan.yourdomain.com` |
| `banan-kitchen` | `kitchen.banan.yourdomain.com` |

Cloudflare auto-creates the DNS records and provisions SSL.

### 6d — Update CORS_ORIGINS on Cloud Run

```pwsh
gcloud run services update banan-api `
  --region asia-southeast1 `
  --update-env-vars CORS_ORIGINS="https://banan.yourdomain.com,https://merchant.banan.yourdomain.com,https://kitchen.banan.yourdomain.com"
```

### 6e — Rebuild & redeploy the Flutter sites with the real custom-domain API URL

Yes, this rebuild is necessary — the API URL is baked into the dart2js
bundle. Repeat Step 5a with `BANAN_API_BASE_URL=https://api.banan.yourdomain.com/api/v1` and Step 5b.

---

## Step 7 — Update VNPay return URL to production

In your VNPay sandbox merchant dashboard
(https://sandbox.vnpayment.vn/merchantv2/) update:

- **Return URL**: `https://api.banan.yourdomain.com/api/v1/payments/vnpay/return`
- **IPN URL**: `https://api.banan.yourdomain.com/api/v1/payments/vnpay/ipn`

Then update the Cloud Run env:

```pwsh
gcloud run services update banan-api `
  --region asia-southeast1 `
  --update-env-vars `
    VNPAY_RETURN_URL=https://api.banan.yourdomain.com/api/v1/payments/vnpay/return,VNPAY_IPN_URL=https://api.banan.yourdomain.com/api/v1/payments/vnpay/ipn,CUSTOMER_APP_BASE_URL=https://banan.yourdomain.com
```

---

## Step 8 — Smoke test

1. Open `https://banan.yourdomain.com` in incognito → menu loads, no login required
2. Add a cake → checkout → fill guest contact → pay with VNPay sandbox card → redirect → order detail
3. Open `https://merchant.banan.yourdomain.com` → log in with seed merchant account → see the order
4. Open `https://kitchen.banan.yourdomain.com` → log in → see kitchen kanban

---

## What it will cost monthly at different scales

| Customers/day | Cloud Run | Neon | Cloudflare | Total |
|---|---|---|---|---|
| 0–20 (testing) | $0 (free tier) | $0 | $0 | **$0** |
| 50–100 real | $2–5 | $0 | $0 | **$2–5** |
| 500+ | $15–25 | $0 (still under 0.5 GB) | $0 | **$15–25** |
| 2,000+ | $40–80 | $19/mo (upgrade to Launch plan) | $0 | **$60–100** |

Domain: flat $10/yr.

---

## Ongoing maintenance

- **Backend updates**: `gcloud run deploy banan-api --source .` from `backend/` — same command as Step 4. Cloud Run keeps the secrets and env vars from before.
- **Flutter updates**: rebuild + `wrangler pages deploy` for the affected app(s).
- **Database backups**: Neon snapshots every day; restore from any 7-day point with one click.
- **Logs**: `gcloud run logs read banan-api --region asia-southeast1` or use the Cloud Console UI.
- **Custom domain monitoring**: Cloudflare → Analytics → uptime + traffic.

---

## CI/CD upgrade (optional, when you have a team)

When you have multiple developers, set up GitHub Actions to auto-deploy
on push to `main`:

- `backend/`: `google-github-actions/deploy-cloudrun@v2`
- Flutter apps: `cloudflare/pages-action@v1`

Total CI setup is ~30 min. Ask me later — I'll write the workflows.

---

## Alternative: cheapest possible setup (pure Cloudflare)

If you want to **completely skip Google Cloud**:

- **Backend** → Cloudflare Workers Containers (in beta, $5/mo) **or** stay on Fly.io trial with a card on file
- **Postgres** → Neon (same as above)
- **Flutter web** → Cloudflare Pages (same)
- **Storage for cake photos** → Cloudflare R2 (free 10 GB)

Total ~$5/mo, all in one provider's dashboard.

---

## Got stuck?

The most common pitfalls:

| Symptom | Fix |
|---|---|
| `gcloud run deploy` fails with "service account does not have permission" | Re-run the `secrets add-iam-policy-binding` block in Step 4 |
| Custom domain shows "Site not found" 24h after setup | Check the CNAME target matches what `gcloud run domain-mappings describe` returned; Cloudflare proxy status must be **DNS only** for the api subdomain |
| Customer site CORS error | Check `CORS_ORIGINS` includes the **exact** customer URL (no trailing slash, with scheme) and you re-deployed Cloud Run after changing it |
| Flutter web shows blank page | Hard-refresh (Ctrl+Shift+R) to clear the bundle cache, then check browser console for the API URL — if it points at `localhost:3000`, the `--dart-define` didn't take. Rebuild and redeploy |
| VNPay "Sai chữ ký" (wrong signature) | Means HMAC mismatch — check that `VNPAY_HASH_SECRET` is set in Cloud Run and the return URL in the VNPay dashboard exactly matches the one configured |

Ping me with the error and I'll diagnose.
