# Overlay Images — Client Integration Guide

This document covers how mobile clients (iOS/Android) interact with the overlay image system to let viewers trigger images and GIFs on Burke's stream.

## Overview

The overlay image system has two modes:

1. **Static images** — Pre-uploaded images configured by moderators (stored in the panel DB)
2. **GIFs** — Searched via Klipy, returned as encrypted URLs + opaque trigger tokens

Both are triggered through the same endpoint. The image appears on Burke's OBS overlay via a WebSocket broadcast.

---

## Base URLs

| Service | URL |
|---------|-----|
| App API | `https://api.burkeblack.tv/app` |
| Bot Trigger API | `https://burkeblack.tv/bot/v2` |

---

## Authentication

### App API (`/app/*` endpoints)

Used for listing images, getting GIF decrypt keys, and searching GIFs. Requires a Bearer token:

```
Authorization: Bearer <app_token>
```

The token comes from the Twitch OAuth login flow (`POST /app/auth`). It has a 30-day rolling expiry that extends on each use.

### Bot Trigger API (`/bot/v2/*` endpoints)

Used for triggering images/GIFs on stream. Uses `UPLOAD_API_KEY` via POST body parameter `key`.

---

## Part 1: Static Images

### Listing Available Images

```
GET /app/overlay-images?filter={filter}
Authorization: Bearer <app_token>
```

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `filter` | No | `all` | Audience filter: `all`, `followers`, `subs`, or `mods` |

The `filter` parameter controls which images are returned based on their audience permissions. The filter is inclusive of lower tiers:

| Filter | Returns images where |
|--------|---------------------|
| `all` | `allow_all = 1` |
| `followers` | `allow_all = 1` OR `allow_followers = 1` |
| `subs` | `allow_all = 1` OR `allow_followers = 1` OR `allow_subs = 1` |
| `mods` | `allow_all = 1` OR `allow_followers = 1` OR `allow_subs = 1` OR `allow_mods = 1` |

The client should pass the appropriate filter based on the user's known status. The listing endpoint does **not** verify the user's actual Twitch status — that validation happens on the trigger endpoint.

**Response (200):**
```json
{
    "api_version": 1,
    "success": true,
    "data": {
        "categories": [
            { "id": 1, "name": "Memes" },
            { "id": 2, "name": "Emotes" }
        ],
        "images": [
            {
                "id": 5,
                "name": "PepeLaugh",
                "category_id": 1,
                "thumbnail_url": "https://burkeblack.tv/panel/uploads/overlay_images/abc123.png",
                "allow_all": true,
                "allow_followers": false,
                "allow_subs": false,
                "allow_mods": false,
                "modes": {
                    "large":  { "width": 400, "height": 400, "duration": 10 },
                    "medium": { "width": 300, "height": 300, "duration": 10 },
                    "small":  { "width": 150, "height": 150, "duration": 10 },
                    "bounce": { "width": 100, "height": 100, "duration": 10, "count": 10 }
                }
            }
        ]
    }
}
```

**Field details:**

| Field | Type | Description |
|-------|------|-------------|
| `categories` | array | All categories (id + name). Use to group images in the UI. |
| `images[].id` | int | Image ID — pass this to the trigger endpoint |
| `images[].name` | string | Display name |
| `images[].category_id` | int or null | Category this image belongs to |
| `images[].thumbnail_url` | string | Full URL to the image file — use for preview thumbnails |
| `images[].allow_*` | bool | Audience permission flags |
| `images[].modes` | object | Per-mode dimensions and durations |
| `images[].modes.bounce.count` | int | Number of bouncing copies in bounce mode |

### Triggering a Static Image

