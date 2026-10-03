# NewsInsights — Setup Guide

This guide sets up and runs NewsInsights on a fresh machine (Windows, macOS or Linux).
It is written so that **Claude Code (or any AI coding agent) can follow it end to end**, and a person can follow it too.

> **For the agent:** do the steps in order and run each **Verify** check before moving on.
> When a step says **ASK THE USER**, stop and ask; never invent keys or passwords.
> Never commit `.env` files, and never print API keys back into the chat or terminal output.

---

## 0. What you are setting up

| Part | Tech | Port | Folder |
|---|---|---|---|
| Database | MongoDB 7 | 27017 | (installed separately) |
| Backend API | Python 3.11 + FastAPI | 8000 | `python-backend/` |
| App | Flutter (web in Chrome; Android optional) | 8080 when served | `client/` |

External services (free accounts, the user must provide the keys):

| Key | Used for | Get it at |
|---|---|---|
| `NEWSAPI_KEY` | News feed, search, recommendations, fake-news coverage check | https://newsapi.org/register |
| `GROQ_API_KEY` | AI summaries, personalised picks, fake news detection | https://console.groq.com/keys |

All keys live **only** in `python-backend/.env`. The app never holds API keys; it only talks to the backend.

---

## 1. Install prerequisites

Install what is missing. Check first: `git --version`, `python --version`, `flutter --version`.

