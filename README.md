# Niko Automsg

An advanced auto-messaging utility that manages and broadcasts up to four independent messages across your chat channels. Perfect for Trade, LFG, and guild recruitment on Warmane — with anti-spam pacing built in.

---

## 🚀 Features

* **Multi-Slot System:** Manage up to 4 independent message profiles (Tabs) at once. Each slot has its own text, interval, and targeted channels.
* **Dynamic Channel Detection:** Automatically detects which global channels you're connected to (Channels 1-6), alongside Say and Yell.
* **Master Switch & Per-Slot Toggles:** Turn individual messages on/off instantly, and control the whole broadcast engine with a single "Master Start/Stop" button.
* **Anti-Spam Engine:** Messages are queued and sent with a small delay, each broadcast interval is randomized by ±10% to avoid a robotic pattern, and a **30-second minimum interval** protects you from server mutes.
* **Unsaved-changes indicator:** The "Save Text" button shows a `*` when you have unsaved edits, so you never lose text by switching tabs.
* **Character counter:** A live `0/255` counter under the message box shows how close you are to the limit.
* **Smart Item Linking:** Shift-Click items, spells, and achievements directly into your message box.
* **Helpful warnings:** Warns you if you try to start with nothing enabled, or if a selected channel isn't connected.
* **Toggleable minimap button:** Show or hide the minimap icon from inside the window.
* **Lightweight:** The engine only runs while broadcasting — no background work when idle.

---

## 🛠 Installation

1. Download the latest version of the addon.
2. Extract the folder into your World of Warcraft directory:
   `World of Warcraft/Interface/AddOns/`
3. Ensure the folder name is exactly **NikoAutoMSG** (remove any `-master` or version suffixes).
4. Restart the game or type `/reload` in-game.

---

## 🎮 How to Use

* `/nikoautomsg` - Toggle the main window.
* **Minimap Icon:** Left-Click to toggle the window, Right-Click and drag to move it. Untick **Show Minimap Button** in the window to hide it.
* **Tabs (Msg 1 - 4):** Switch between your 4 message profiles.
* **"Save Text" Button:** **IMPORTANT!** Click this to save the text, interval, or channel changes in the current tab. A `*` on the button means you have unsaved changes.
* **"Enable" Tickbox:** Instantly turn the current message profile ON or OFF (no save needed).
* **Master Start/Stop:** The main engine switch. When running, every enabled slot broadcasts on its saved interval (±10% jitter).

---

## 🌐 Community & Support

Join our Discord for other addons, updates, bug reports, and suggestions:

**[Join Discord Server](https://discord.gg/e4FWTS4V9c)**

---

## 📌 Technical Specifications
* **Addon Version:** 1.1.1
* **Game Version:** World of Warcraft: Wrath of the Lich King (3.3.5a)
* **Tested On:** Warmane (Onyxia Realm)
* **Author:** Nikowsky (Kokotiar / Jebly)

<!-- SCREENSHOT: drag an image here in the GitHub web editor; it auto-uploads to a github.com/user-attachments URL. Then replace this comment with the generated ![NikoAutoMSG](...) block. -->
