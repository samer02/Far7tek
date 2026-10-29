import { supabase } from "@/integrations/supabase/client";
import { fallbackCarImage } from "@/lib/platform";

const SUPABASE_URL = "https://jvvgxtqwjrznkirjrisw.supabase.co";

export type CarView = {
  id: string; name: string; slug: string; brand: string; model: string; year: number | null; color: string | null;
  category: string; short_description: string; description: string; price_from: number | null; availability: string;
  seats: number | null; city: string | null; services: string[]; images: string[];
};

/** Resolve public URL for an image stored in either `car-images` or `proposal-images` bucket. */
export function resolveCarImageUrl(storagePath: string): string {
  if (!storagePath) return "";
  if (storagePath.startsWith("http://") || storagePath.startsWith("https://")) return storagePath;
  if (storagePath.startsWith("car-images/")) {
    return `${SUPABASE_URL}/storage/v1/object/public/${storagePath}`;
  }
  if (storagePath.startsWith("proposal-images/")) {
    return `${SUPABASE_URL}/storage/v1/object/public/${storagePath}`;
  }
  // Proposal uploads have path format: "<proposal_id>/<filename>" (2 parts)
  // Standard car uploads have path format: "<owner_id>/<car_id>/<filename>" (3 parts)
  const parts = storagePath.split("/");
  const bucket = parts.length <= 2 ? "proposal-images" : "car-images";
  return `${SUPABASE_URL}/storage/v1/object/public/${bucket}/${storagePath}`;
}

export async function signedUrls(bucket: string, paths: string[]) {
  if (!paths.length) return {} as Record<string, string>;
  const { data } = await supabase.storage.from(bucket).createSignedUrls(paths, 3600);
  const out: Record<string, string> = {};
  for (const d of data ?? []) if (d.path && d.signedUrl) out[d.path] = d.signedUrl;
  return out;
}

export async function fetchCars(filter?: { slug?: string; ownerId?: string }): Promise<CarView[]> {
  let q = supabase
    .from("cars")
    .select(`
      *,
      car_images(storage_path, is_cover, sort_order)
    `)
    .order("sort_order");

  if (filter?.slug) q = q.eq("slug", filter.slug);
  if (filter?.ownerId) q = q.eq("owner_id", filter.ownerId);
  else q = q.eq("active", true);

  const { data, error } = await q;
  if (error) throw error;

  return (data ?? []).map((c: any) => {
    // Read images from car_images
    const fromCarImages: string[] = [...(c.car_images ?? [])]
      .sort((a: any, b: any) => Number(b.is_cover) - Number(a.is_cover) || a.sort_order - b.sort_order)
      .map((i: any) => resolveCarImageUrl(i.storage_path))
      .filter(Boolean);

    if (fromCarImages.length) {
      return { ...c, images: fromCarImages };
    }

    // Fallback: bundled static image by slug
    return { ...c, images: [fallbackCarImage(c.slug)] };
  });
}
