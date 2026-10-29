import { supabase } from "@/integrations/supabase/client";
import { fallbackCarImage } from "@/lib/platform";

export type CarView = {
  id: string; name: string; slug: string; brand: string; model: string; year: number | null; color: string | null;
  category: string; short_description: string; description: string; price_from: number | null; availability: string;
  seats: number | null; city: string | null; services: string[]; images: string[];
};

export async function signedUrls(bucket: string, paths: string[]) {
  if (!paths.length) return {} as Record<string, string>;
  const { data } = await supabase.storage.from(bucket).createSignedUrls(paths, 3600);
  const out: Record<string, string> = {};
  for (const d of data ?? []) if (d.path && d.signedUrl) out[d.path] = d.signedUrl;
  return out;
}

export async function fetchCars(filter?: { slug?: string; ownerId?: string }): Promise<CarView[]> {
  let q = supabase.from("cars").select("*, car_images(storage_path,is_cover,sort_order)").order("sort_order");
  if (filter?.slug) q = q.eq("slug", filter.slug);
  if (filter?.ownerId) q = q.eq("owner_id", filter.ownerId);
  else q = q.eq("active", true);
  const { data, error } = await q;
  if (error) throw error;
  const allPaths = (data ?? []).flatMap((c: any) => c.car_images.map((i: any) => i.storage_path));
  const urls = await signedUrls("car-images", allPaths);
  return (data ?? []).map((c: any) => {
    const imgs = [...c.car_images]
      .sort((a: any, b: any) => Number(b.is_cover) - Number(a.is_cover) || a.sort_order - b.sort_order)
      .map((i: any) => urls[i.storage_path])
      .filter(Boolean);
    return { ...c, images: imgs.length ? imgs : [fallbackCarImage(c.slug)] };
  });
}
