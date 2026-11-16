// Project-specific web destinations; never infer the origin from request input.
export function previewOrigin(projectUrl: string): string {
  if (projectUrl === "https://czswojzpekcsisudgfsg.supabase.co") return "http://localhost:3001";
  if (projectUrl === "https://kdrccmqcrruixuworlmz.supabase.co") return "https://b2bconecta-app-git-dev-b2bconecta.vercel.app";
  return "https://app.b2bconecta.com.ve";
}
