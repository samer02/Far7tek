import fs from 'fs';
const b = fs.readFileSync('supabase/reseed_cars_for_partners.sql', 'utf8').split('-- Voiture ');
console.log('--- BLOCK 3 ---');
console.log(b[3]);