```
POST https://burkeblack.tv/bot/v2/triggerOverlayImage.php
Content-Type: application/x-www-form-urlencoded
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `key` | Yes | `UPLOAD_API_KEY` |
| `image_id` | Yes* | Single image ID (integer) |
| `image_ids` | Yes* | Comma-separated image IDs for multi-image modes (e.g. `1,5,12`) |
| `mode` | Yes | `large`, `medium`, `small`, `bounce`, or `bounce-multi` |
| `duration` | No | Override duration in seconds (1-300). Defaults to the per-mode duration configured on the image. |
| `username` | No | Twitch username of the viewer who triggered it (default: `unknown`) |
| `source` | No | Client identifier: `app_ios` or `app_android` (default: `unknown`) |

*One of `image_id`, `image_ids`, or `gif_token` is required.

**Display modes:**

| Mode | Behavior | Use case |
|------|----------|----------|
| `large` | Single image, centered on screen | Full-screen impact moments |
| `medium` | Single image, centered on screen | Standard display |
| `small` | Single image, centered on screen | Subtle/minimal display |
| `bounce` | N copies of one image bouncing around (DVD screensaver style) | Fun/chaotic moments |
| `bounce-multi` | Multiple different images bouncing simultaneously | Requires multiple `image_ids` |

**Success response (200):**
```json
{
    "success": true,
    "message": "Image overlay triggered",
    "images_shown": 1,
    "mode": "large",
    "duration": 10
}
```

**Error responses:**

| Code | Condition |
|------|-----------|
| 400 | Invalid mode, missing IDs, no valid IDs |
| 403 | Invalid or missing API key |
| 404 | No enabled images found for given IDs |
| 405 | Non-POST request |
| 502 | Socket server unreachable |

---

## Part 2: GIF Search and Trigger

GIF search uses a two-key encryption system:

- **Temp decrypt key** (per-session, 6hr expiry): The client obtains this key and uses it to decrypt GIF URLs for display. Stored server-side in the auth token record.
- **Server key** (`GIF_ENCRYPTION_KEY`, permanent): Encrypts the trigger token (GIF ID + timestamp). The client never has access to this key — tokens are opaque and passed through to the trigger endpoint.

### Step 1: Get a Temporary Decrypt Key

Call this once when the user enters the GIF search UI. The key lasts 6 hours.

```
POST /app/gifs/key
Authorization: Bearer <app_token>
```

No request body required.

**Response (200):**
```json
{
    "api_version": 1,
    "success": true,
    "data": {
        "gif_decrypt_key": "a1b2c3d4e5f6...",
        "expires_at": 1747180800
    }
}
```

Store `gif_decrypt_key` in memory for the session. When it expires, call this endpoint again.

### Step 2: Search for GIFs

```
GET /app/gifs/search?q={query}&page={page}&per_page={per_page}
Authorization: Bearer <app_token>
```

Requires a valid temp decrypt key (from Step 1). Returns 403 if the key is missing or expired.

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `q` | Yes | - | Search query |
| `page` | No | `1` | Page number (1-indexed) |
| `per_page` | No | `20` | Results per page (max 50) |
| `content_filter` | No | `high` | Klipy content filter level |

**Response (200):**
```json
{
    "api_version": 1,
    "success": true,
    "data": {
        "results": [
            {
                "token": "server-encrypted-opaque-string...",
                "title": "Funny Cat Reaction",
                "encrypted_gif_url": "base64-encrypted-string...",
                "encrypted_preview_url": "base64-encrypted-string...",
                "preview_width": 220,
                "preview_height": 229
            }
        ],
        "has_next": true,
        "page": 1
    }
}
```

**Field details:**

| Field | Type | Description |
|-------|------|-------------|
| `token` | string | Server-encrypted trigger token (GIF ID + timestamp). **Opaque — do not parse.** Pass directly to the trigger endpoint. Expires 30 minutes after search. |
| `title` | string | GIF title from Klipy |
| `encrypted_gif_url` | string | Full-size GIF URL, encrypted with the temp decrypt key. Decrypt client-side to display. |
| `encrypted_preview_url` | string | Small preview GIF URL, encrypted with the temp decrypt key. Decrypt client-side for thumbnails. |
| `preview_width` | int | Width of the preview GIF in pixels |
| `preview_height` | int | Height of the preview GIF in pixels |

### Step 2b: Client-Side Decryption

To display GIFs, the client must decrypt `encrypted_gif_url` and `encrypted_preview_url` using the temp key from Step 1.

**Algorithm:** AES-256-CBC

**Decryption steps:**
1. Base64-decode the encrypted string to get raw bytes
2. First 16 bytes = IV (initialization vector)
3. Remaining bytes = ciphertext
4. Key = SHA-256 hash of `gif_decrypt_key` (raw bytes, not hex)
5. Decrypt with AES-256-CBC using the key and IV
6. Result is the plain GIF URL string

**Pseudocode:**
```
function decryptGifUrl(encryptedString, gifDecryptKey):
    raw = base64Decode(encryptedString)
    iv = raw[0:16]
    ciphertext = raw[16:]
    key = sha256(gifDecryptKey)          // raw 32 bytes, not hex string
    plaintext = aes256cbc_decrypt(ciphertext, key, iv)
    return plaintext                      // "https://static.klipy.com/..."
```

**iOS (Swift) example using CryptoKit + CommonCrypto:**
```swift
import CryptoKit
import CommonCrypto

func decryptGifUrl(_ encrypted: String, key gifDecryptKey: String) -> String? {
    guard let raw = Data(base64Encoded: encrypted), raw.count > 16 else { return nil }
    let iv = raw.prefix(16)
    let ciphertext = raw.dropFirst(16)
    let keyHash = SHA256.hash(data: Data(gifDecryptKey.utf8))
    let keyBytes = Array(keyHash)

    var decrypted = Data(count: ciphertext.count + kCCBlockSizeAES128)
    var decryptedLength = 0
    let status = keyBytes.withUnsafeBufferPointer { keyPtr in
        iv.withUnsafeBytes { ivPtr in
            ciphertext.withUnsafeBytes { dataPtr in
                decrypted.withUnsafeMutableBytes { outPtr in
                    CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, keyBytes.count,
                            ivPtr.baseAddress,
                            dataPtr.baseAddress, ciphertext.count,
                            outPtr.baseAddress, decrypted.count, &decryptedLength)
                }
            }
        }
    }
    guard status == kCCSuccess else { return nil }
    return String(data: decrypted.prefix(decryptedLength), encoding: .utf8)
}
```

**Android (Kotlin) example:**
```kotlin
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec
import java.security.MessageDigest

