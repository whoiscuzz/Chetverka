import { FormEvent, useEffect, useMemo, useState } from "react";
import {
  AppTab,
  LoginResponse,
  NewsItem,
  Profile,
  QuarterGradesTable,
  SubjectResult,
  Week,
} from "./types";

type AuthState = {
  isAuthenticated: boolean;
  profile?: Profile;
  weeks: Week[];
};

const greetings = [
  "Снова за учебу?",
  "Готов(а) к новым знаниям?",
  "Смотрим дневник одним глазком.",
  "Какие оценки получим сегодня?",
];

const tabs: Array<{ id: AppTab; label: string; icon: string }> = [
  { id: "dashboard", label: "Главная", icon: "⌂" },
  { id: "diary", label: "Дневник", icon: "▤" },
  { id: "analytics", label: "Аналитика", icon: "◔" },
  { id: "results", label: "Итоги", icon: "◎" },
  { id: "profile", label: "Профиль", icon: "◉" },
];

export default function App() {
  const [booting, setBooting] = useState(true);
  const [authLoading, setAuthLoading] = useState(false);
  const [diaryLoading, setDiaryLoading] = useState(false);
  const [authError, setAuthError] = useState<string | null>(null);
  const [diaryError, setDiaryError] = useState<string | null>(null);
  const [auth, setAuth] = useState<AuthState>({ isAuthenticated: false, weeks: [] });
  const [tab, setTab] = useState<AppTab>("dashboard");
  const [tabTick, setTabTick] = useState(0);
  const [news, setNews] = useState<NewsItem[]>([]);
  const [newsError, setNewsError] = useState<string | null>(null);
  const [newsLoading, setNewsLoading] = useState(false);
  const [quarterTable, setQuarterTable] = useState<QuarterGradesTable | null>(null);
  const [quarterError, setQuarterError] = useState<string | null>(null);
  const [quarterLoading, setQuarterLoading] = useState(false);
  const welcome = useMemo(() => greetings[Math.floor(Math.random() * greetings.length)], []);

  useEffect(() => {
    void (async () => {
      const state = await window.desktopApi.bootstrap();
      setAuth({ isAuthenticated: state.isAuthenticated, profile: state.profile, weeks: state.weeks ?? [] });
      setBooting(false);
      if (state.isAuthenticated) {
        void loadNews();
      }
    })();
  }, []);

  async function loadNews() {
    setNewsLoading(true);
    setNewsError(null);
    try {
      const data = await window.desktopApi.fetchNews();
      setNews(data);
    } catch (error) {
      setNewsError(getError(error));
    } finally {
      setNewsLoading(false);
    }
  }

  async function doLogin(username: string, password: string) {
    setAuthLoading(true);
    setAuthError(null);
    try {
      const data: LoginResponse = await window.desktopApi.login(username, password);
      const diary = await window.desktopApi.fetchDiary();
      setAuth({ isAuthenticated: true, profile: data.profile, weeks: diary.weeks });
      void loadNews();
    } catch (error) {
      setAuthError(getError(error));
    } finally {
      setAuthLoading(false);
    }
  }

  async function refreshDiary() {
    setDiaryLoading(true);
    setDiaryError(null);
    try {
      const diary = await window.desktopApi.fetchDiary();
      setAuth((prev) => ({ ...prev, weeks: diary.weeks }));
    } catch (error) {
      setDiaryError(getError(error));
    } finally {
      setDiaryLoading(false);
    }
  }

  async function loadQuarterGrades(force: boolean) {
    if (!force && quarterTable) return;
    setQuarterLoading(true);
    setQuarterError(null);
    try {
      const table = await window.desktopApi.fetchQuarterGrades();
      setQuarterTable(table);
      if (!table.rows.length) {
        setQuarterError("Таблица четвертей не найдена.");
      }
    } catch (error) {
      setQuarterError(getError(error));
    } finally {
      setQuarterLoading(false);
    }
  }

  async function logout() {
    await window.desktopApi.logout();
    setAuth({ isAuthenticated: false, weeks: [] });
    setTab("dashboard");
    setNews([]);
    setQuarterTable(null);
  }

  function onTabSelect(next: AppTab) {
    if (next === tab) return;
    setTab(next);
    setTabTick((v) => v + 1);
  }

  if (booting) return <div className="boot">Загрузка...</div>;

  if (!auth.isAuthenticated) {
    return <LoginScreen loading={authLoading} error={authError} onLogin={doLogin} />;
  }

  return (
    <div className="app-shell">
      <header className="app-header">
        <h1>{tabs.find((x) => x.id === tab)?.label}</h1>
        <button className="ghost-btn" onClick={refreshDiary} disabled={diaryLoading}>
          {diaryLoading ? "Обновление..." : "Обновить"}
        </button>
      </header>

      <main key={`${tab}-${tabTick}`} className="app-page page-enter">
        {tab === "dashboard" && (
          <DashboardScreen
            weeks={auth.weeks}
            welcome={welcome}
            news={news}
            newsLoading={newsLoading}
            newsError={newsError}
            onReloadNews={loadNews}
          />
        )}
        {tab === "diary" && <DiaryScreen weeks={auth.weeks} />}
        {tab === "analytics" && <AnalyticsScreen weeks={auth.weeks} />}
        {tab === "results" && (
          <ResultsScreen
            weeks={auth.weeks}
            quarterTable={quarterTable}
            quarterError={quarterError}
            quarterLoading={quarterLoading}
            onLoadQuarterGrades={loadQuarterGrades}
          />
        )}
        {tab === "profile" && <ProfileScreen profile={auth.profile} onLogout={logout} />}
        {diaryError && <p className="inline-error">{diaryError}</p>}
      </main>

      <nav className="tabbar">
        {tabs.map((item) => (
          <button
            key={item.id}
            className={item.id === tab ? "tabbar-item active" : "tabbar-item"}
            onClick={() => onTabSelect(item.id)}
          >
            <span className="tabbar-icon">{item.icon}</span>
            <span>{item.label}</span>
          </button>
        ))}
      </nav>
    </div>
  );
}

