import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

export type AuthInfo = {
  userId: string | null;
  email: string | null;
  roles: string[];
};

export function useAuth() {
  return useQuery<AuthInfo>({
    queryKey: ["auth"],
    queryFn: async () => {
      const { data } = await supabase.auth.getUser();
      const user = data.user;
      if (!user) return { userId: null, email: null, roles: [] };
      const { data: roles } = await supabase.from("user_roles").select("role").eq("user_id", user.id);
      return { userId: user.id, email: user.email ?? null, roles: (roles ?? []).map((r) => r.role) };
    },
    staleTime: 60_000,
  });
}
