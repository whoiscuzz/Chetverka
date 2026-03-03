import { NewsItem } from "./types";

const fallbackBaseURL = "https://cfxymbnlgfbpgxsysrah.supabase.co";
const fallbackApiKey =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNmeHltYm5sZ2ZicGd4c3lzcmFoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA3NTMxOTQsImV4cCI6MjA4NjMyOTE5NH0.T8pk05YEcFbpgh5sR2gMKW8ek0qWKL84rekvOgxwbFo";

export async function fetchNews(): Promise<NewsItem[]> {
  const url = new URL(`${fallbackBaseURL}/rest/v1/news`);
  url.searchParams.set("select", "id,title,body,created_at,is_published,author_name,image_url");
  url.searchParams.set("is_published", "eq.true");
  url.searchParams.set("order", "created_at.desc");

  const response = await fetch(url.toString(), {
    headers: {
      Accept: "application/json",
      apikey: fallbackApiKey,
      Authorization: `Bearer ${fallbackApiKey}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Новости недоступны (${response.status})`);
  }

  return (await response.json()) as NewsItem[];
}
