# Blueprint: Linwood Butterfly (Infinite Canvas Note-Taking Web App)

## Overview & Homelab Value

[Linwood Butterfly](https://butterfly.linwood.dev/) is an open-source, cross-platform infinite canvas note-taking and visual thinking application. The web version is compiled with Flutter Web (WASM) and served as a lightweight static SPA via `nginx:1-alpine`.

### Key Capabilities & Architecture:
- **Infinite Canvas Notes**: Freehand drawing, shapes, text, markdown, PDF/image annotations, and structured packs/templates.
- **Stateless Web Server**: Runs strictly as a lightweight static frontend served by Nginx on port `80` (~16MiB RAM requested).
- **Zero Backend Dependencies**: No external database, persistent volume, or cluster secrets required.

---

## Architectural Specifications

- **Target Namespace**: `butterfly`
- **Directory**: `k8s/10_apps/19_butterfly`
- **Ingress FQDNs**:
  - `https://butterfly.local.naguiar.dev`
  - `https://butterfly.naguiar.dev`
- **Database Required**: None (Stateless).
- **Storage Required**: None (client-side browser storage + `.bfly` file import/export).

---

## Deployment & Usage Notes

> [!NOTE]
> **Remote Storage (WebDAV)**: WebDAV remote storage connections (e.g., Nextcloud) are only supported in Butterfly's native desktop and mobile clients, not in the web app. Notes created in the web version reside in client-side browser storage and can be exported/imported as `.bfly` files.

> [!NOTE]
> **Real-Time Collaboration (Swamp)**: Upstream's [Swamp](https://github.com/LinwoodDev/Swamp) WebSocket proxy for live collaborative sessions is marked WIP / not production-ready and is intentionally omitted from this deployment.
