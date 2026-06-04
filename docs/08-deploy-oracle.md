# 08 — Deploy lên Oracle Cloud Always Free

Plan deploy production Banan lên Oracle Cloud Always Free Tier — **0₫ hosting forever**, chỉ tốn ~280K/năm tiền domain.

## Tóm tắt kiến trúc

```
                          Internet
                              │
                              ▼
                    ┌─────────────────────┐
                    │   Cloudflare        │  ← DNS + CDN + DDoS + SSL termination
                    │   (Free plan)       │     (FREE)
                    └──────────┬──────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
        ▼                      ▼                      ▼
  banan.com           merchant.banan.com      api.banan.com
  kitchen.banan.com                                    │
        │                      │                      │
        ▼                      ▼                      ▼
  ┌────────────────────────────────────┐    ┌──────────────────┐
  │   Cloudflare Pages (3 projects)    │    │  Oracle VM       │
  │   - banan-customer                 │    │  Ampere ARM      │
  │   - banan-merchant                 │    │  4 OCPU / 24GB   │
  │   - banan-kitchen                  │    │  200GB SSD       │
  │   Static Flutter web build         │    │  Singapore       │
  │   (FREE, unlimited bandwidth)      │    │  (FREE forever)  │
  └────────────────────────────────────┘    │                  │
                                            │  ┌────────────┐  │
                                            │  │  Caddy     │  │ ← Reverse proxy
                                            │  │  (Docker)  │  │   + auto SSL
                                            │  └─────┬──────┘  │
                                            │        │         │
                                            │  ┌─────▼──────┐  │
                                            │  │ NestJS     │  │
                                            │  │ (port 3000)│  │
                                            │  └──┬──────┬──┘  │
                                            │     │      │     │
                                            │  ┌──▼─┐ ┌──▼──┐  │
                                            │  │ PG │ │Redis│  │
                                            │  │ 16 │ │  7  │  │
                                            │  └────┘ └─────┘  │
                                            │  /var/uploads    │
                                            └──────────────────┘
                                                     │
                                                     │ daily 02:00 ICT
                                                     ▼
                                            ┌──────────────────┐
                                            │ Cloudflare R2    │
                                            │ pg_dump backups  │
                                            │ (10GB FREE)      │
                                            └──────────────────┘
```

## Cost (năm đầu)

| Khoản | Cost |
|---|---|
| Oracle Cloud Ampere ARM VM 4 OCPU / 24GB / 200GB / 10TB egress | **0₫** forever |
| Cloudflare Free (DNS + CDN + DDoS + SSL) | **0₫** forever |
| Cloudflare Pages × 3 (Flutter web) | **0₫** forever |
| Cloudflare R2 backup (10GB) | **0₫** forever |
| Resend email free (3K email/tháng) | **0₫** |
| Domain `.com` trên Cloudflare Registrar | ~$10 = **~280K** |
| **TỔNG** | **~280K/năm** |

## Timeline tổng

| Phase | Time | Khi nào |
|---|---|---|
| **0** — Prep account | 30-60 min | Trước khi bắt đầu |
| **1** — Provision VM | 30-60 min | Có thể bị reject capacity, retry |
| **2** — Server hardening | 30 min | Bắt buộc trước khi expose |
| **3** — Docker stack (backend + DB + Redis + Caddy) | 60-90 min | Cốt lõi |
| **4** — Domain + DNS + SSL | 30 min | Sau khi DNS propagate ~5 min |
| **5** — Flutter web → Cloudflare Pages | 60 min | 3 project song song |
| **6** — Backup + monitoring + keepalive | 60 min | Bảo vệ data + tránh Oracle reclaim |
| **7** — CI/CD GitHub Actions | 30-60 min | Auto deploy on push |
| **8** — Seed prod data + smoke test | 30 min | Pre-launch |
| **TỔNG** | **~5-7 giờ** | Có thể spread 2-3 ngày |

---

## Phase 0 — Prep account (30-60 min)

### 0.1 Đăng ký Oracle Cloud (15-30 min, có thể retry)

1. Vào https://signup.cloud.oracle.com/
2. Chọn home region: **Singapore (Asia South - Singapore)** — KHÔNG ĐỔI ĐƯỢC sau khi tạo
3. Verify email
4. Verify thẻ Visa/Mastercard (không charge, chỉ check)
   - Nếu bị reject: dùng card khác hoặc thử lại 2-3 lần (Oracle hay reject random)
   - Card VN một số ngân hàng (Vietcombank Visa Debit, Techcombank) OK; một số khác bị fail
