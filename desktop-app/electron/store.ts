import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { app } from "electron";
import { Profile } from "./types";

export type SessionStore = {
  sessionId?: string;
  pupilId?: string;
  profile?: Profile;
};

function storePath() {
  return path.join(app.getPath("userData"), "session.json");
}

export async function readSessionStore(): Promise<SessionStore> {
  try {
    const raw = await readFile(storePath(), "utf8");
    const parsed = JSON.parse(raw) as SessionStore;
    return parsed ?? {};
  } catch {
    return {};
  }
}

export async function writeSessionStore(store: SessionStore): Promise<void> {
  const file = storePath();
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, JSON.stringify(store, null, 2), "utf8");
}
