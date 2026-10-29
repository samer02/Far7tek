import { z } from 'zod';
const text = z.string().trim().min(1, 'Champ obligatoire').max(200);
export const bookingStatuses = ['new','contacted','pending','confirmed','cancelled'] as const;
export const proposalStatuses = ['new','reviewing','accepted','rejected'] as const;
export const bookingSchema = z.object({first_name:text,last_name:text,phone:text,email:z.string().email(),wedding_date:z.string().regex(/^\d{4}-\d{2}-\d{2}$/),wedding_time:z.string().regex(/^\d{2}:\d{2}$/),city:text,venue:text,car_id:z.string().uuid().nullable(),car_name:text,service_type:text,message:z.string().max(4000).default('')});
export const proposalSchema = z.object({id:z.string().uuid(),first_name:text,last_name:text,phone:text,email:z.string().email(),city:text,brand:text,model:text,year:z.coerce.number().int().min(1900).max(2100),color:text,vehicle_type:text,description:text.max(4000),availability:text,travel_zone:text,schedules:text,desired_rate:z.coerce.number().min(0).max(100000),message:z.string().max(4000).default(''),photos:z.array(z.string().max(500)).max(12)});
export type BookingInput = z.infer<typeof bookingSchema>;