5. Nhập mật khẩu master account
6. Đăng nhập vào console: https://cloud.oracle.com/

**Risk:** Oracle hay reject signup từ VN. Mitigations:
- Thử nhiều card khác nhau
- Đăng ký bằng máy có VPN sang US/SG nếu dùng card VN bị từ chối
- Có thể nhờ bạn ở nước khác đăng ký, transfer ownership sau

### 0.2 Tạo Cloudflare account (5 min)

1. https://dash.cloudflare.com/sign-up → email + password
2. Chưa add domain — sẽ làm ở Phase 4

### 0.3 Mua domain trên Cloudflare Registrar (10 min)

1. Cloudflare Dashboard → Registrar → Register
2. Search `banan` → chọn `.com` available
3. Checkout (~$9.77 ~ 245K), thanh toán Visa
4. Domain tự động được add vào Cloudflare DNS

> Hoặc mua chỗ khác (Namecheap, Porkbun) rồi đổi nameserver về Cloudflare. Cloudflare Registrar bán giá wholesale nên rẻ nhất.

### 0.4 Setup local tools (10 min)

```bash
# Generate SSH key cho VM
ssh-keygen -t ed25519 -C "banan-deploy" -f ~/.ssh/banan_oracle
# → tạo ra ~/.ssh/banan_oracle (private) và ~/.ssh/banan_oracle.pub (public)

# Cài flyctl... à không, dùng wrangler cho Cloudflare Pages:
npm install -g wrangler
wrangler login
```

---

## Phase 1 — Provision Oracle Ampere VM (30-60 min)

### 1.1 Tạo VCN (Virtual Cloud Network)

Console → Networking → Virtual Cloud Networks → "Start VCN Wizard" → "Create VCN with Internet Connectivity" → đặt tên `banan-vcn` → defaults → Create.

### 1.2 Tạo VM Ampere ARM

Console → Compute → Instances → Create Instance:

- **Name**: `banan-vm`
- **Image**: Ubuntu 22.04 ARM64 (Canonical Ubuntu 22.04 aarch64)
- **Shape**: 
  - Click "Change shape" → "Ampere" → `VM.Standard.A1.Flex`
  - **OCPU**: 4 (tối đa free)
  - **Memory**: 24 GB (tối đa free)
- **Network**: VCN vừa tạo, public subnet, **Assign public IPv4 address**
- **SSH keys**: Paste nội dung `~/.ssh/banan_oracle.pub`
- **Boot volume**: 200 GB (tối đa free)
- Click **Create**

**Risk:** "Out of capacity" — Oracle hay hết Ampere ở Singapore. 
- **Mitigation 1**: Thử lại sau vài giờ (peak time toàn cầu thường 8-12am UTC)
- **Mitigation 2**: Dùng script auto-retry: https://github.com/hitrov/oci-arm-host-capacity
- **Mitigation 3**: Fallback sang 2× E2.1.Micro AMD (1/8 CPU + 1GB RAM mỗi VM) — không đủ chạy Banan, không khuyến nghị

### 1.3 Mở port firewall

Console → Networking → VCN → `banan-vcn` → Security Lists → Default Security List → Add Ingress Rules:

| Source CIDR | Port | Mô tả |
|---|---|---|
| `0.0.0.0/0` | 22 | SSH (sẽ giới hạn ở Phase 2) |
| `0.0.0.0/0` | 80 | HTTP (Caddy redirect → HTTPS) |
| `0.0.0.0/0` | 443 | HTTPS |

Trên VM (Ubuntu mặc định có iptables block):
```bash
ssh -i ~/.ssh/banan_oracle ubuntu@<public-ip>
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
```

### 1.4 Ghi nhớ thông tin

Sau khi VM running, ghi lại:
- Public IP: `xxx.xxx.xxx.xxx`
- SSH: `ssh -i ~/.ssh/banan_oracle ubuntu@<ip>`

---

## Phase 2 — Server hardening (30 min)

SSH vào VM, chạy:

