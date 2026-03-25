# Run Klair (non-technical steps)

## What you’re “installing”

There is **nothing to download from the App Store**. **Klair** is this iPhone app project inside the `Klair` folder. You open it in **Xcode** (Apple’s free app for developers) and press **Run**. Xcode then **installs Klair on the Simulator** (a fake iPhone on your Mac) or on your real iPhone if you plug it in.

You do **not** need to install Cursor or anything else to try Klair—only **Xcode**.

---

## What you need

1. A **Mac** (MacBook, iMac, etc.).
2. **Xcode** — install from the **Mac App Store** (search “Xcode”, install, open once so it finishes setup).  
   First launch can take a while.

---

## Steps (about 5 minutes after Xcode is ready)

1. **Open the project**  
   In Finder, go to your repo:  
   `cursor-hackathon` → **`Klair`**  
   Double‑click **`Klair.xcodeproj`**  
   (It should open in Xcode.)

2. **Pick a virtual iPhone**  
   At the top of Xcode, next to the **Play** ▶️ button, click the device name.  
   Choose something like **iPhone 16** or **iPhone 15** under **iOS Simulators**.

3. **Sign the app (first time only)**  
   Click **Klair** in the left sidebar (blue icon).  
   Open the **Signing & Capabilities** tab.  
   Under **Team**, choose your **Apple ID** (add account in Xcode → Settings → Accounts if needed).  
   Xcode may fix a “bundle identifier” warning by itself; if it asks, allow it.

4. **Run**  
   Press the **Play** ▶️ button (or **Product → Run**).  
   Wait for the build to finish. The **Simulator** opens and **Klair** launches with **sample data** (no Oura/OpenAI keys needed).

---

## If something fails

- **“No such module” / build errors** — In the menu: **Product → Clean Build Folder**, then Run again.  
- **Signing errors** — Make sure a **Team** is selected and you’re on the **Klair** target.  
- **Blank or old data** — In the Simulator menu: **Device → Erase All Content and Settings**, then Run again.

---

## Real iPhone (optional)

1. Plug in the iPhone with a cable, unlock it, tap **Trust** on the phone.  
2. Select your **iPhone** instead of the Simulator at the top of Xcode.  
3. On the iPhone: **Settings → Privacy & Security → Developer Mode** (turn on if iOS asks).  
4. Press **Run** again.

---

## When you want real Oura + OpenAI later

In `Klair/Config/DemoMode.swift`, set `useMockRemoteServices` to **`false`**, then add your keys as described in **`README.md`**.
