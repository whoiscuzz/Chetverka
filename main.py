from curl_cffi import requests
from bs4 import BeautifulSoup
import time
from collections import defaultdict
from datetime import datetime, timedelta
import re

BASE = "https://4minsk.schools.by"
START_WEEK = "2026-01-12"

def parse_date(date_str: str) -> datetime:
    return datetime.strptime(date_str, "%Y-%m-%d")

def get_monday(date: datetime) -> datetime:
    return date - timedelta(days=date.weekday())

def clean_subject(text: str) -> str:
    if not text:
        return ""
    text = " ".join(text.split())
    text = re.sub(r"^\d+[\.\)]\s*", "", text)
    return text

def fetch_week(session, pupil_id: str, week_date: str):
    url = f"{BASE}/m/pupil/{pupil_id}/dnevnik/quarter/90/week/{week_date}"
    try:
        r = session.get(url, timeout=10)
        r.raise_for_status() 
    except (requests.errors.RequestsError, requests.errors.HTTPError) as e:
        print(f"Error fetching week {week_date}: {e}")
        return None, None

    soup = BeautifulSoup(r.text, "html.parser")
    week_block = soup.select_one("div.db_days:not([style])")
    if not week_block:
        # Если блок не найден, это может быть нормально для недели без уроков.
        print(f"Warning: No 'div.db_days' found for week {week_date}. It might be an empty week.")
        
        # Дополнительно проверим, есть ли кнопка "next", чтобы не прерывать цикл зря
        next_btn = soup.select_one("a.next")
        next_week = next_btn.get("next_week_id") if next_btn else None
        return None, next_week

    next_btn = soup.select_one("a.next")
    next_week = next_btn.get("next_week_id") if next_btn else None
    return week_block, next_week

def parse_week(week_block, week_start: datetime):
    rows = []
    days = week_block.select("div.db_day")
    for day_index, day in enumerate(days):
        table = day.select_one("table.db_table")
        if not table:
            continue
        day_name_th = table.select_one("th.lesson")
        day_name = day_name_th.get_text(strip=True) if day_name_th else "?"
        day_date = week_start + timedelta(days=day_index)
        for tr in table.select("tbody tr"):
            lesson_td = tr.select_one("td.lesson span")
            lesson_raw = lesson_td.get_text(" ", strip=True) if lesson_td else ""
            subject = clean_subject(lesson_raw)
            hw_td = tr.select_one("div.ht-text")
            hw = hw_td.get_text(" ", strip=True) if hw_td else None
            mark_td = tr.select_one("td.mark strong")
            mark = mark_td.get_text(strip=True) if mark_td else None
            if not subject and not hw and not mark:
                continue
            rows.append({
                "date": day_date,
                "day_name": day_name,
                "subject": subject,
                "mark": mark,
                "hw": hw
            })
    return rows

def parse_quarter(session, pupil_id: str):
    visited = set()
    week = START_WEEK
    all_rows = []
    while week and week not in visited:
        visited.add(week)
        week_start = parse_date(week)
        block, next_week = fetch_week(session, pupil_id, week)
        if not block:
            break
        all_rows.extend(parse_week(block, week_start))
        week = next_week
        time.sleep(0.5) # Немного уменьшим задержку
    return all_rows

def structure_for_ios(rows):
    # Группируем уроки по дате (YYYY-MM-DD) и по неделям
    weeks_map = defaultdict(lambda: defaultdict(lambda: {'name': '?', 'lessons': []}))
    for r in rows:
        monday = get_monday(r["date"])
        week_id = monday.strftime("%Y-%m-%d")
        day_id = r["date"].strftime("%Y-%m-%d")

        weeks_map[week_id][day_id]['name'] = r["day_name"]
        weeks_map[week_id][day_id]['lessons'].append({
            "subject": r["subject"],
            "mark": r["mark"],
            "hw": r["hw"]
        })

    weeks_list = []
    for week_id in sorted(weeks_map.keys()):
        days_list = []
        day_map = weeks_map[week_id]
        for day_id in sorted(day_map.keys()):
            day_data = day_map[day_id]
            days_list.append({
                "date": day_id, # Добавляем дату
                "name": day_data['name'],
                "lessons": day_data['lessons']
            })
        weeks_list.append({
            "monday": week_id,
            "days": days_list
        })
    return weeks_list

