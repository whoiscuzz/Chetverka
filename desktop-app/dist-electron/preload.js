"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const electron_1 = require("electron");
electron_1.contextBridge.exposeInMainWorld("desktopApi", {
    bootstrap: () => electron_1.ipcRenderer.invoke("app:bootstrap"),
    login: (username, password) => electron_1.ipcRenderer.invoke("auth:login", username, password),
    fetchDiary: () => electron_1.ipcRenderer.invoke("diary:fetch"),
    fetchQuarterGrades: () => electron_1.ipcRenderer.invoke("diary:quarter"),
    logout: () => electron_1.ipcRenderer.invoke("auth:logout"),
    fetchNews: () => electron_1.ipcRenderer.invoke("news:fetch"),
});
