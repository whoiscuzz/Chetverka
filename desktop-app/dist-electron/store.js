"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.readSessionStore = readSessionStore;
exports.writeSessionStore = writeSessionStore;
const promises_1 = require("node:fs/promises");
const node_path_1 = __importDefault(require("node:path"));
const electron_1 = require("electron");
function storePath() {
    return node_path_1.default.join(electron_1.app.getPath("userData"), "session.json");
}
async function readSessionStore() {
    try {
        const raw = await (0, promises_1.readFile)(storePath(), "utf8");
        const parsed = JSON.parse(raw);
        return parsed ?? {};
    }
    catch {
        return {};
    }
}
async function writeSessionStore(store) {
    const file = storePath();
    await (0, promises_1.mkdir)(node_path_1.default.dirname(file), { recursive: true });
    await (0, promises_1.writeFile)(file, JSON.stringify(store, null, 2), "utf8");
}
