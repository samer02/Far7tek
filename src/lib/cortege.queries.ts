import {queryOptions} from '@tanstack/react-query';
import {getCatalog,getAdminData} from './cortege.functions';
export const catalogQuery=queryOptions({queryKey:['catalog'],queryFn:()=>getCatalog(),staleTime:30000});
export const adminQuery=queryOptions({queryKey:['admin'],queryFn:()=>getAdminData()});
export function pageHead(title:string,description:string){return {meta:[{title:`${title} — Cortège & Cérémonie`},{name:'description',content:description},{property:'og:title',content:`${title} — Cortège & Cérémonie`},{property:'og:description',content:description},{property:'og:type',content:'website'},{name:'twitter:card',content:'summary_large_image'}]};}
