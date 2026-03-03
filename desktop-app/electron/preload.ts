import { contextBridge, ipcRenderer } from "electron";

contextBridge.exposeInMainWorld("desktopApi", {
  bootstrap: () => ipcRenderer.invoke("app:bootstrap"),
  login: (username: string, password: string) => ipcRenderer.invoke("auth:login", username, password),
  fetchDiary: () => ipcRenderer.invoke("diary:fetch"),
  fetchQuarterGrades: () => ipcRenderer.invoke("diary:quarter"),
  logout: () => ipcRenderer.invoke("auth:logout"),
  fetchNews: () => ipcRenderer.invoke("news:fetch"),
});