function LoginScreen({
  loading,
  error,
  onLogin,
}: {
  loading: boolean;
  error: string | null;
  onLogin: (username: string, password: string) => Promise<void>;
}) {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");

  async function submit(event: FormEvent) {
    event.preventDefault();
    await onLogin(username.trim(), password);
  }

  return (
    <div className="login-page">
      <div className="login-orb" />
      <form className="login-card" onSubmit={submit}>
        <h2>Вход в schools.by</h2>
        <p>Chetverka Desktop</p>
        <input value={username} onChange={(e) => setUsername(e.target.value)} placeholder="Логин" />
        <input value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Пароль" type="password" />
        {error && <div className="inline-error">{error}</div>}
        <button type="submit" disabled={loading} className="primary-btn">
          {loading ? "Входим..." : "Войти"}
        </button>
      </form>
    </div>
  );
}

function DashboardScreen({
  weeks,
  welcome,
  news,
  newsLoading,
  newsError,
  onReloadNews,
}: {
  weeks: Week[];
  welcome: string;
  news: NewsItem[];
  newsLoading: boolean;
  newsError: string | null;
  onReloadNews: () => Promise<void>;
}) {
  const today = new Date();
  const todayIso = toIso(today);
  const allLessons = weeks.flatMap((w) => w.days.flatMap((d) => d.lessons.map((lesson) => ({ lesson, date: d.date }))));
  const todayLessons = weeks.flatMap((w) => w.days).find((d) => d.date === todayIso)?.lessons ?? [];
  const marks = allLessons.map((x) => markInt(x.lesson.mark)).filter((x): x is number => x !== null);
  const avg = marks.length ? marks.reduce((a, b) => a + b, 0) / marks.length : 0;
  const recent = allLessons.filter((x) => x.lesson.mark?.trim()).slice(-4).reverse();
  const weak = weakSubjects(weeks);
  const latestNews = news[0];

  return (
    <section className="screen-stack">
      <div className="hero-card reveal-delay-1">
        <small>{welcome}</small>
        <h2>{formatDate(today)}</h2>
      </div>

      <div className="stats-grid reveal-delay-2">
        <StatCard title="Уроков" value={String(todayLessons.length)} />
        <StatCard title="ДЗ" value={String(todayLessons.filter((x) => x.hw?.trim()).length)} />
        <StatCard title="Средний" value={avg ? avg.toFixed(2) : "—"} />
      </div>

      <section className="soft-card reveal-delay-3">
        <div className="section-head">
          <h3>Новости</h3>
          <button className="ghost-btn" onClick={() => void onReloadNews()}>
            Обновить
          </button>
        </div>
        {newsLoading && <p className="muted">Загрузка новостей...</p>}
        {newsError && <p className="inline-error">{newsError}</p>}
        {!newsLoading && !newsError && !latestNews && <p className="muted">Пока новостей нет.</p>}
        {latestNews && (
          <article className="news-card">
            <h4>{latestNews.title}</h4>
            <p>{latestNews.body.slice(0, 220)}...</p>
            <small>{formatNewsDate(latestNews.created_at)}</small>
          </article>
        )}
      </section>

      <section className="soft-card reveal-delay-4">
        <h3>Последние оценки</h3>
        {!recent.length && <p className="muted">Оценок пока нет.</p>}
        {recent.map((item, idx) => (
          <div className="row-line" key={`${item.lesson.subject}-${idx}`}>
            <span>{capitalize(item.lesson.subject)}</span>
            <strong className="mark-pill">{item.lesson.mark}</strong>
          </div>
        ))}
      </section>

      <section className="soft-card reveal-delay-5">
        <h3>Требуют внимания</h3>
        {!weak.length && <p className="muted">Все предметы в норме.</p>}
        {weak.map((item) => (
          <div className="row-line" key={item[0]}>
            <span>{item[0]}</span>
            <strong>{item[1].toFixed(2)}</strong>
          </div>
        ))}
      </section>
    </section>
  );
}