def get_quarter(sessionid: str, pupil_id: str):
    session = requests.Session(
        headers={"User-Agent": "Mozilla/5.0"},
        cookies={"sessionid": sessionid},
        impersonate="chrome110"
    )
    raw_rows = parse_quarter(session, pupil_id)
    return structure_for_ios(raw_rows)

def login(username, password):
    with requests.Session(
        headers={"User-Agent": "Mozilla/5.0"},
        impersonate="chrome110"
    ) as s:
        # 1. Получаем страницу входа и CSRF токен
        login_url = "https://schools.by/login"
        try:
            r_get = s.get(login_url, timeout=10)
            r_get.raise_for_status()
            soup = BeautifulSoup(r_get.text, "html.parser")
            csrf_token_tag = soup.find("input", {"name": "csrfmiddlewaretoken"})
            if not csrf_token_tag:
                print("Error: CSRF token not found")
                return None
            csrf_token = csrf_token_tag["value"]
        except (requests.errors.RequestsError, KeyError) as e:
            print(f"Error getting CSRF token: {e}")
            return None

        # 2. Отправляем данные для входа
        login_data = {
            "csrfmiddlewaretoken": csrf_token,
            "username": username,
            "password": password,
            "|123": "|123",
        }
        headers = {"Referer": login_url}

        try:
            r_post = s.post(login_url, data=login_data, headers=headers, timeout=10)
            r_post.raise_for_status()
        except requests.errors.RequestsError as e:
            print(f"Error during login POST: {e}")
            return None

        # 3. Проверяем, успешный ли вход и ищем Pupil ID
        if 'sessionid' not in s.cookies:
            print("Login failed: sessionid not in cookies")
            return None
            
        post_soup = BeautifulSoup(r_post.text, 'html.parser')
        if post_soup.find(text=re.compile("Пожалуйста, введите правильные имя пользователя и пароль")):
            print("Login failed: Invalid credentials message found")
            return None

        # 4. Ищем Pupil ID и парсим профиль
        try:
            # Сначала убеждаемся, что мы на мобильной версии главной страницы
            main_page_url = f"{BASE}/m/"
            main_page = s.get(main_page_url, timeout=10)
            main_page.raise_for_status()
            main_soup = BeautifulSoup(main_page.text, 'html.parser')
            
            user_link = main_soup.find("a", class_="u_name")
            if not user_link or not user_link.has_attr('href'):
                print("Error: 'a.u_name' link not found.")
                return None

            id_match = re.search(r"/pupil/(\d+)", user_link['href'])
            if not id_match:
                print("Error: Could not extract pupil_id from href.")
                return None
                
            pupil_id = id_match.group(1)
            session_id = s.cookies.get("sessionid")
            
            # 5. Теперь идем на страницу профиля за детальной информацией
            profile_page_url = f"{BASE}/pupil/{pupil_id}/" # Убираем /m/
            profile_page = s.get(profile_page_url, timeout=10)
            profile_page.raise_for_status()
            profile_soup = BeautifulSoup(profile_page.text, 'html.parser')

            profile_data = {}

            # Имя и класс
            title_box = profile_soup.find("div", class_="title_box")
            if title_box and title_box.h1:
                full_title = title_box.h1.get_text(strip=True)
                # "Ерошенко Ефим, 10 "Б" класс, ID 1106490"
                name_part = full_title.split(',')[0].strip()
                class_part_match = re.search(r",\s*(.*?)\s*класс", full_title)
                profile_data["fullName"] = name_part
                if class_part_match:
                    profile_data["className"] = class_part_match.group(1)

            # Аватар
            avatar_box = profile_soup.find("div", class_="profile-photo__box")
            if avatar_box and avatar_box.img and avatar_box.img.has_attr('src'):
                profile_data["avatarUrl"] = avatar_box.img['src']

            # Классный руководитель
            pp_lines = profile_soup.find_all("div", class_="pp_line_new")
            for line in pp_lines:
                if "Классный руководитель:" in line.get_text():
                    teacher_name = line.get_text().replace("Классный руководитель:", "").strip()
                    profile_data["classTeacher"] = teacher_name
            
            print(f"Login successful! Scraped profile data: {profile_data}")
            
            return {
                "sessionid": session_id,
                "pupilid": pupil_id,
                "profile": profile_data
            }
            
        except (requests.errors.RequestsError, KeyError, AttributeError) as e:
            print(f"Error fetching profile data after login: {e}")
            return None