```bash
# 2.1 Update OS
sudo apt update && sudo apt upgrade -y
sudo apt install -y ufw fail2ban unattended-upgrades htop git

# 2.2 Tạo user non-root cho deploy
sudo adduser banan --disabled-password --gecos ""
sudo usermod -aG sudo banan
sudo mkdir -p /home/banan/.ssh
sudo cp ~/.ssh/authorized_keys /home/banan/.ssh/
sudo chown -R banan:banan /home/banan/.ssh
sudo chmod 700 /home/banan/.ssh
sudo chmod 600 /home/banan/.ssh/authorized_keys

# 2.3 Disable root + password SSH
sudo sed -i 's/#PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# 2.4 UFW firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# 2.5 Fail2ban (chặn brute force SSH)
sudo systemctl enable --now fail2ban

# 2.6 Auto security updates
sudo dpkg-reconfigure -plow unattended-upgrades
# chọn Yes
```

Test SSH với user mới: `ssh -i ~/.ssh/banan_oracle banan@<ip>` — từ giờ dùng user này, không dùng `ubuntu` nữa.

---

## Phase 3 — Docker stack (60-90 min)

### 3.1 Cài Docker

```bash
ssh -i ~/.ssh/banan_oracle banan@<ip>

curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker banan
# Logout + login lại để effect group

docker --version
docker compose version
```

### 3.2 Clone repo

```bash
# Trên VM
sudo mkdir -p /opt/banan && sudo chown banan:banan /opt/banan
cd /opt/banan
git clone https://github.com/<YOUR_USERNAME>/banan.git .
```

> Nếu repo private: cần deploy key. Tạo SSH key trên VM `ssh-keygen -t ed25519 -C "banan-vm"`, paste public key vào GitHub repo → Settings → Deploy Keys.

### 3.3 Tạo `docker-compose.prod.yml`

> Plan: tôi sẽ generate file này trong Phase implement. Cấu trúc:

```yaml
# /opt/banan/docker-compose.prod.yml
services:
  caddy:
    image: caddy:2-alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./infra/Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    networks: [banan]

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile.prod
    restart: unless-stopped
    env_file: ./infra/.env.prod
    depends_on:
      postgres: { condition: service_healthy }
      redis: { condition: service_started }
    volumes:
      - uploads:/app/uploads
    networks: [banan]
    expose: ["3000"]

  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: banan
      POSTGRES_USER: banan
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks: [banan]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U banan"]
      interval: 5s

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redisdata:/data
    networks: [banan]

volumes:
  caddy_data:
  caddy_config:
  pgdata:
  redisdata:
  uploads:

networks:
  banan:
```

### 3.4 Caddyfile (reverse proxy + auto SSL)

```caddy
# /opt/banan/infra/Caddyfile
api.banan.com {
  reverse_proxy backend:3000

  # Trust Cloudflare IPs for X-Forwarded-For
  trusted_proxies static 173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 \
                         103.31.4.0/22 141.101.64.0/18 108.162.192.0/18 \
                         190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 \
                         198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 \
                         104.24.0.0/14 172.64.0.0/13 131.0.72.0/22
}
```

Caddy tự xin Let's Encrypt cert. Cloudflare nếu bật proxy (orange cloud) → cần tắt proxy cho `api.banan.com` để Caddy đăng ký cert được, hoặc dùng DNS challenge.

### 3.5 `Dockerfile.prod` cho backend

```dockerfile
# /backend/Dockerfile.prod
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY . .
RUN pnpm prisma generate
RUN pnpm run build

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma
COPY package.json ./
RUN mkdir -p /app/uploads
EXPOSE 3000
CMD ["sh", "-c", "pnpm prisma migrate deploy && node dist/main.js"]
```

### 3.6 Env file

```bash
# /opt/banan/infra/.env.prod
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://banan:${DB_PASSWORD}@postgres:5432/banan
REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379
JWT_ACCESS_SECRET=<openssl rand -hex 32>
JWT_REFRESH_SECRET=<openssl rand -hex 32>
CORS_ORIGIN=https://banan.com,https://merchant.banan.com,https://kitchen.banan.com
DB_PASSWORD=<strong random>
REDIS_PASSWORD=<strong random>
RESEND_API_KEY=<from resend.com>
```

Generate secrets:
```bash
openssl rand -hex 32  # cho mỗi JWT secret
openssl rand -base64 24  # cho mỗi password
```

### 3.7 First launch

```bash
cd /opt/banan
docker compose -f docker-compose.prod.yml --env-file infra/.env.prod up -d --build
docker compose logs -f backend  # check logs

# Seed dữ liệu
docker compose exec backend pnpm prisma db seed
```

