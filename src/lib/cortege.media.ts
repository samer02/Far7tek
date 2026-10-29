import ghost from '@/assets/rolls-royce-ghost.jpg';
import maybach from '@/assets/maybach-s680.jpg';
import jaguar from '@/assets/jaguar-mark-ii.jpg';
import hero from '@/assets/cortege-hero.jpg';
export {hero,ghost,maybach,jaguar};
export function fallbackCar(brand:string){return brand.includes('Jaguar')?jaguar:brand.includes('Mercedes')?maybach:ghost;}
export function storageUrl(bucket:string,path:string){return `${import.meta.env['VITE_SUPABASE_URL']}/storage/v1/object/authenticated/${bucket}/${path}`;}
