"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const node_path_1 = __importDefault(require("node:path"));
const electron_1 = require("electron");
const newsService_1 = require("./newsService");
const schoolsByClient_1 = require("./schoolsByClient");
const store_1 = require("./store");
let mainWindow = null;
const schoolsClient = new schoolsByClient_1.SchoolsByClient();
function createWindow() {
    mainWindow = new electron_1.BrowserWindow({
        width: 1360,
        height: 900,
        minWidth: 1080,
        minHeight: 760,
        show: false,
        webPreferences: {
            preload: node_path_1.default.join(__dirname, "preload.js"),
            contextIsolation: true,
            nodeIntegration: false,
        },
    });
    const devUrl = process.env.VITE_DEV_SERVER_URL;
    if (devUrl) {
        void mainWindow.loadURL(devUrl);
    }
    else {
        void mainWindow.loadFile(node_path_1.default.join(__dirname, "../dist-renderer/index.html"));
    }
    mainWindow.once("ready-to-show", () => mainWindow?.show());
    mainWindow.on("closed", () => {
        mainWindow = null;
    });
}
electron_1.app.whenReady().then(() => {
    electron_1.ipcMain.handle("app:bootstrap", async () => {
        const session = await (0, store_1.readSessionStore)();
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
        }
        catch {
            return {
                isAuthenticated: true,
                profile: session.profile,
                weeks: [],
            };
        }
    });
    electron_1.ipcMain.handle("auth:login", async (_event, username, password) => {
        if (!username?.trim() || !password?.trim()) {
            throw new Error("Заполни логин и пароль.");
        }
        const data = await schoolsClient.login(username.trim(), password);
        await (0, store_1.writeSessionStore)({
            sessionId: data.sessionId,
            pupilId: data.pupilId,
            profile: data.profile,
        });
        return data;
    });
    electron_1.ipcMain.handle("diary:fetch", async () => {
        const session = await (0, store_1.readSessionStore)();
        if (!session.sessionId || !session.pupilId) {
            throw new Error("Нет активной сессии.");
        }
        return schoolsClient.fetchDiary(session.pupilId, session.sessionId);
    });
    electron_1.ipcMain.handle("diary:quarter", async () => {
        const session = await (0, store_1.readSessionStore)();
        if (!session.sessionId || !session.pupilId) {
            throw new Error("Нет активной сессии.");
        }
        return schoolsClient.fetchQuarterGrades(session.pupilId, session.sessionId);
    });
    electron_1.ipcMain.handle("auth:logout", async () => {
        await schoolsClient.clearSession();
        await (0, store_1.writeSessionStore)({});
    });
    electron_1.ipcMain.handle("news:fetch", async () => {
        return (0, newsService_1.fetchNews)();
    });
    createWindow();
});
electron_1.app.on("window-all-closed", () => {
    if (process.platform !== "darwin")
        electron_1.app.quit();
});
electron_1.app.on("activate", () => {
    if (electron_1.BrowserWindow.getAllWindows().length === 0)
        createWindow();
});
