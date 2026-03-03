export type AppTab = "dashboard" | "diary" | "analytics" | "results" | "profile";

export type LessonAttachment = {
  name: string;
  url?: string;
  type?: string;
};

export type Lesson = {
  subject: string;
  mark?: string;
  hw?: string;
  cabinet?: string;
  attachments?: LessonAttachment[];
};

export type Day = {
  date: string;
  name: string;
  lessons: Lesson[];
};

export type Week = {
  monday: string;
  days: Day[];
};

export type DiaryResponse = {
  weeks: Week[];
};

export type Profile = {
  fullName: string;
  className?: string;
  avatarUrl?: string;
  classTeacher?: string;
  role?: string;
};

export type LoginResponse = {
  sessionId: string;
  pupilId: string;
  profile: Profile;
};

export type SubjectResult = {
  subject: string;
  average: number;
  marks: number[];
};

export type QuarterGradesRow = {
  subject: string;
  grades: Array<string | null>;
};

export type QuarterGradesTable = {
  columns: string[];
  rows: QuarterGradesRow[];
};

export type NewsItem = {
  id: number;
  title: string;
  body: string;
  created_at: string;
  is_published?: boolean;
  author_name?: string;
  image_url?: string;
};
