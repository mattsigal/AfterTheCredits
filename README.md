# After The Credits

A personalized Android mobile application for searching, scheduling upcoming theatre visits, and viewing post-credits/mid-credits stinger data alongside Letterboxd activity.

---

## Data Sources & Attribution

- **[AfterCredits.com](https://aftercredits.com/)**: Primary source for movie stinger information, mid-credit / after-credit scene breakdowns, spoiler details, and stinger community ratings.
- **[Letterboxd](https://letterboxd.com/)**: Primary source for user recently watched film activity, member ratings, and watch history pulled via user RSS feeds (`https://letterboxd.com/{username}/rss/`).

---

## Features

- **Minimalist Search**: Full-width search bar to query any film on `aftercredits.com` with title normalization and fuzzy matching.
- **Upcoming Theatre Calendar**: Add movies you plan to see in theatres with a date picker and track them on your home screen.
- **Stinger Visual Badges & Borders**:
  - **Red Border**: Indicates the film has mid-credits or post-credits stinger content.
  - **Green Border**: Indicates no stinger content.
  - Overlay badges: **MID** and **AFTER** credit scene indicators.
- **Recently Watched Integration**: Displays your recent Letterboxd activity with automatic stinger status resolution and 100% interactive poster navigation.
- **Detailed Stinger Breakdown**:
  - Collapsible credit spoiler cards (`+ Click to see credit details`).
  - Rating, Directed by, Written by, Starring, Release Date, Running Time, Official Site, Letterboxd search link, IMDb link, and Synopsis.
- **Offline Caching**: Built-in SQLite database (`sqflite`) for fast offline access and local caching.
- **Appearance & Focus Controls**:
  - Dark Mode (default) and Light Mode toggle.
  - Non-intrusive search field focus behavior (keyboard opens only on explicit tap).

---

## Tech Stack & Architecture

- **Framework**: Flutter (Android Mobile, Portrait Orientation)
- **State Management**: Provider
- **Local Storage**: SQLite (`sqflite`) + `shared_preferences`
- **Networking & Scraping**: `http`, `html`, `xml`
- **Typography**: Google Fonts (Inter & Outfit)

---

## Building & Installation

To build and run the release APK on a connected Android device:

```bash
flutter pub get
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