function DiaryScreen({ weeks }: { weeks: Week[] }) {
  const [selected, setSelected] = useState(currentWeekIndex(weeks));
  const [weekTick, setWeekTick] = useState(0);
  useEffect(() => {
    setSelected(currentWeekIndex(weeks));
  }, [weeks]);
  if (!weeks.length) return <div className="soft-card">Данных нет</div>;
  const week = weeks[Math.min(selected, weeks.length - 1)];

  function go(delta: number) {
    setSelected((prev) => {
      const next = Math.max(0, Math.min(weeks.length - 1, prev + delta));
      if (next !== prev) setWeekTick((v) => v + 1);
      return next;
    });
  }

  return (
    <section className="screen-stack">
      <div className="week-head soft-card">
        <button className="ghost-btn" disabled={selected <= 0} onClick={() => go(-1)}>
          ‹
        </button>
        <strong>{weekRangeLabel(week.monday)}</strong>
        <button className="ghost-btn" disabled={selected >= weeks.length - 1} onClick={() => go(1)}>
          ›
        </button>
      </div>

      <div key={`${selected}-${weekTick}`} className="week-page week-enter">
        {week.days.map((day) => (
          <div className="soft-card day-card" key={day.date}>
            <h3>
              {day.name} • {day.date}
            </h3>
            {!day.lessons.length && <p className="muted">Уроков нет</p>}
            {day.lessons.map((lesson, idx) => (
              <article className="lesson-row" key={`${lesson.subject}-${idx}`}>
                <div>
                  <strong>{lesson.subject}</strong>
                  {lesson.hw && <p>ДЗ: {lesson.hw}</p>}
                </div>
                {lesson.mark && <span className="mark-pill">{lesson.mark}</span>}
              </article>
            ))}
          </div>
        ))}
      </div>
    </section>
  );
}

