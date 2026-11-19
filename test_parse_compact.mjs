import fs from 'fs';

const fullReset = fs.readFileSync('supabase/full_reset.sql', 'utf8');

// Parse cars from full_reset.sql
const lines = fullReset.split('\n');
const cars = [];
let cur = null;
let curImgs = [];

for (let i = 2620; i < lines.length; i++) {
  const line = lines[i];
  if (line.startsWith('INSERT INTO public.cars (')) {
    if (cur) cars.push({ car: cur, imgs: curImgs });
    cur = [];
    curImgs = [];
  } else if (cur) {
    if (line.startsWith('INSERT INTO public.car_images (')) {
      const imgLines = [line];
      while (i + 1 < lines.length && !lines[i + 1].startsWith('INSERT INTO public.cars (') && !lines[i + 1].startsWith('INSERT INTO public.car_images (')) {
        i++;
        imgLines.push(lines[i]);
      }
      curImgs.push(imgLines.join('\n'));
    } else {
      cur.push(line);
    }
  }
}
if (cur) cars.push({ car: cur, imgs: curImgs });

console.log('Cars count:', cars.length);

// Let's create a compact array of cars in PL/pgSQL
let carData = [];
for (let i = 0; i < cars.length; i++) {
  const c = cars[i];
  const pNum = Math.min(20, Math.floor(i / 5) + 1);
  const pEmail = `partner${pNum}@far7tek.tn`;
  
  // Extract values from VALUES (...)
  const valText = c.car.join('\n');
  const m = valText.match(/VALUES\s*\(\s*'([^']+)',\s*'([^']+)',\s*'([^']+)',\s*'([^']+)',\s*'([^']+)',\s*([0-9]+|null),\s*'([^']+)',\s*'([^']+)',\s*'([^']*)',\s*'([^']*)',\s*([0-9.]+),\s*'([^']+)',\s*(true|false),\s*(true|false),\s*([0-9]+),\s*'([^']*)',\s*'([^']*)',\s*([0-9]+|null),\s*'([^']+)',\s*(ARRAY\[[^\]]*\]),\s*'([^']+)',\s*'([^']+)',\s*(ARRAY\[[^\]]*\]::text\[\]),\s*(true|false),\s*'([^']+)'\s*\)/);
  if (m) {
    // Extract first image url
    let imgUrl = '';
    if (c.imgs.length > 0) {
      const im = c.imgs[0].match(/'(https:\/\/[^']+)'/);
      if (im) imgUrl = im[1];
    }
    carData.push({
      id: m[1],
      name: m[2],
      brand: m[3],
      model: m[4],
      slug: m[5],
      year: parseInt(m[6]),
      color: m[7],
      cat: m[8],
      desc: m[9],
      price: parseFloat(m[11]),
      sort: parseInt(m[15]),
      partner: pEmail,
      seats: parseInt(m[18]),
      city: m[19],
      services: m[20],
      trans: m[21],
      fuel: m[22],
      equip: m[23],
      img: imgUrl
    });
  }
}

console.log('Successfully parsed carData count:', carData.length);
fs.writeFileSync('compact_cardata.json', JSON.stringify(carData));