fun decryptGifUrl(encrypted: String, gifDecryptKey: String): String? {
    val raw = Base64.getDecoder().decode(encrypted)
    if (raw.size < 17) return null
    val iv = raw.sliceArray(0 until 16)
    val ciphertext = raw.sliceArray(16 until raw.size)
    val keyBytes = MessageDigest.getInstance("SHA-256").digest(gifDecryptKey.toByteArray())
    val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
    cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(keyBytes, "AES"), IvParameterSpec(iv))
    return String(cipher.doFinal(ciphertext))
}
```

### Step 3: Trigger a GIF

Use the same trigger endpoint as static images, but pass `gif_token` instead of `image_id`:

```
POST https://burkeblack.tv/bot/v2/triggerOverlayImage.php
Content-Type: application/x-www-form-urlencoded
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `key` | Yes | `UPLOAD_API_KEY` |
| `gif_token` | Yes | The `token` value from search results — pass as-is, do not modify |
| `mode` | Yes | `large`, `medium`, `small`, `bounce`, or `bounce-multi` |
| `duration` | No | Seconds to display (1-300, default: 10) |
| `username` | No | Viewer's Twitch username |
| `source` | No | `app_ios` or `app_android` |

**What happens server-side:**
1. Decrypts `gif_token` using `GIF_ENCRYPTION_KEY` to recover GIF ID + timestamp
2. Validates timestamp is within 30 minutes
3. Calls Klipy's item lookup API to get the full GIF URL and dimensions
4. Sends the GIF URL + dimensions to the socket server
5. Socket server broadcasts to the OBS overlay via WebSocket
6. Logs the trigger in `overlay_image_usage` table as `gif:{klipy_id}`

**Success response (200):**
```json
{
    "success": true,
    "message": "GIF overlay triggered",
    "gif_title": "Funny Cat Reaction",
    "mode": "bounce",
    "duration": 10
}
```

**Error responses:**

| Code | Condition |
|------|-----------|
| 400 | Invalid mode, invalid/malformed gif token, expired gif token (>30 min) |
| 403 | Invalid API key |
| 404 | GIF not found on Klipy, or GIF URL unavailable |
| 500 | `GIF_ENCRYPTION_KEY` or `KLIPY_API_KEY` not configured |
| 502 | Klipy API or socket server unreachable |

---

## Complete Client Flows

### Static image trigger
```
1. GET /app/overlay-images?filter=subs       → categories + images with thumbnails
2. User picks an image + display mode
3. POST /bot/v2/triggerOverlayImage.php       → image_id + mode + username + source
4. Image appears on stream overlay
```

### GIF trigger
```
1. POST /app/gifs/key                         → get temp decrypt key (once per session, lasts 6hr)
2. GET /app/gifs/search?q=reaction            → encrypted URLs + opaque tokens
3. Client decrypts preview URLs using temp key → display thumbnails
4. User picks a GIF + display mode
5. POST /bot/v2/triggerOverlayImage.php       → gif_token + mode + username + source
6. Server decrypts token, validates timestamp (30 min), fetches GIF from Klipy
7. GIF appears on stream overlay
```

---

## Usage Logging

Every trigger (image or GIF) is logged server-side in the `overlay_image_usage` table:

| Column | Description |
|--------|-------------|
| `image_ids` | Comma-separated image IDs, or `gif:{klipy_id}` for GIFs |
| `image_names` | Human-readable names |
| `username` | Who triggered it |
| `source` | Platform identifier (`app_ios`, `app_android`, etc.) |
| `mode` | Display mode used |
| `duration` | Seconds displayed |
| `triggered_at` | Timestamp |

Always pass `source` as `app_ios` or `app_android` so triggers can be tracked by platform.

---

## Security Model

| Layer | Mechanism | Purpose |
|-------|-----------|---------|
| App auth | Bearer token (30-day, rolling) | Identifies the user, gates all `/app` endpoints |
| Temp decrypt key | Per-session hex key (6hr expiry) | Lets client decrypt GIF URLs for display only |
| Trigger token | AES-256-CBC with server-only key | Contains GIF ID + timestamp, 30-min expiry, client cannot forge or read |
| Trigger auth | `UPLOAD_API_KEY` in POST body | Gates the trigger endpoint |
| Klipy API key | Server-side only, never exposed | Used by server to query/look up GIFs |

The client **never** has access to:
- The Klipy API key
- The `GIF_ENCRYPTION_KEY` (server-side token encryption)
- Raw Klipy GIF IDs
- The `UPLOAD_API_KEY` is stored in the app but not exposed to users

The client **does** have:
- Bearer token (from Twitch login)
- Temp decrypt key (from `/app/gifs/key`, 6hr expiry)
- Encrypted GIF URLs (decryptable with temp key for display)
- Opaque trigger tokens (passed through to trigger endpoint)