function AnalyticsScreen({ weeks }: { weeks: Week[] }) {
  const results = subjectResults(weeks);
  const avg = results.length ? results.reduce((a, b) => a + b.average, 0) / results.length : 0;
  if (!results.length) return <div className="soft-card">Нет оценок для аналитики.</div>;
  const ringValue = Math.max(0, Math.min(100, Math.round((avg / 10) * 100)));
  return (
    <section className="screen-stack">
      <div className="soft-card ring-card">
        <h3>Средний балл</h3>
        <div className="ring-outer" style={{ ["--ring" as string]: `${ringValue}%` }}>
          <div className="ring-inner">{avg.toFixed(2)}</div>
        </div>
      </div>
      {results.map((item) => (
        <div className="soft-card" key={item.subject}>
          <div className="row-line">
            <strong>{item.subject}</strong>
            <span>{item.average.toFixed(2)}</span>
          </div>
          <div className="grade-track">
            <div className="grade-fill" style={{ width: `${Math.max(6, (item.average / 10) * 100)}%` }} />
          </div>
        </div>
      ))}
    </section>
  );
}

function ResultsScreen({
  weeks,
  quarterTable,
  quarterError,
  quarterLoading,
  onLoadQuarterGrades,
}: {
  weeks: Week[];
  quarterTable: QuarterGradesTable | null;
  quarterError: string | null;
  quarterLoading: boolean;
  onLoadQuarterGrades: (force: boolean) => Promise<void>;
}) {
  const [mode, setMode] = useState<"current" | "all">("current");
  const results = subjectResults(weeks);

  useEffect(() => {
    if (mode === "all") {
      void onLoadQuarterGrades(false);
    }
  }, [mode, onLoadQuarterGrades]);

  return (
    <section className="screen-stack">
      <div className="segment">
        <button className={mode === "current" ? "segment-btn active" : "segment-btn"} onClick={() => setMode("current")}>
          Текущая
        </button>
        <button className={mode === "all" ? "segment-btn active" : "segment-btn"} onClick={() => setMode("all")}>
          Все четверти
        </button>
      </div>

      {mode === "current" &&
        results.map((item) => (
          <div className="soft-card" key={item.subject}>
            <div className="row-line">
              <strong>{item.subject}</strong>
              <span>{item.average.toFixed(2)}</span>
            </div>
            <div className="chips">
              {item.marks.map((mark, idx) => (
                <span className={`grade-chip g-${gradeClass(mark)}`} key={idx}>
                  {mark}
                </span>
              ))}
            </div>
          </div>
        ))}

      {mode === "all" && (
        <div className="soft-card">
          <div className="section-head">
            <h3>Оценки по четвертям</h3>
            <button className="ghost-btn" onClick={() => void onLoadQuarterGrades(true)}>
              Обновить
            </button>
          </div>
          {quarterLoading && <p className="muted">Загрузка...</p>}
          {quarterError && <p className="inline-error">{quarterError}</p>}
          {!quarterLoading &&
            quarterTable?.rows?.map((row) => (
              <div className="row-quarter" key={row.subject}>
                <strong>{row.subject}</strong>
                <div className="chips">
                  {quarterTable.columns.map((col, idx) => (
                    <span key={`${row.subject}-${col}`} className="quarter-chip">
                      {shortQuarter(col)}: {row.grades[idx] ?? "—"}
                    </span>
                  ))}
                </div>
              </div>
            ))}
        </div>
      )}
    </section>
  );
}

function ProfileScreen({ profile, onLogout }: { profile?: Profile; onLogout: () => Promise<void> }) {
  return (
    <section className="screen-stack">
      <div className="soft-card profile-card">
        <div className="avatar">{(profile?.fullName ?? "П")[0]}</div>
        <h3>{profile?.fullName ?? "Пользователь"}</h3>
        <p>{profile?.className ?? "Класс не указан"}</p>
        <p className="muted">Классный руководитель: {profile?.classTeacher ?? "Не указан"}</p>
      </div>
      <button className="danger-btn" onClick={() => void onLogout()}>
        Выйти
      </button>
    </section>
  );
}

