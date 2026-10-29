import { createServerFn } from '@tanstack/react-start';
import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';
import { requireSupabaseAuth } from '@/integrations/supabase/auth-middleware';
import type { Database } from '@/integrations/supabase/types';
import { bookingSchema, proposalSchema, bookingStatuses, proposalStatuses } from './cortege.schemas';
function publicClient() {
 const url=process.env['SUPABASE_URL']; const key=process.env['SUPABASE_PUBLISHABLE_KEY'];
 if(!url || !key) throw new Error('Service momentanément indisponible');
 return createClient<Database>(url,key,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(input,init)=>{const headers=new Headers(init?.headers); if(headers.get('Authorization')===`Bearer ${key}`) headers.delete('Authorization'); headers.set('apikey',key);return fetch(input,{...init,headers});}}});
}
export const getCatalog = createServerFn({method:'GET'}).handler(async()=>{
 const client=publicClient();
 const [{data:cars,error},{data:gallery}]=await Promise.all([client.from('cars').select('*,car_images(*),car_videos(*)').eq('active',true).order('sort_order'),client.from('gallery').select('*').eq('active',true).order('sort_order')]);
 if(error) throw new Error('La collection est momentanément indisponible');
 return {cars:cars??[],gallery:gallery??[]};
});
export const sendBooking=createServerFn({method:'POST'}).inputValidator((data)=>bookingSchema.parse(data)).handler(async({data})=>{
 const client=publicClient();
 if(data.car_id){const {data:car}=await client.from('cars').select('name').eq('id',data.car_id).eq('active',true).single();if(!car) throw new Error('Cette automobile n’est plus disponible');data.car_name=car.name;}
 const {error}=await client.from('booking_requests').insert(data);if(error) throw new Error('Votre demande n’a pas pu être envoyée. Veuillez réessayer.');return {success:true};
});
export const sendProposal=createServerFn({method:'POST'}).inputValidator((data)=>proposalSchema.parse(data)).handler(async({data})=>{
 const {photos,...proposal}=data; const client=publicClient();
 if(photos.some(path=>!path.startsWith(`${data.id}/`))) throw new Error('Photographies invalides');
 const {error}=await client.from('car_proposals').insert(proposal);if(error) throw new Error('La candidature n’a pas pu être envoyée');
 if(photos.length){const {error:imageError}=await client.from('proposal_images').insert(photos.map(storage_path=>({proposal_id:data.id,storage_path})));if(imageError) throw new Error('La candidature est enregistrée mais les photos nécessitent une nouvelle tentative');}
 return {success:true};
});
export const getAdminData=createServerFn({method:'GET'}).middleware([requireSupabaseAuth]).handler(async({context})=>{
 const {data:allowed}=await context.supabase.rpc('has_role',{_user_id:context.userId,_role:'admin'});if(!allowed) throw new Error('Votre compte n’a pas encore accès à la direction.');
 const [cars,bookings,proposals,gallery,notes,profile]=await Promise.all([context.supabase.from('cars').select('*,car_images(*),car_videos(*)').order('sort_order'),context.supabase.from('booking_requests').select('*').order('created_at',{ascending:false}),context.supabase.from('car_proposals').select('*,proposal_images(*)').order('created_at',{ascending:false}),context.supabase.from('gallery').select('*').order('sort_order'),context.supabase.from('admin_notes').select('*').order('created_at',{ascending:false}),context.supabase.from('profiles').select('*').eq('id',context.userId).maybeSingle()]);
 for(const result of [cars,bookings,proposals,gallery,notes]) if(result.error) throw new Error('Le registre n’a pas pu être chargé');
 return {cars:cars.data??[],bookings:bookings.data??[],proposals:proposals.data??[],gallery:gallery.data??[],notes:notes.data??[],profile:profile.data,userId:context.userId};
});
const adminActionSchema=z.discriminatedUnion('kind',[
 z.object({kind:z.literal('booking'),id:z.string().uuid(),status:z.enum(bookingStatuses)}),
 z.object({kind:z.literal('proposal'),id:z.string().uuid(),status:z.enum(proposalStatuses)}),
 z.object({kind:z.literal('note'),id:z.string().uuid(),entity:z.enum(['booking','proposal']),note:z.string().trim().min(1).max(4000)}),
 z.object({kind:z.literal('delete'),id:z.string().uuid(),table:z.enum(['cars','gallery','car_images','car_videos'])}),
 z.object({kind:z.literal('car'),id:z.string().uuid().optional(),name:z.string().min(1).max(200),brand:z.string().min(1),model:z.string().min(1),category:z.string().min(1),description:z.string().max(10000),short_description:z.string().max(1000),color:z.string(),year:z.number().nullable(),price_from:z.number().min(0),availability:z.string(),active:z.boolean(),featured:z.boolean(),features:z.record(z.unknown()),service_information:z.record(z.unknown())}),
 z.object({kind:z.literal('media'),car_id:z.string().uuid(),media_type:z.enum(['image','video']),storage_path:z.string().min(1),title:z.string()}),
 z.object({kind:z.literal('gallery'),id:z.string().uuid().optional(),title:z.string().min(1),description:z.string(),event_date:z.string().nullable(),service_type:z.string(),media_type:z.enum(['image','video']),storage_path:z.string().min(1),active:z.boolean()})
]);
export const adminAction=createServerFn({method:'POST'}).middleware([requireSupabaseAuth]).inputValidator((data)=>adminActionSchema.parse(data)).handler(async({data,context})=>{
 const {data:allowed}=await context.supabase.rpc('has_role',{_user_id:context.userId,_role:'admin'});if(!allowed) throw new Error('Accès refusé');
 let error;
 if(data.kind==='booking') ({error}=await context.supabase.from('booking_requests').update({status:data.status,updated_at:new Date().toISOString()}).eq('id',data.id));
 if(data.kind==='proposal') ({error}=await context.supabase.from('car_proposals').update({status:data.status,updated_at:new Date().toISOString()}).eq('id',data.id));
 if(data.kind==='note') ({error}=await context.supabase.from('admin_notes').insert({author_id:context.userId,note:data.note,booking_request_id:data.entity==='booking'?data.id:null,car_proposal_id:data.entity==='proposal'?data.id:null}));
 if(data.kind==='delete') ({error}=await context.supabase.from(data.table).delete().eq('id',data.id));
 if(data.kind==='car'){const {kind,id,...values}=data;const row={...values,features:values.features as Database['public']['Tables']['cars']['Insert']['features'],service_information:values.service_information as Database['public']['Tables']['cars']['Insert']['service_information'],updated_at:new Date().toISOString()}; if(id) ({error}=await context.supabase.from('cars').update(row).eq('id',id));else ({error}=await context.supabase.from('cars').insert({...row,slug:`${values.brand}-${values.model}-${crypto.randomUUID().slice(0,8)}`.toLowerCase().replace(/\s+/g,'-')}));}
 if(data.kind==='media'){if(data.media_type==='image') ({error}=await context.supabase.from('car_images').insert({car_id:data.car_id,storage_path:data.storage_path,alt_text:data.title}));else ({error}=await context.supabase.from('car_videos').insert({car_id:data.car_id,storage_path:data.storage_path,title:data.title}));}
 if(data.kind==='gallery'){const {kind,id,...values}=data;if(id) ({error}=await context.supabase.from('gallery').update(values).eq('id',id));else ({error}=await context.supabase.from('gallery').insert(values));}
 if(error) throw new Error('La modification n’a pas pu être enregistrée');return {success:true};
});
export type Catalog=Awaited<ReturnType<typeof getCatalog>>;
export type Car=Catalog['cars'][number];