---

## Phase 4 — Domain + DNS + SSL (30 min)

### 4.1 Cloudflare DNS records

Cloudflare Dashboard → `banan.com` → DNS → Add records:

| Type | Name | Content | Proxy |
|---|---|---|---|
| A | `@` | <Oracle VM public IP> | ❌ DNS only (sẽ chuyển sang Pages ở Phase 5) |
| A | `merchant` | <Oracle VM public IP> | ❌ DNS only |
| A | `kitchen` | <Oracle VM public IP> | ❌ DNS only |
| A | `api` | <Oracle VM public IP> | ❌ **DNS only** (Caddy cần cấp cert) |

### 4.2 Đợi DNS propagate

```bash
# Trên máy local
dig +short api.banan.com  # phải trả về IP của VM
```

Khi ra IP đúng → Caddy sẽ auto xin SSL khi gặp request đầu tiên.

### 4.3 Test backend

```bash
curl https://api.banan.com/api/v1/health
# → {"data":{"ok":true,...}}
```

Nếu SSL fail (DNS chưa propagate hoặc Cloudflare bật proxy), check Caddy logs:
```bash
docker compose logs caddy
```

### 4.4 Bật Cloudflare proxy cho api (optional, sau khi có cert)

Một khi cert đã issued, có thể bật proxy (orange cloud) cho `api.banan.com` → SSL mode Full (strict). Lúc đó CF cache tĩnh + DDoS protection.

> Nhưng nếu app dùng WebSocket (Socket.IO), cần bật **WebSockets** trong Network tab Cloudflare.

---

## Phase 5 — Flutter web → Cloudflare Pages (60 min)

### 5.1 Build local (1 lần test)

```bash
# Trên máy local — banan_customer
cd apps/banan_customer
flutter build web --release --base-href / \
  --dart-define=API_URL=https://api.banan.com/api/v1

# build/web/ là thư mục output
```

### 5.2 Tạo 3 project trên Cloudflare Pages

Cloudflare Dashboard → Workers & Pages → Create application → Pages → "Connect to Git" → chọn GitHub repo.

**Project 1: `banan-customer`**
- Production branch: `main`
- Build command:
  ```bash
  cd apps/banan_customer && flutter build web --release --base-href / --dart-define=API_URL=https://api.banan.com/api/v1
  ```
- Build output directory: `apps/banan_customer/build/web`
- Root directory: `/`
- Environment variables:
  - `FLUTTER_VERSION` = `3.27.0` (hoặc phiên bản đang dùng)

**Project 2: `banan-merchant`** — tương tự, build path đổi sang `apps/banan_merchant`

**Project 3: `banan-kitchen`** — tương tự `apps/banan_kitchen`

### 5.3 Custom domain

Mỗi Cloudflare Pages project → Custom domains → Set up:
- `banan-customer` → add custom domain `banan.com` + `www.banan.com`
- `banan-merchant` → add `merchant.banan.com`
- `banan-kitchen` → add `kitchen.banan.com`

CF tự update DNS record (A `@` của VM được giữ vì pages dùng CNAME riêng).

### 5.4 Flutter web cần custom build environment

Cloudflare Pages default không có Flutter. Tạo `apps/banan_customer/build.sh`:

```bash
#!/bin/bash
set -e

# Cài Flutter
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 $HOME/flutter
fi
export PATH="$HOME/flutter/bin:$PATH"

flutter --version
flutter pub get
flutter build web --release \
  --dart-define=API_URL=https://api.banan.com/api/v1
```

Build command trên Cloudflare Pages: `bash apps/banan_customer/build.sh`

> Cloudflare cache `$HOME/flutter` giữa các build → lần 2 trở đi nhanh ~2 phút.

---

## Phase 6 — Backup + monitoring + keepalive (60 min)

### 6.1 Cloudflare R2 backup setup

1. CF Dashboard → R2 → Create bucket `banan-backups`
2. Manage R2 API Tokens → Create:
   - Permission: Object Read & Write
   - Specify bucket: `banan-backups`
3. Lưu Access Key ID + Secret Access Key

### 6.2 Backup script trên VM

