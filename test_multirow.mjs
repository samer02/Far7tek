import fs from 'fs';

const reseed = fs.readFileSync('supabase/reseed_cars_for_partners.sql', 'utf8');

// Extract all car VALUES and image VALUES
const carValues = [];
const imgValues = [];

const lines = reseed.split('\n');
let inCarValues = false;
let curCarVal = [];
let inImgValues = false;
let curImgVal = [];

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  if (line.startsWith('INSERT INTO public.cars (')) {
    // Find VALUES (
    while (i < lines.length && !lines[i].includes('VALUES (')) i++;
    curCarVal = [lines[i].replace(/.*VALUES\s*\(/, '(')];
    while (i < lines.length && !lines[i].includes(') ON CONFLICT')) {
      i++;
      if (lines[i].includes(') ON CONFLICT')) {
        curCarVal.push(lines[i].replace(/\)\s*ON CONFLICT.*/, ')'));
        break;
      } else {
        curCarVal.push(lines[i]);
      }
    }
    carValues.push(curCarVal.join('\n'));
  } else if (line.startsWith('INSERT INTO public.car_images (')) {
    while (i < lines.length && !lines[i].includes('VALUES (')) i++;
    curImgVal = [lines[i].replace(/.*VALUES\s*\(/, '(')];
    while (i < lines.length && !lines[i].includes(') ON CONFLICT')) {
      i++;
      if (lines[i].includes(') ON CONFLICT')) {
        curImgVal.push(lines[i].replace(/\)\s*ON CONFLICT.*/, ')'));
        break;
      } else {
        curImgVal.push(lines[i]);
      }
    }
    imgValues.push(curImgVal.join('\n'));
  }
}

console.log('carValues:', carValues.length);
console.log('imgValues:', imgValues.length);

const compactSql = `-- 1. Clean
DELETE FROM public.car_availability_rules;
DELETE FROM public.car_images;
DELETE FROM public.car_videos;
DELETE FROM public.trip_assignments;
DELETE FROM public.vehicle_change_requests;
DELETE FROM public.booking_requests;
DELETE FROM public.cars;

-- 2. Insert cars
INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES
` + carValues.join(',\n') + `;\n\n` +
`-- 3. Insert images
INSERT INTO public.car_images (id, car_id, storage_path, alt_text, is_cover, sort_order)
VALUES
` + imgValues.join(',\n') + `;\n`;

console.log('Total compact length:', compactSql.length);
fs.writeFileSync('compact_all.sql', compactSql);
