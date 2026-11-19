import fs from 'fs';

const reseed = fs.readFileSync('supabase/reseed_cars_for_partners.sql', 'utf8');
const carBlocks = reseed.split('-- Voiture ');

const parsed = [];

for (let i = 1; i < carBlocks.length; i++) {
  const b = carBlocks[i];
  const pMatch = b.match(/Partenaire (\d+): (partner\d+@far7tek\.tn)/);
  const pEmail = pMatch ? pMatch[2] : 'partner1@far7tek.tn';

  // Extract from INSERT INTO public.cars (...) VALUES (...)
  const valIdx = b.indexOf('VALUES (');
  const conflictIdx = b.indexOf(') ON CONFLICT (id)');
  if (valIdx === -1 || conflictIdx === -1) continue;

  const rawVals = b.substring(valIdx + 8, conflictIdx).trim();

  // Extract image storage path
  const imgMatch = b.match(/INSERT INTO public\.car_images [^)]+\) VALUES \(\s*'([^']+)',\s*'([^']+)',\s*'([^']+)'/);
  const imgUrl = imgMatch ? imgMatch[3] : 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80';

  parsed.push({
    carValues: rawVals,
    email: pEmail,
    img: imgUrl
  });
}

console.log('Total extracted blocks:', parsed.length);

// Generate final clean SQL
// We split the 100 cars into 2 parts of 50 cars each, or create 1 clean script.
// Let's see: how long is 1 script if we use multi-row insert?
// In PostgreSQL:
// INSERT INTO public.cars (...) VALUES (...), (...);
// INSERT INTO public.car_images (...) VALUES (...), (...);

const carRows = parsed.map(p => `(${p.carValues})`);
const imgRows = parsed.map((p, idx) => `(gen_random_uuid(), (SELECT id FROM public.cars WHERE sort_order = ${idx + 1} LIMIT 1), '${p.img}', (SELECT name FROM public.cars WHERE sort_order = ${idx + 1} LIMIT 1), true, 1)`);

const part1Cars = parsed.slice(0, 50);
const part2Cars = parsed.slice(50);

console.log('Part 1 cars:', part1Cars.length, 'Part 2 cars:', part2Cars.length);

fs.writeFileSync('part1_cars.json', JSON.stringify(part1Cars));
fs.writeFileSync('part2_cars.json', JSON.stringify(part2Cars));
