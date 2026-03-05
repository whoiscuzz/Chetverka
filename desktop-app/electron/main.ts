import path from "node:path";
import { app, BrowserWindow, ipcMain } from "electron";
import { fetchNews } from "./newsService";
import { SchoolsByClient } from "./schoolsByClient";
import { readSessionStore, writeSessionStore } from "./store";

let mainWindow: BrowserWindow | null = null;
const schoolsClient = new SchoolsByClient();

//im ok
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1360,
    height: 900,
    minWidth: 1080,
    minHeight: 760,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  const devUrl = process.env.VITE_DEV_SERVER_URL;
  if (devUrl) {
    void mainWindow.loadURL(devUrl);
  } else {
    void mainWindow.loadFile(path.join(__dirname, "../dist-renderer/index.html"));
  }

  mainWindow.once("ready-to-show", () => mainWindow?.show());
  mainWindow.on("closed", () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  ipcMain.handle("app:bootstrap", async () => {
    const session = await readSessionStore();
    if (!session.sessionId || !session.pupilId) {
      return { isAuthenticated: false, weeks: [] };
    }
    try {
      const diary = await schoolsClient.fetchDiary(session.pupilId, session.sessionId);
      return {
        isAuthenticated: true,
        profile: session.profile,
        weeks: diary.weeks,
      };
    } catch {
      return {
        isAuthenticated: true,
        profile: session.profile,
        weeks: [],
      };
    }
  });

  ipcMain.handle("auth:login", async (_event, username: string, password: string) => {
    if (!username?.trim() || !password?.trim()) {
      throw new Error("Заполни логин и пароль.");
    }
    const data = await schoolsClient.login(username.trim(), password);
    await writeSessionStore({
      sessionId: data.sessionId,
      pupilId: data.pupilId,
      profile: data.profile,
    });
    return data;
  });

  ipcMain.handle("diary:fetch", async () => {
    const session = await readSessionStore();
    if (!session.sessionId || !session.pupilId) {
      throw new Error("Нет активной сессии.");
    }
    return schoolsClient.fetchDiary(session.pupilId, session.sessionId);
  });

  ipcMain.handle("diary:quarter", async () => {
    const session = await readSessionStore();
    if (!session.sessionId || !session.pupilId) {
      throw new Error("Нет активной сессии.");
    }
    return schoolsClient.fetchQuarterGrades(session.pupilId, session.sessionId);
  });

  ipcMain.handle("auth:logout", async () => {
    await schoolsClient.clearSession();
    await writeSessionStore({});
  });

  ipcMain.handle("news:fetch", async () => {
    return fetchNews();
  });

  createWindow();
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

app.on("activate", () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});
