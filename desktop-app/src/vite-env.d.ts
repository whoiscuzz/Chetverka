/// <reference types="vite/client" />

import { DiaryResponse, LoginResponse, NewsItem, Profile, QuarterGradesTable, Week } from "./types";

type BootstrapPayload = {
  isAuthenticated: boolean;
  profile?: Profile;
  weeks: Week[];
};

interface DesktopApi {
  bootstrap(): Promise<BootstrapPayload>;
  login(username: string, password: string): Promise<LoginResponse>;
  fetchDiary(): Promise<DiaryResponse>;
  fetchQuarterGrades(): Promise<QuarterGradesTable>;
  logout(): Promise<void>;
  fetchNews(): Promise<NewsItem[]>;
}

declare global {
  interface Window {
    desktopApi: DesktopApi;
  }
}

export {};