```bash
# /opt/banan/infra/backup.sh
#!/bin/bash
set -e

DATE=$(date +%Y%m%d_%H%M%S)
DUMP_DIR=/tmp/banan-backup
mkdir -p $DUMP_DIR

# Postgres dump
docker compose -f /opt/banan/docker-compose.prod.yml exec -T postgres \
  pg_dump -U banan banan | gzip > $DUMP_DIR/db_$DATE.sql.gz

# Uploads tarball
docker run --rm -v banan_uploads:/data -v $DUMP_DIR:/backup alpine \
  tar czf /backup/uploads_$DATE.tar.gz -C /data .

# Upload lên R2 (dùng rclone)
rclone copy $DUMP_DIR/db_$DATE.sql.gz r2:banan-backups/db/
rclone copy $DUMP_DIR/uploads_$DATE.tar.gz r2:banan-backups/uploads/

# Cleanup local
rm -f $DUMP_DIR/db_$DATE.sql.gz $DUMP_DIR/uploads_$DATE.tar.gz

# Cleanup R2 (giữ 30 ngày)
rclone delete --min-age 30d r2:banan-backups/db/
rclone delete --min-age 30d r2:banan-backups/uploads/
```

Cài rclone + config:
```bash
sudo apt install -y rclone
rclone config  # tạo remote tên "r2" với credentials R2
chmod +x /opt/banan/infra/backup.sh
```

Cron:
```bash
crontab -e
# Thêm:
0 19 * * * /opt/banan/infra/backup.sh >> /var/log/banan-backup.log 2>&1
# (19:00 UTC = 02:00 ICT)
```

### 6.3 Keepalive (tránh Oracle reclaim Ampere idle)

Oracle thu hồi Ampere VM nếu CPU < 20% trong 7 ngày. Force giữ load nhẹ:

```bash
# /etc/cron.d/banan-keepalive
*/30 * * * * banan /usr/bin/stress -c 1 -t 60 >/dev/null 2>&1
```

```bash
sudo apt install -y stress
```

→ Spike 1 CPU 60s mỗi 30 phút = đủ tránh reclaim, không tốn gì.

### 6.4 Uptime monitoring

**Option A — Cloudflare Health Checks** (paid plan only)

**Option B — UptimeRobot free** (5 phút interval)
- https://uptimerobot.com/ → New monitor
- HTTPs `https://api.banan.com/api/v1/health` mỗi 5 phút
- Alert sang email + Telegram bot

**Option C — Self-hosted Uptime Kuma** trên cùng VM (Docker, 0 cost):
```yaml
# Thêm vào docker-compose.prod.yml
uptime:
  image: louislam/uptime-kuma:1
  restart: unless-stopped
  volumes:
    - uptime_data:/app/data
  expose: ["3001"]
  networks: [banan]
```
Thêm vào Caddyfile: `uptime.banan.com { reverse_proxy uptime:3001 }`

### 6.5 Log rotation

```bash
sudo nano /etc/logrotate.d/docker-banan
```
```
/var/lib/docker/containers/*/*.log {
  daily
  rotate 7
  compress
  size 100M
  missingok
  notifempty
  copytruncate
}
```

---

## Phase 7 — CI/CD GitHub Actions (30-60 min)

### 7.1 Secrets trên GitHub

Repo Settings → Secrets and variables → Actions → New:

| Name | Value |
|---|---|
| `ORACLE_VM_HOST` | Public IP của VM |
| `ORACLE_VM_USER` | `banan` |
| `ORACLE_VM_SSH_KEY` | Nội dung `~/.ssh/banan_oracle` (private key) |

### 7.2 Workflow file

```yaml
# .github/workflows/deploy-backend.yml
name: Deploy backend to Oracle

on:
  push:
    branches: [main]
    paths:
      - 'backend/**'
      - 'docker-compose.prod.yml'
      - 'infra/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: SSH deploy
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.ORACLE_VM_HOST }}
          username: ${{ secrets.ORACLE_VM_USER }}
          key: ${{ secrets.ORACLE_VM_SSH_KEY }}
          script: |
            cd /opt/banan
            git fetch origin
            git reset --hard origin/main
            docker compose -f docker-compose.prod.yml --env-file infra/.env.prod up -d --build backend
            docker image prune -f
```

> Cloudflare Pages tự deploy khi push tới `apps/banan_customer/**` nhờ Pages auto-detect.

### 7.3 Test pipeline

```bash
# Local — push 1 commit dummy
git commit --allow-empty -m "test ci"
git push origin main
```

→ Xem GitHub Actions tab. Build xong ~3-5 phút, backend live.

