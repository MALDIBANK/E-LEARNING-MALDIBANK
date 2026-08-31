import { supabase } from "./supabase-client.js";

// Redirects to index.html if not signed in. Returns {session, profile}.
export async function requireAuth() {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) {
    window.location.href = "index.html";
    return null;
  }
  const { data: profile, error } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", session.user.id)
    .single();
  if (error) console.error(error);
  return { session, profile };
}

// Like requireAuth, but also redirects non-admins away.
export async function requireAdmin() {
  const result = await requireAuth();
  if (!result) return null;
  if (!result.profile || result.profile.role !== "admin") {
    window.location.href = "dashboard.html";
    return null;
  }
  return result;
}

export async function signOut() {
  await supabase.auth.signOut();
  window.location.href = "index.html";
}

export function wireSignOutButtons() {
  document.querySelectorAll("[data-sign-out]").forEach((el) => {
    el.addEventListener("click", (e) => {
      e.preventDefault();
      signOut();
    });
  });
}
