# ⚡ GoJo I/O

> all protocols, one exchange.

4-in-1 disposable proxy server — VLESS, VMess, Trojan, Shadowsocks × WebSocket. Built on Xray-core + nginx. One-click deploy on Google Cloud Run.

---

## Protocols

| Protocol | Transport | Path |
|----------|-----------|------|
| VLESS | WebSocket | `/gojo/vless-ws/[suffix]` |
| VMess | WebSocket | `/gojo/vmess-ws/[suffix]` |
| Trojan | WebSocket | `/gojo/trojan-ws/[suffix]` |
| Shadowsocks | WebSocket | `/gojo/ss-ws/[suffix]` |

---

## GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |

---

## Deploy

1. Fork or clone this repo
2. Add GitHub Secrets
3. Push to `main` — auto-builds and pushes to Docker Hub
4. Deploy to Cloud Run using the Docker Hub image
5. Open the Cloud Run URL

---

## Pages

| URL | Description |
|-----|-------------|
| `/` | Landing page |
| `/status.json` | Server status + credentials |
| `/maintenance` | Maintenance page |

---

## Stack

- **Xray-core** · **nginx** · **supervisord** · **teddysun/xray** · **Google Cloud Run**