function StatCard({ title, value }: { title: string; value: string }) {
  return (
    <div className="stat-card">
      <h3>{value}</h3>
      <p>{title}</p>
    </div>
  );
}

function markInt(mark?: string): number | null {
  if (!mark) return null;
  const m = mark.trim().replace(",", ".");
  if (!m) return null;
  if (m.includes("/")) {
    const [a, b] = m.split("/");
    const left = Number(a);
    const right = Number(b);
    if (!Number.isNaN(left) && !Number.isNaN(right)) return Math.round((left + right) / 2);
  }
  const direct = Number(m);
  if (!Number.isNaN(direct)) return Math.round(direct);
  const numbers = m.match(/\d+(\.\d+)?/g)?.map(Number).filter((x) => !Number.isNaN(x)) ?? [];
  if (!numbers.length) return null;
  return Math.round(Math.max(...numbers));
}

function subjectResults(weeks: Week[]): SubjectResult[] {
  const map = new Map<string, number[]>();
  for (const week of weeks) {
    for (const day of week.days) {
      for (const lesson of day.lessons) {
        const score = markInt(lesson.mark);
        if (score === null) continue;
        const key = lesson.subject.trim().toLowerCase();
        const current = map.get(key) ?? [];
        current.push(score);
        map.set(key, current);
      }
    }
  }
  return [...map.entries()]
    .map(([subject, marks]) => ({
      subject: capitalize(subject),
      average: marks.reduce((a, b) => a + b, 0) / marks.length,
      marks,
    }))
    .sort((a, b) => b.average - a.average);
}

function weakSubjects(weeks: Week[]): Array<[string, number]> {
  return subjectResults(weeks)
    .map((x) => [x.subject, x.average] as [string, number])
    .filter((x) => x[1] < 6.5)
    .sort((a, b) => a[1] - b[1])
    .slice(0, 2);
}

function currentWeekIndex(weeks: Week[]): number {
  if (!weeks.length) return 0;
  const today = toIso(new Date());
  const found = weeks.findIndex((w) => w.days.some((d) => d.date === today));
  if (found >= 0) return found;
  return Math.max(0, weeks.length - 1);
}

function weekRangeLabel(monday: string): string {
  const start = new Date(monday);
  if (Number.isNaN(start.getTime())) return monday;
  const end = new Date(start);
  end.setDate(start.getDate() + 6);
  const day = new Intl.DateTimeFormat("ru-RU", { day: "numeric" }).format(start);
  const endLabel = new Intl.DateTimeFormat("ru-RU", { day: "numeric", month: "long" }).format(end);
  return `${day} - ${endLabel}`;
}

function shortQuarter(value: string): string {
  const lower = value.toLowerCase().replace(/\s+/g, "");
  if (lower === "i") return "I";
  if (lower === "ii" || lower === "ii/i") return "II";
  if (lower === "iii") return "III";
  if (lower === "iv" || lower === "iv/ii") return "IV";
  if (lower.includes("сред")) return "Ср.";
  if (lower.includes("год") || lower.includes("итог")) return "Год";
  return value.length <= 4 ? value : value.slice(0, 4);
}

function gradeClass(mark: number): "good" | "warn" | "bad" {
  if (mark >= 9) return "good";
  if (mark >= 7) return "warn";
  return "bad";
}

function formatDate(date: Date): string {
  return new Intl.DateTimeFormat("ru-RU", { day: "numeric", month: "long", weekday: "long" }).format(date);
}

function formatNewsDate(raw: string): string {
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) return raw;
  return new Intl.DateTimeFormat("ru-RU", { day: "numeric", month: "long" }).format(date);
}

function toIso(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

function capitalize(value: string): string {
  if (!value) return value;
  return value[0].toUpperCase() + value.slice(1);
}

function getError(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}