### 1.1 Git
- Windows: `winget install --id Git.Git -e` (or https://git-scm.com/download/win)
- macOS: `xcode-select --install`
- Linux: `sudo apt install git`

### 1.2 Python 3.11 (exactly 3.11; 3.13/3.14 will fail)
The pinned packages (pydantic 1.x, scikit-learn 1.3.2, numpy < 2) have no wheels for Python 3.13+.
The easiest way is **uv**, which downloads Python 3.11 for you without touching the system Python:

- Windows (PowerShell): `powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"`
- macOS/Linux: `curl -LsSf https://astral.sh/uv/install.sh | sh`

Then open a new terminal and check: `uv --version`

(Alternative without uv: install Python 3.11 from https://www.python.org/downloads/ and use `py -3.11` / `python3.11` in step 3.)

### 1.3 Flutter SDK (stable channel)
Tested with **Flutter 3.47.6 / Dart 3.13** (any recent stable should work).

- Windows:
  ```powershell
  git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter
  # Add C:\src\flutter\bin to the user PATH, then open a new terminal
  [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\src\flutter\bin", "User")
  ```
- macOS: `brew install --cask flutter`
- Linux: `sudo snap install flutter --classic`

Then run `flutter --version` (the first run downloads the Dart SDK and takes a few minutes) and `flutter config --no-analytics`.

### 1.4 Google Chrome
Needed to run the web app. Check it's installed; `flutter devices` should list **Chrome**.

### 1.5 MongoDB (pick ONE option)

**Option A: Docker (simplest if Docker Desktop already works)**
```bash
docker run -d --name newsinsights-mongo -p 27017:27017 -v newsinsights-mongo:/data/db --restart unless-stopped mongo:7
```
Mongo URI: `mongodb://127.0.0.1:27017`

**Option B: Local install**
- Windows: `winget install MongoDB.Server` (installs as a service that starts automatically)
- macOS: `brew tap mongodb/brew && brew install mongodb-community@7.0 && brew services start mongodb-community@7.0`
- Linux: follow https://www.mongodb.com/docs/manual/administration/install-on-linux/

Mongo URI: `mongodb://127.0.0.1:27017`

**Option C: Portable, no admin rights (Windows)**: what the original machine uses
```powershell
mkdir C:\src -Force; cd C:\src
curl.exe -L -o mongodb.zip https://fastdl.mongodb.org/windows/mongodb-windows-x86_64-7.0.14.zip
tar -xf mongodb.zip; Rename-Item mongodb-win32-x86_64-windows-7.0.14 mongodb; Remove-Item mongodb.zip
mkdir C:\src\mongodb-data -Force
# Start it (keep this terminal open, or run it in the background):
C:\src\mongodb\bin\mongod.exe --dbpath C:\src\mongodb-data --bind_ip 127.0.0.1
```
Mongo URI: `mongodb://127.0.0.1:27017`

**Option D: MongoDB Atlas (cloud, free tier)**: ASK THE USER for their connection string
(`mongodb+srv://USER:PASSWORD@cluster.xxxxx.mongodb.net`), and make sure their current IP is allowed in Atlas → Network Access.

**Verify:** port 27017 is listening (Options A–C):
- Windows: `Test-NetConnection 127.0.0.1 -Port 27017` → `TcpTestSucceeded : True`
- macOS/Linux: `nc -z 127.0.0.1 27017 && echo ok`

---

## 2. Get the code

```bash
git clone https://github.com/T1TANN/NewsInsightsAppFinal.git
cd NewsInsightsAppFinal
git checkout feature/ai-news-insights   # the AI features live here until merged into main
```

**Verify:** `python-backend/app/services/verify_service.py` and `client/lib/services/api_client.dart` exist.
If they don't, you are on the wrong branch.

---

## 3. Backend setup (`python-backend/`)

### 3.1 Create the virtual environment and install packages
```bash
cd python-backend
uv venv --python 3.11 venv
# Windows:
uv pip install --python venv\Scripts\python.exe -r requirements.txt
# macOS/Linux:
uv pip install --python venv/bin/python -r requirements.txt
```
(Without uv: `py -3.11 -m venv venv` then `venv\Scripts\python -m pip install -r requirements.txt`.)

### 3.2 Download the NLTK stopwords (required, or the backend crashes on start)
```bash
# Windows:
venv\Scripts\python -m nltk.downloader stopwords
# macOS/Linux:
venv/bin/python -m nltk.downloader stopwords
```

### 3.3 Create `python-backend/.env`
Copy the template: `cp .env.example .env` (Windows: `Copy-Item .env.example .env`).

**ASK THE USER** for their `NEWSAPI_KEY` and `GROQ_API_KEY` (links in section 0).
Generate the JWT secret yourself:
```bash
venv/Scripts/python -c "import secrets; print(secrets.token_hex(32))"   # Windows path shown; use venv/bin/python on macOS/Linux
```

Final `python-backend/.env` (no quotes, no spaces around `=`):
```env
MONGO_URI=mongodb://127.0.0.1:27017
NEWSAPI_KEY=<user's NewsAPI key>
JWT_SECRET=<the 64-character hex string you generated>
GROQ_API_KEY=<user's Groq key, starts with gsk_>
GROQ_MODEL=openai/gpt-oss-120b
GROQ_FALLBACK_MODEL=qwen/qwen3.8-27b
```

**Verify the keys before going further:**
```bash
# NewsAPI: expect "status": "ok"
curl "https://newsapi.org/v2/everything?q=india&pageSize=1&apiKey=<NEWSAPI_KEY>"
# Groq: expect a JSON list of models; check that GROQ_MODEL is in it
curl https://api.groq.com/openai/v1/models -H "Authorization: Bearer <GROQ_API_KEY>"
```
If `openai/gpt-oss-120b` is not listed (Groq retires models over time), set `GROQ_MODEL` to another large chat model from that list.

### 3.4 Start the backend
Run from inside `python-backend/` and keep this terminal open:
```bash
# Windows:
venv\Scripts\python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
# macOS/Linux:
venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```
Expect `Uvicorn running on http://0.0.0.0:8000` and `MongoDB connected successfully.`

**Verify (in another terminal):**
```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8000/docs        # 200
curl -s "http://127.0.0.1:8000/news" | head -c 300                            # {"status":true,"articles":[...
curl -s -X POST http://127.0.0.1:8000/registration -H "Content-Type: application/json" \
  -d '{"email":"setup-check@example.com","password":"secret123","username":"setupcheck","phone":"9000000001"}'
# {"status":true,...}  (or "Email already registered" if run twice; both mean MongoDB works)
```
On Windows PowerShell use `curl.exe` instead of `curl`, and put the JSON in a file for `-d @file.json` if quoting is a problem.

---

## 4. App setup (`client/`)

### 4.1 Install packages
```bash
cd client
flutter pub get
```
Use `flutter pub get`, **not** `flutter pub upgrade`: `pubspec.lock` pins versions that compile
(e.g. `velocity_x 4.3.1`; 4.3.0 fails on new Flutter).
A warning "Building with plugins requires symlink support / enable Developer Mode" only matters for
Windows *desktop* builds. It's safe to ignore for web.

### 4.2 Create `client/.env`
```bash
cp .env.example .env      # Windows: Copy-Item .env.example .env
```
It contains a single line. Keep the trailing slash:
```env
API_BASE_URL=http://localhost:8000/
```

### 4.3 Run the app in Chrome
```bash
flutter run -d chrome --dart-define-from-file=.env
```
The `--dart-define-from-file=.env` flag is required; it's how the app learns the backend URL.

**Alternative (stable URL, no hot reload):** build once and serve the files:
```bash
flutter build web --dart-define-from-file=.env
# Windows:
..\python-backend\venv\Scripts\python -m http.server 8080 --directory build/web
# macOS/Linux:
../python-backend/venv/bin/python -m http.server 8080 --directory build/web
```
Then open http://localhost:8080

**Verify:** `flutter analyze` reports no errors, `flutter test` passes (3 tests), and the app opens on the **Welcome back** sign-in screen.

### 4.4 (Optional) Android phone or emulator
Needs Android Studio + Android SDK (`flutter doctor` must show the Android toolchain ✓).
- **Emulator:** set `API_BASE_URL=http://10.0.2.2:8000/` in `client/.env`
- **Real phone (same Wi-Fi):** set `API_BASE_URL=http://<PC's LAN IP>:8000/` (find it with `ipconfig` / `ifconfig`) and allow port 8000 through the PC firewall.
- Run: `flutter run --dart-define-from-file=.env`

Camera scanning (OCR) works **only** on Android/iOS. On web, the Scan tab offers a paste-text box instead.

---

## 5. Smoke test (do this before saying setup is done)

In the app:
1. **Create one** → register (username ≥ 3 chars, valid email, phone, password ≥ 6) → you return to sign-in with the email filled in → **Sign in**.
2. **Home** shows a news feed with images; tap a topic chip (e.g. *Business*): the feed changes.
3. Tap the **heart** on 3 different stories.
4. Open a story → **Summarize with AI** → summary + key points appear in a few seconds.
5. Same story → **Check if this is real** → a verdict (e.g. *Likely real*), score, signals and claims appear.
6. **For You** tab → interest chips + stories, each with "Because you liked …".
7. **Discover** → search `electric vehicles` → results.
8. **Scan** tab → paste the hoax text below → **Summarize & check** → **Check if this is real** → *Likely fake*.
   > BREAKING!!! Government CONFIRMS that drinking hot water with lemon every morning CURES cancer in 3 days. Doctors are SHOCKED and big pharma is trying to hide this. Share this with everyone before it gets deleted!!!
9. **Profile** → shows the 3 likes → **Log out** → back to sign-in; reloading the page stays signed out.

API-only equivalents (useful for agents):
```bash
curl -s -X POST http://127.0.0.1:8000/summarize -H "Content-Type: application/json" -d '{"text":"<paste 30+ words of news text>"}'
curl -s -X POST http://127.0.0.1:8000/verify    -H "Content-Type: application/json" -d '{"text":"<paste a news claim>"}'
curl -s -X POST http://127.0.0.1:8000/recommend -H "Content-Type: application/json" -d '{"liked_articles":[{"title":"ISRO launches new satellite","category":"science"}]}'
```

---

## 6. Everyday start (after setup)

Three terminals, in this order:
```bash
# 1. MongoDB: only needed for the portable option; Docker/service installs start automatically
C:\src\mongodb\bin\mongod.exe --dbpath C:\src\mongodb-data --bind_ip 127.0.0.1

# 2. Backend
cd python-backend
venv\Scripts\python -m uvicorn app.main:app --host 0.0.0.0 --port 8000        # macOS/Linux: venv/bin/python ...

# 3. App
cd client
flutter run -d chrome --dart-define-from-file=.env
```

---

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `pip install` fails building pydantic / scikit-learn / numpy | Wrong Python version | Recreate the venv with **Python 3.11** (step 3.1) |
| Backend crash: `RuntimeError: JWT_SECRET is not set` | Missing `.env` or wrong folder | Create `python-backend/.env` (3.3) and start uvicorn from inside `python-backend/` |
| Backend crash: `Resource stopwords not found` | NLTK data missing | Run step 3.2 |
| `ModuleNotFoundError: No module named 'app'` | Started from the wrong folder | `cd python-backend` first |
| App shows **"Can't reach the server"** | Backend not running, or wrong `API_BASE_URL` | Start the backend; check `client/.env`; restart `flutter run` (values are baked in at build time) |
| Register/login returns **Internal server error**, backend log shows timeouts | MongoDB not running / wrong `MONGO_URI` | Start MongoDB (1.5); check the URI; for Atlas, allow your IP |
| Home feed: "Couldn't load the news" with a NewsAPI message | Bad key, or free-plan limit (~100 requests/day) | Check `NEWSAPI_KEY`; results are cached 10 min, so wait and retry |
| Summaries / fake-news check: "AI … is unavailable" | Bad Groq key, retired model, or rate limit | Check the key; list models (3.3) and update `GROQ_MODEL` |
| Summary says "based on the preview only" | The news site blocked article download | Expected for some sites; the summary still works from the preview |
| `flutter` not found | PATH not updated | Open a new terminal; re-check step 1.3 |
| Flutter compile error inside `velocity_x` | Packages were upgraded past the lock file | `git checkout client/pubspec.lock && flutter pub get` |
| Port 8000 or 8080 already in use | Old process still running | Windows: `Get-NetTCPConnection -LocalPort 8000 \| % { Stop-Process -Id $_.OwningProcess }` · macOS/Linux: `lsof -ti:8000 \| xargs kill` |
| Docker Desktop: "WSL update required" on an old Windows Insider build | Built-in WSL too old | Use MongoDB Option B or C instead |
| Python `UnicodeEncodeError` in backend logs on Windows | Old console encoding | Already handled in `app/main.py`; if it appears, set `PYTHONUTF8=1` before starting |

---

## 8. Project map

```
python-backend/
  app/main.py                     FastAPI app, routers, CORS
  app/routes/user_router.py       /registration /login /likeArticle /unlikeArticle /getUserDetails /getLikedArticles
  app/routes/recommend_router.py  /recommend
  app/routes/news_router.py       /news /summarize /verify
  app/services/llm_service.py     Groq client (primary + fallback model)
  app/services/news_service.py    NewsAPI proxy with cache
  app/services/article_extractor.py  Full-text extraction (JSON-LD / paragraphs)
  app/services/summarize_service.py  AI summary with key points
  app/services/verify_service.py     Fake news detection (claims + coverage + verdict)
  app/services/recommend_service.py  LLM interests + TF-IDF ranking
  .env.example                    Template for secrets
client/
  lib/main.dart                   App entry, session restore
  lib/services/api_client.dart    All backend calls
  lib/providers/likedArticleProvider.dart  Session + likes
  lib/screens/                    Home, For You, Scan, Discover, Profile, Article, Login, Register
  lib/widgets/                    Theme tokens, article cards, summary & credibility panels
  .env.example                    API_BASE_URL template
```

API docs (interactive) are at http://127.0.0.1:8000/docs while the backend runs.