---

## Phase 8 — Pre-launch checklist (30 min)

### 8.1 Seed prod data

```bash
ssh banan@<vm-ip>
cd /opt/banan
docker compose exec backend pnpm prisma db seed
```

Sau đó **đổi mật khẩu admin** ngay:
```bash
docker compose exec postgres psql -U banan -d banan
# UPDATE "User" SET "passwordHash" = '<bcrypt-hash>' WHERE email = 'admin@banan.local';
```

### 8.2 Smoke test

Chạy 2 script test đã có:
```bash
# Trên máy local, đổi API endpoint
API=https://api.banan.com/api/v1 bash backend/scripts/test-all-wards.sh
API=https://api.banan.com/api/v1 bash backend/scripts/test-order-creation.sh
```

### 8.3 Final checks

- [ ] Backend health: `curl https://api.banan.com/api/v1/health`
- [ ] Customer web: open `https://banan.com` → menu load được
- [ ] Merchant web: open `https://merchant.banan.com` → login admin
- [ ] Kitchen web: open `https://kitchen.banan.com`
- [ ] Đặt 1 đơn thật → check merchant nhận realtime
- [ ] Test review submit + wishlist + VAT invoice
- [ ] Test backup: `bash /opt/banan/infra/backup.sh` chạy thủ công, check R2 có file
- [ ] UptimeRobot báo 200 OK

### 8.4 Go live

- Update README với production URLs
- Đổi `.env.prod` Resend API key
- Đổi VNPay/MoMo sang production credentials (sau khi đã verify merchant)

---

## Bảo trì hàng tháng (~30 phút/tháng)

1. **SSH vào VM check**:
   ```bash
   df -h          # disk usage
   free -h        # RAM
   docker compose ps   # services up
   docker stats --no-stream  # resource usage
   ```

2. **Update OS**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo reboot   # nếu kernel update
   ```

3. **Pull latest backend**:
   ```bash
   cd /opt/banan && git pull && docker compose -f docker-compose.prod.yml up -d --build
   ```

4. **Verify backup restore** (1 lần/quý):
   ```bash
   # Lấy 1 dump từ R2 → restore vào DB test → verify data → drop
   ```

5. **Review logs**:
   ```bash
   docker compose logs --since 7d backend | grep ERROR
   ```

---

## Migration path khi hết tier free (Tier 2)

Khi đơn > 100/ngày hoặc DB > 1GB:

1. **Postgres → Supabase Pro $25/tháng** (managed, backup tự động, point-in-time recovery)
2. **App vẫn trên Oracle VM** — backend không cần upgrade
3. **Uploads → Cloudflare R2** (đã có account) — di chuyển volume sang R2

Chi phí lúc đó: ~25-35$/tháng (~625K-875K VND), thay vì migrate toàn bộ ngay.

---

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Oracle reclaim VM | Medium | High | Keepalive cron + backup R2 — restore mất ~30 phút |
| Oracle account banned | Low | High | Backup R2 + có doc deploy → migrate Contabo 1h |
| DDoS attack | Low | Medium | Cloudflare proxy + rate limit NestJS |
| DB corruption | Very low | High | Daily R2 backup, restore từ snapshot |
| Domain hijack | Very low | High | Cloudflare 2FA + registrar lock |
| SSL cert fail | Low | Low | Caddy auto-retry; UptimeRobot báo |
| ARM compatibility lib | Low | Medium | Hầu hết npm package ARM OK; Sharp/bcrypt có ARM binary |

---

## What I'll generate next

Khi bạn sẵn sàng implement plan này, tôi sẽ tạo:

1. `infra/docker-compose.prod.yml` — full stack production
2. `backend/Dockerfile.prod` — multi-stage build cho ARM
3. `infra/Caddyfile` — reverse proxy với Cloudflare trusted proxies
4. `infra/.env.prod.example` — template env (đừng commit secret thật)
5. `infra/backup.sh` — pg_dump + rclone tới R2
6. `infra/keepalive.cron` — Oracle reclaim prevention
7. `apps/banan_customer/build.sh` (và merchant/kitchen) — Flutter build cho Cloudflare Pages
8. `.github/workflows/deploy-backend.yml` — CI/CD trên push main
9. `docs/09-runbook.md` — operations runbook (restart, restore, scale up)

Tell me "bắt đầu" hoặc "implement phase X" để tôi tạo các file.
