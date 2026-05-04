# Rokid VideoCall iOS


> **🔵 Connectivity Update — May 2025**
> The glasses connection has been migrated from **raw TCP sockets** to
> **Bluetooth via the Rokid AI glasses SDK** (`pod 'RokidSDK' ~> 1.10.2`).
> No Wi-Fi port forwarding is needed. See **SDK Setup** below.

iOS companion app for WebRTC video calling with Rokid AR glasses.

Converted from the Android original. Replaces the native WebRTC SDK + OkHttp WebSocket with WKWebView JavaScript WebRTC + URLSessionWebSocketTask.

## What it does

- **WebRTC video call**: Full bidirectional audio/video via the browser's built-in WebRTC engine running inside WKWebView — no third-party SDK needed.
- **WebSocket signaling**: Connects to a signaling server (ws://) to exchange SDP offers/answers and ICE candidates.
- **Camera controls**: Front/back camera toggle mid-call; mute/unmute.
- **Incoming calls**: Incoming SDP offer shown as an overlay with accept/decline.
- **Glasses HUD**: TCP server on port 8087 broadcasts call state (idle / connecting / inCall / incoming / ended) as JSON to connected Rokid glasses.
- **STUN / TURN**: Configurable ICE servers for NAT traversal.

## Android → iOS mapping

| Android | iOS |
|---------|-----|
| `org.webrtc` native SDK | WKWebView + JavaScript WebRTC (`RTCPeerConnection`) |
| `SignalingClient` (OkHttp WS) | `SignalingClient` (URLSessionWebSocketTask) |
| `WebRTCManager` | `WebRTCCoordinator` (Swift↔JS bridge via WKScriptMessageHandler) |
| `RokidManager` (CxrApi) | `GlassesServer` (NWListener TCP :8087) |
| `Config.kt` | `SettingsStore` (UserDefaults) |

## Architecture

```
ContentView
  └─ CallView
       ├─ WebRTCView (WKWebView hosting webrtc.html)
       │    └─ JavaScript RTCPeerConnection
       └─ Controls overlay

CallViewModel
  ├─ WebRTCCoordinator  (Swift ↔ JS bridge)
  ├─ SignalingClient    (URLSessionWebSocketTask)
  └─ GlassesServer     (NWListener TCP :8087)
```

## Signaling protocol

The app expects a WebSocket server at the configured URL. Messages are JSON:

```json
// Outgoing
{"type":"call_start","data":{"sdp":"...","type":"offer","device_id":"..."}}
{"type":"call_answer","data":{"sdp":"...","type":"answer"}}
{"type":"ice_candidate","data":{"candidate":"...","sdpMid":"0","sdpMLineIndex":0}}
{"type":"call_end","data":{"reason":"user_hangup"}}
{"type":"camera_switched","data":{"camera":"front"}}

// Incoming
{"type":"call_answer","data":{"sdp":"...","type":"answer"}}
{"type":"ice_candidate","data":{...}}
{"type":"call_start","data":{"sdp":"...","type":"offer","operator_id":"user123"}}
{"type":"call_end","data":{}}
```

## Glasses protocol (TCP :8087)

```json
{"type":"callState","state":"inCall","remote":"user123"}
{"type":"callState","state":"ended"}
{"type":"status","text":"Signaling connected"}
```

## Setup

1. Deploy a signaling server (see the Android repo's `server/` directory for a Node.js reference).
2. Open `RokidVideoCall.xcodeproj` in Xcode 15+.
3. Set your team in Signing & Capabilities.
4. Build and run on an iPhone (iOS 17+).
5. Open Settings, enter your signaling server WebSocket URL.
6. The app auto-connects to the signaling server on launch.

## Requirements

- iOS 17.0+
- Xcode 15+
- A WebRTC signaling server (WebSocket)
- No third-party Swift dependencies
