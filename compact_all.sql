-- 1. Clean
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
(
  '5f53f226-ef7b-570a-9142-81d634bef8c9', 'Rolls-Royce Ghost', 'Rolls-Royce', 'Ghost',
  'rolls-royce-ghost-1', 2022, 'Blanc', 'Berline de prestige',
  'Élégance royale et raffinement absolu pour une arrivée des mariés mémorable avec chauffeur en tenue.', 'Élégance royale et raffinement absolu pour une arrivée des mariés mémorable avec chauffeur en tenue.',
  1800.00, 'Disponible 7j/7', true, true, 1, (SELECT id FROM auth.users WHERE email = 'partner1@far7tek.tn'), 'active',
  4, 'Tunis', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver', 'water']::text[], false, 'always'
),
(
  '28feb2d6-5592-5557-8642-97bcb73aebcd', 'Rolls-Royce Phantom VIII', 'Rolls-Royce', 'Phantom VIII',
  'rolls-royce-phantom-viii-2', 2023, 'Noir', 'Berline de prestige',
  'Le summum du luxe automobile mondial. Prestation haute couture pour votre mariage.', 'Le summum du luxe automobile mondial. Prestation haute couture pour votre mariage.',
  2400.00, 'Disponible 7j/7', true, true, 2, (SELECT id FROM auth.users WHERE email = 'partner1@far7tek.tn'), 'active',
  4, 'Sousse', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'uniformed_driver', 'water', 'wifi']::text[], true, 'always'
),
(
  'c5cf7fe2-3781-53bf-be42-af7f78add149', 'Rolls-Royce Dawn Cabriolet', 'Rolls-Royce', 'Dawn',
  'rolls-royce-dawn-3', 2021, 'Ivoire', 'Cabriolet',
  'Cabriolet de prestige idéal pour des séances photo d''exception et un cortège à ciel ouvert.', 'Cabriolet de prestige idéal pour des séances photo d''exception et un cortège à ciel ouvert.',
  2200.00, 'Disponible 7j/7', true, true, 3, (SELECT id FROM auth.users WHERE email = 'partner1@far7tek.tn'), 'active',
  4, 'Sfax', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'convertible_roof', 'uniformed_driver', 'water']::text[], false, 'always'
),
(
  'f80690cd-365c-5ecc-a5b9-6516e364e464', 'Rolls-Royce Cullinan', 'Rolls-Royce', 'Cullinan',
  'rolls-royce-cullinan-4', 2023, 'Blanc', 'SUV',
  'Le SUV le plus luxueux au monde, prestance incomparable pour le cortège nuptial.', 'Le SUV le plus luxueux au monde, prestance incomparable pour le cortège nuptial.',
  2500.00, 'Disponible 7j/7', true, true, 4, (SELECT id FROM auth.users WHERE email = 'partner1@far7tek.tn'), 'active',
  4, 'Monastir', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver', 'wifi', 'water']::text[], true, 'always'
),
(
  '2cd1d676-f101-5df7-b28f-fae219af4d29', 'Mercedes-Maybach S680 V12', 'Mercedes-Maybach', 'S680',
  'mercedes-maybach-s680-5', 2023, 'Noir', 'Berline de prestige',
  'Sièges massants inclinables, insonorisation parfaite et décoration florale offerte.', 'Sièges massants inclinables, insonorisation parfaite et décoration florale offerte.',
  1400.00, 'Disponible 7j/7', true, true, 5, (SELECT id FROM auth.users WHERE email = 'partner1@far7tek.tn'), 'active',
  4, 'Nabeul', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver', 'water']::text[], true, 'always'
),
(
  'd0084c09-5eea-5e45-8bfd-e465f97d67f0', 'Mercedes-Maybach S580', 'Mercedes-Maybach', 'S580',
  'mercedes-maybach-s580-6', 2022, 'Champagne', 'Berline de prestige',
  'Harmonie parfaite de blanc nacré et champagne avec finitions en bois précieux.', 'Harmonie parfaite de blanc nacré et champagne avec finitions en bois précieux.',
  1250.00, 'Disponible 7j/7', true, true, 6, (SELECT id FROM auth.users WHERE email = 'partner2@far7tek.tn'), 'active',
  4, 'Hammamet', ARRAY['wedding', 'event'], 'automatic', 'hybrid', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver', 'water']::text[], false, 'always'
),
(
  'dedbbf0a-107e-55e5-b5f9-3150779d4ad1', 'Mercedes-Benz Classe S 500 W223', 'Mercedes-Benz', 'Classe S 500',
  'mercedes-benz-classe-s-500-7', 2023, 'Blanc', 'Berline de prestige',
  'Dernière génération de Classe S avec éclairage d''ambiance 64 couleurs et sonorisation Burmester.', 'Dernière génération de Classe S avec éclairage d''ambiance 64 couleurs et sonorisation Burmester.',
  950.00, 'Disponible 7j/7', true, true, 7, (SELECT id FROM auth.users WHERE email = 'partner2@far7tek.tn'), 'active',
  4, 'Bizerte', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], true, 'always'
),
(
  '5b35ab6b-24af-5fb6-bfda-54436fd689ce', 'Mercedes-Benz Classe S 400d AMG', 'Mercedes-Benz', 'Classe S 400d',
  'mercedes-benz-classe-s-400d-8', 2022, 'Noir', 'Berline de prestige',
  'Pack AMG complet, vitres teintées et confort princier pour les mariés.', 'Pack AMG complet, vitres teintées et confort princier pour les mariés.',
  850.00, 'Disponible 7j/7', true, true, 8, (SELECT id FROM auth.users WHERE email = 'partner2@far7tek.tn'), 'active',
  4, 'Tunis', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  '48048715-5957-5824-9926-32021ad31cc7', 'Mercedes-Benz Classe S 350d W222', 'Mercedes-Benz', 'Classe S 350d',
  'mercedes-benz-classe-s-350d-9', 2020, 'Argent', 'Berline de prestige',
  'Élégance intemporelle de la W222, très appréciée pour les cortèges de mariage en Tunisie.', 'Élégance intemporelle de la W222, très appréciée pour les cortèges de mariage en Tunisie.',
  700.00, 'Disponible 7j/7', true, true, 9, (SELECT id FROM auth.users WHERE email = 'partner2@far7tek.tn'), 'active',
  4, 'Sousse', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  '7934420b-becc-58b0-8ee3-52dc84915889', 'Mercedes-Benz Classe E 300 AMG Line W214', 'Mercedes-Benz', 'Classe E 300',
  'mercedes-benz-classe-e-300-10', 2024, 'Blanc', 'Berline de prestige',
  'Toute nouvelle Classe E 2024, technologie Superscreen et design ultra moderne.', 'Toute nouvelle Classe E 2024, technologie Superscreen et design ultra moderne.',
  650.00, 'Disponible 7j/7', true, true, 10, (SELECT id FROM auth.users WHERE email = 'partner2@far7tek.tn'), 'active',
  4, 'Ariana', ARRAY['wedding', 'event'], 'automatic', 'hybrid', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], true, 'always'
),
(
  '72796b04-8e5f-5ccb-991e-408217c8e710', 'Mercedes-Benz Classe E 220d Pack Nuit', 'Mercedes-Benz', 'Classe E 220d',
  'mercedes-benz-classe-e-220d-11', 2022, 'Gris', 'Berline de prestige',
  'Allure sportive et élégante, parfaite pour un cortège jeune et branché.', 'Allure sportive et élégante, parfaite pour un cortège jeune et branché.',
  550.00, 'Disponible 7j/7', true, true, 11, (SELECT id FROM auth.users WHERE email = 'partner3@far7tek.tn'), 'active',
  4, 'Ben Arous', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  '2552a85d-0752-503a-9f83-ae473c045e40', 'Mercedes-Benz CLE Coupé 300 AMG', 'Mercedes-Benz', 'CLE Coupé 300',
  'mercedes-benz-cle-coup-300-12', 2024, 'Blanc', 'Cabriolet',
  'Ligne de coupé racée pour une arrivée remarquée devant la mairie et la salle des fêtes.', 'Ligne de coupé racée pour une arrivée remarquée devant la mairie et la salle des fêtes.',
  750.00, 'Disponible 7j/7', true, true, 12, (SELECT id FROM auth.users WHERE email = 'partner3@far7tek.tn'), 'active',
  4, 'La Marsa', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], true, 'always'
),
(
  '795607ec-8278-53a7-9e9c-fb23cd0f5b34', 'Mercedes-Benz CLS 400d AMG', 'Mercedes-Benz', 'CLS 400d',
  'mercedes-benz-cls-400d-13', 2021, 'Noir', 'Berline de prestige',
  'Berline coupé 4 portes au style sculptural et à l''habitacle raffiné.', 'Berline coupé 4 portes au style sculptural et à l''habitacle raffiné.',
  680.00, 'Disponible 7j/7', true, false, 13, (SELECT id FROM auth.users WHERE email = 'partner3@far7tek.tn'), 'active',
  4, 'Djerba', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  '2bb49ec3-40cd-5c2f-abb0-0ca5684c1c8d', 'Mercedes-Benz CLA 200 AMG Line', 'Mercedes-Benz', 'CLA 200',
  'mercedes-benz-cla-200-14', 2023, 'Blanc', 'Berline de prestige',
  'Voiture des mariés très demandée en Tunisie pour son style dynamique et son rapport qualité-prix.', 'Voiture des mariés très demandée en Tunisie pour son style dynamique et son rapport qualité-prix.',
  480.00, 'Disponible 7j/7', true, false, 14, (SELECT id FROM auth.users WHERE email = 'partner3@far7tek.tn'), 'active',
  4, 'Sfax', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof']::text[], true, 'always'
),
(
  '87a28830-bdfa-58f3-9abf-a18f0a446556', 'Mercedes-AMG G63 V8 Biturbo', 'Mercedes-Benz', 'G63 AMG',
  'mercedes-benz-g63-amg-15', 2022, 'Noir', 'SUV',
  'Prestance colossale, sonorité envoûtante du V8 AMG pour ouvrir le cortège nuptial.', 'Prestance colossale, sonorité envoûtante du V8 AMG pour ouvrir le cortège nuptial.',
  1300.00, 'Disponible 7j/7', true, false, 15, (SELECT id FROM auth.users WHERE email = 'partner3@far7tek.tn'), 'active',
  4, 'Mahdia', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver', 'bluetooth_audio']::text[], false, 'always'
),
(
  'cbd10172-427f-56e6-9c8e-73e83e5ca693', 'Mercedes-Benz GLE 350de Coupé AMG', 'Mercedes-Benz', 'GLE 350de Coupé',
  'mercedes-benz-gle-350de-coup-16', 2023, 'Blanc', 'SUV',
  'SUV Coupé premium alliant modernité, grand confort et allure athlétique.', 'SUV Coupé premium alliant modernité, grand confort et allure athlétique.',
  750.00, 'Disponible 7j/7', true, false, 16, (SELECT id FROM auth.users WHERE email = 'partner4@far7tek.tn'), 'active',
  4, 'Sousse', ARRAY['wedding', 'event'], 'automatic', 'hybrid', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], true, 'always'
),
(
  'fba28cae-19b7-584f-9028-22e1ccc54f49', 'Porsche Panamera 4S', 'Porsche', 'Panamera 4S',
  'porsche-panamera-4s-17', 2022, 'Blanc', 'Berline de prestige',
  'Performance et prestance allemande pour une entrée triomphale des mariés.', 'Performance et prestance allemande pour une entrée triomphale des mariés.',
  1100.00, 'Disponible 7j/7', true, false, 17, (SELECT id FROM auth.users WHERE email = 'partner4@far7tek.tn'), 'active',
  4, 'Kairouan', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  '9693c638-dc16-5673-9ccb-2b620938030a', 'Porsche Panamera GTS', 'Porsche', 'Panamera GTS',
  'porsche-panamera-gts-18', 2021, 'Noir', 'Berline de prestige',
  'Version GTS avec échappement sport et intérieur Alcantara/cuir noir surpiqué.', 'Version GTS avec échappement sport et intérieur Alcantara/cuir noir surpiqué.',
  1200.00, 'Disponible 7j/7', true, false, 18, (SELECT id FROM auth.users WHERE email = 'partner4@far7tek.tn'), 'active',
  4, 'Monastir', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  'a2bdc4e4-118c-55e2-8b1f-2f478937bd13', 'Porsche Macan GTS', 'Porsche', 'Macan GTS',
  'porsche-macan-gts-19', 2023, 'Blanc', 'SUV',
  'SUV compact prestigieux parfait pour les séances photos à Sidi Bou Saïd ou La Marsa.', 'SUV compact prestigieux parfait pour les séances photos à Sidi Bou Saïd ou La Marsa.',
  700.00, 'Disponible 7j/7', true, false, 19, (SELECT id FROM auth.users WHERE email = 'partner4@far7tek.tn'), 'active',
  4, 'Tunis', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], true, 'always'
),
(
  'a48bbcf4-5574-5c31-9f34-7f2c65aaadb0', 'Porsche Cayenne Coupé Platinum', 'Porsche', 'Cayenne Coupé',
  'porsche-cayenne-coup-20', 2023, 'Gris', 'SUV',
  'Design musclé et finitions Platinum Edition pour sublimer votre journée.', 'Design musclé et finitions Platinum Edition pour sublimer votre journée.',
  850.00, 'Disponible 7j/7', true, false, 20, (SELECT id FROM auth.users WHERE email = 'partner4@far7tek.tn'), 'active',
  4, 'Gammarth', ARRAY['wedding', 'event'], 'automatic', 'hybrid', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], true, 'always'
),
(
  '611eced2-9165-57b0-bf05-96e3206b541b', 'Porsche Taycan 4S', 'Porsche', 'Taycan 4S',
  'porsche-taycan-4s-21', 2022, 'Bleu', 'Berline de prestige',
  'Berline 100% électrique avant-gardiste au silence feutré pour les mariés.', 'Berline 100% électrique avant-gardiste au silence feutré pour les mariés.',
  900.00, 'Disponible 7j/7', true, false, 21, (SELECT id FROM auth.users WHERE email = 'partner5@far7tek.tn'), 'active',
  4, 'Tunis', ARRAY['wedding', 'event'], 'automatic', 'electric', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  'a7302eac-516a-557b-83a5-cc8156c87f5d', 'BMW Série 7 740i G70', 'BMW', 'Série 7 740i',
  'bmw-s-rie-7-740i-22', 2023, 'Noir', 'Berline de prestige',
  'La nouvelle Série 7 avec écran cinéma 31 pouces arrière et calandre Iconic Glow.', 'La nouvelle Série 7 avec écran cinéma 31 pouces arrière et calandre Iconic Glow.',
  1150.00, 'Disponible 7j/7', true, false, 22, (SELECT id FROM auth.users WHERE email = 'partner5@far7tek.tn'), 'active',
  4, 'Sousse', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver', 'wifi']::text[], true, 'always'
),
(
  '74a14c23-90fb-5025-8dac-e7df4d180359', 'BMW Série 7 730d M Sport G11', 'BMW', 'Série 7 730d',
  'bmw-s-rie-7-730d-23', 2021, 'Blanc', 'Berline de prestige',
  'Confort princier et allure M Sport plébiscitée pour les mariages tunisiens.', 'Confort princier et allure M Sport plébiscitée pour les mariages tunisiens.',
  800.00, 'Disponible 7j/7', true, false, 23, (SELECT id FROM auth.users WHERE email = 'partner5@far7tek.tn'), 'active',
  4, 'Sfax', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  '91816af6-ee3a-5683-ab81-58425e8fe506', 'BMW Série 5 530i M Sport G30', 'BMW', 'Série 5 530i',
  'bmw-s-rie-5-530i-24', 2022, 'Blanc', 'Berline de prestige',
  'Berline d''affaires par excellence, très demandée pour les cortèges.', 'Berline d''affaires par excellence, très demandée pour les cortèges.',
  600.00, 'Disponible 7j/7', true, false, 24, (SELECT id FROM auth.users WHERE email = 'partner5@far7tek.tn'), 'active',
  4, 'Monastir', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  'b2ab4d44-0095-556f-8057-965ef86616f9', 'BMW Série 4 Gran Coupé 420i', 'BMW', 'Série 4 Gran Coupé',
  'bmw-s-rie-4-gran-coup-25', 2023, 'Bleu', 'Berline de prestige',
  'Couleur Bleu Portimao éclatante pour des photos de mariage spectaculaires.', 'Couleur Bleu Portimao éclatante pour des photos de mariage spectaculaires.',
  550.00, 'Disponible 7j/7', true, false, 25, (SELECT id FROM auth.users WHERE email = 'partner5@far7tek.tn'), 'active',
  4, 'Nabeul', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof']::text[], true, 'always'
),
(
  '2642af19-c3fc-5d27-a310-2e0f6af9d799', 'BMW Série 8 Gran Coupé M850i', 'BMW', 'Série 8 Gran Coupé',
  'bmw-s-rie-8-gran-coup-26', 2022, 'Noir', 'Berline de prestige',
  'Coupé 4 portes d''élite avec moteur V8 Biturbo de 530 chevaux.', 'Coupé 4 portes d''élite avec moteur V8 Biturbo de 530 chevaux.',
  1300.00, 'Disponible 7j/7', true, false, 26, (SELECT id FROM auth.users WHERE email = 'partner6@far7tek.tn'), 'active',
  4, 'Hammamet', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  'b9079c97-2440-5a56-ae09-30caf7bd51eb', 'BMW X7 xDrive40i M Sport', 'BMW', 'X7',
  'bmw-x7-27', 2023, 'Blanc', 'SUV',
  'Majestueux SUV BMW offrant une prestance colossale et un habitacle très généreux.', 'Majestueux SUV BMW offrant une prestance colossale et un habitacle très généreux.',
  1000.00, 'Disponible 7j/7', true, false, 27, (SELECT id FROM auth.users WHERE email = 'partner6@far7tek.tn'), 'active',
  5, 'Bizerte', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], true, 'always'
),
(
  '58fdcece-afe6-5f0e-bc57-3ff82ddee46a', 'BMW X6 xDrive30d M Sport', 'BMW', 'X6',
  'bmw-x6-28', 2022, 'Gris', 'SUV',
  'Pionnier du segment SUV Coupé au design expressif et percutant.', 'Pionnier du segment SUV Coupé au design expressif et percutant.',
  750.00, 'Disponible 7j/7', true, false, 28, (SELECT id FROM auth.users WHERE email = 'partner6@far7tek.tn'), 'active',
  4, 'Tunis', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  'bf90e59e-5ace-561f-98e9-b49cfafdaee8', 'Audi A8 L 55 TFSI Quattro', 'Audi', 'A8 L',
  'audi-a8-l-29', 2022, 'Noir', 'Berline de prestige',
  'Version longue avec espace aux jambes impérial et projecteurs Digital Matrix LED.', 'Version longue avec espace aux jambes impérial et projecteurs Digital Matrix LED.',
  850.00, 'Disponible 7j/7', true, false, 29, (SELECT id FROM auth.users WHERE email = 'partner6@far7tek.tn'), 'active',
  4, 'Sousse', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  '994e2694-53e6-5ff3-9d09-4047e0454d2c', 'Audi A7 Sportback 45 TFSI S-Line', 'Audi', 'A7 Sportback',
  'audi-a7-sportback-30', 2023, 'Blanc', 'Berline de prestige',
  'Ligne de toit fuyante spectaculaire et signature lumineuse animée.', 'Ligne de toit fuyante spectaculaire et signature lumineuse animée.',
  700.00, 'Disponible 7j/7', true, false, 30, (SELECT id FROM auth.users WHERE email = 'partner6@far7tek.tn'), 'active',
  4, 'Ariana', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], true, 'always'
),
(
  '787e0fcc-1766-5f4d-95ea-7a3d7c9aff71', 'Audi A6 S-Line 40 TDI', 'Audi', 'A6',
  'audi-a6-31', 2022, 'Argent', 'Berline de prestige',
  'Finition S-Line complète, sobre, statutaire et très confortable.', 'Finition S-Line complète, sobre, statutaire et très confortable.',
  550.00, 'Disponible 7j/7', true, false, 31, (SELECT id FROM auth.users WHERE email = 'partner7@far7tek.tn'), 'active',
  4, 'Ben Arous', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  '9ce8456a-2c65-5305-92bd-743efaf3035b', 'Audi Q8 S-Line 50 TDI', 'Audi', 'Q8',
  'audi-q8-32', 2023, 'Blanc', 'SUV',
  'Vaisseau amiral de la gamme Q, portes sans encadrement et design avant-gardiste.', 'Vaisseau amiral de la gamme Q, portes sans encadrement et design avant-gardiste.',
  800.00, 'Disponible 7j/7', true, false, 32, (SELECT id FROM auth.users WHERE email = 'partner7@far7tek.tn'), 'active',
  4, 'La Marsa', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], true, 'always'
),
(
  '6ad31e35-86cb-5e61-a957-279419221674', 'Audi A5 Sportback S-Line', 'Audi', 'A5 Sportback',
  'audi-a5-sportback-33', 2021, 'Gris', 'Berline de prestige',
  'L''élégance sportive allemande accessible pour votre cortège.', 'L''élégance sportive allemande accessible pour votre cortège.',
  480.00, 'Disponible 7j/7', true, false, 33, (SELECT id FROM auth.users WHERE email = 'partner7@far7tek.tn'), 'active',
  4, 'Djerba', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof']::text[], false, 'always'
),
(
  'f22ff51b-1972-58d5-bd9d-d8abfbeaa626', 'Range Rover Vogue Autobiography', 'Land Rover', 'Range Rover Vogue',
  'land-rover-range-rover-vogue-34', 2023, 'Blanc', 'SUV',
  'Le roi des SUV de luxe. Raffinement britannique suprême pour les mariés.', 'Le roi des SUV de luxe. Raffinement britannique suprême pour les mariés.',
  1200.00, 'Disponible 7j/7', true, false, 34, (SELECT id FROM auth.users WHERE email = 'partner7@far7tek.tn'), 'active',
  4, 'Sfax', ARRAY['wedding', 'event'], 'automatic', 'hybrid', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver', 'water']::text[], true, 'always'
),
(
  'f32472a6-9e79-53d6-bd71-d196c0b6836b', 'Range Rover Sport HSE Dynamic', 'Land Rover', 'Range Rover Sport',
  'land-rover-range-rover-sport-35', 2022, 'Noir', 'SUV',
  'Allure musclée et toit contrasté pour un cortège imposant.', 'Allure musclée et toit contrasté pour un cortège imposant.',
  850.00, 'Disponible 7j/7', true, false, 35, (SELECT id FROM auth.users WHERE email = 'partner7@far7tek.tn'), 'active',
  4, 'Mahdia', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  '0364d319-25f0-58f0-ae61-ecffa01e3e3c', 'Range Rover Velar R-Dynamic', 'Land Rover', 'Range Rover Velar',
  'land-rover-range-rover-velar-36', 2022, 'Ivoire', 'SUV',
  'Poignées affleurantes et design épuré récompensé dans le monde entier.', 'Poignées affleurantes et design épuré récompensé dans le monde entier.',
  650.00, 'Disponible 7j/7', true, false, 36, (SELECT id FROM auth.users WHERE email = 'partner8@far7tek.tn'), 'active',
  4, 'Sousse', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  'bd65894b-e4c6-5231-a49e-4aacf86f2dfa', 'Range Rover Evoque HSE', 'Land Rover', 'Range Rover Evoque',
  'land-rover-range-rover-evoque-37', 2022, 'Blanc', 'SUV',
  'SUV compact glamour idéal pour les mariages dans les villes côtières.', 'SUV compact glamour idéal pour les mariages dans les villes côtières.',
  480.00, 'Disponible 7j/7', true, false, 37, (SELECT id FROM auth.users WHERE email = 'partner8@far7tek.tn'), 'active',
  4, 'Kairouan', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof']::text[], false, 'always'
),
(
  '1a3a2743-4469-504f-bf12-590651ffe6f2', 'Jaguar XF Portfolio', 'Jaguar', 'XF',
  'jaguar-xf-38', 2022, 'Blanc', 'Berline de prestige',
  'L''élégance féline anglaise dans une berline racée.', 'L''élégance féline anglaise dans une berline racée.',
  550.00, 'Disponible 7j/7', true, false, 38, (SELECT id FROM auth.users WHERE email = 'partner8@far7tek.tn'), 'active',
  4, 'Monastir', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  'a45a9081-59d5-515b-b7ec-0071d46f146c', 'Jaguar XJ L Sovereign', 'Jaguar', 'XJ L',
  'jaguar-xj-l-39', 2020, 'Noir', 'Berline de prestige',
  'Version limousine longue au charme aristocratique indéniable.', 'Version limousine longue au charme aristocratique indéniable.',
  700.00, 'Disponible 7j/7', true, false, 39, (SELECT id FROM auth.users WHERE email = 'partner8@far7tek.tn'), 'active',
  4, 'Tunis', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  '8dadd781-393d-5d5e-8bb4-2b0c52f01f98', 'Maserati Ghibli Modena', 'Maserati', 'Ghibli',
  'maserati-ghibli-40', 2022, 'Blanc', 'Berline de prestige',
  'Le son mythique du moteur Ferrari sous le capot d''une berline italienne sculpturale.', 'Le son mythique du moteur Ferrari sous le capot d''une berline italienne sculpturale.',
  800.00, 'Disponible 7j/7', true, false, 40, (SELECT id FROM auth.users WHERE email = 'partner8@far7tek.tn'), 'active',
  4, 'Gammarth', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  '89e24515-8a0d-5935-b7ca-efe9fd3af153', 'Maserati Levante GranLusso', 'Maserati', 'Levante',
  'maserati-levante-41', 2021, 'Bleu', 'SUV',
  'Intérieur soyeux Ermenegildo Zegna et style italien inimitable.', 'Intérieur soyeux Ermenegildo Zegna et style italien inimitable.',
  850.00, 'Disponible 7j/7', true, false, 41, (SELECT id FROM auth.users WHERE email = 'partner9@far7tek.tn'), 'active',
  4, 'Tunis', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  'a4404890-3107-5867-a467-ecbb2301cedf', 'Bentley Continental GT', 'Bentley', 'Continental GT',
  'bentley-continental-gt-42', 2021, 'Blanc', 'Berline de prestige',
  'Grand Tourer d''exception associant artisanat anglais et performances supersoniques.', 'Grand Tourer d''exception associant artisanat anglais et performances supersoniques.',
  1900.00, 'Disponible 7j/7', true, false, 42, (SELECT id FROM auth.users WHERE email = 'partner9@far7tek.tn'), 'active',
  4, 'Sousse', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver', 'water']::text[], false, 'always'
),
(
  '04ce00c8-010e-5554-9c26-c737c3ee6b9f', 'Bentley Flying Spur V8', 'Bentley', 'Flying Spur',
  'bentley-flying-spur-43', 2022, 'Noir', 'Berline de prestige',
  'Mascotte Flying B rétractable et habitacle cousu main.', 'Mascotte Flying B rétractable et habitacle cousu main.',
  2100.00, 'Disponible 7j/7', true, false, 43, (SELECT id FROM auth.users WHERE email = 'partner9@far7tek.tn'), 'active',
  4, 'Sfax', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver', 'wifi', 'water']::text[], false, 'always'
),
(
  '34b63051-28f5-5b91-ada7-b319b0ea914b', 'Chrysler 300C Limousine Stretch 9m', 'Chrysler', '300C Limousine',
  'chrysler-300c-limousine-44', 2019, 'Blanc', 'Limousine',
  'Véritable limousine américaine de 9 mètres avec bar lumineux, ciel étoilé et sono VIP.', 'Véritable limousine américaine de 9 mètres avec bar lumineux, ciel étoilé et sono VIP.',
  1100.00, 'Disponible 7j/7', true, false, 44, (SELECT id FROM auth.users WHERE email = 'partner9@far7tek.tn'), 'active',
  8, 'Monastir', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'uniformed_driver', 'water', 'bluetooth_audio']::text[], false, 'always'
),
(
  '7898dcd3-3985-5049-a6fc-f5f06ba94c6f', 'Chrysler 300C Luxury Sedan', 'Chrysler', '300C',
  'chrysler-300c-45', 2020, 'Noir', 'Berline de prestige',
  'Calandre chromée majestueuse style Bentley pour un budget très doux.', 'Calandre chromée majestueuse style Bentley pour un budget très doux.',
  500.00, 'Disponible 7j/7', true, false, 45, (SELECT id FROM auth.users WHERE email = 'partner9@far7tek.tn'), 'active',
  4, 'Nabeul', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof']::text[], false, 'always'
),
(
  '4fa912d4-7a47-5d39-8452-a1cc4d45889e', 'Citroën Traction Avant 11B', 'Citroën', 'Traction Avant',
  'citro-n-traction-avant-46', 1954, 'Noir', 'Voiture de collection',
  'Véritable légende française entièrement restaurée. Idéale pour des mariages vintage.', 'Véritable légende française entièrement restaurée. Idéale pour des mariages vintage.',
  800.00, 'Disponible 7j/7', true, false, 46, (SELECT id FROM auth.users WHERE email = 'partner10@far7tek.tn'), 'active',
  4, 'Hammamet', ARRAY['wedding', 'event'], 'manual', 'petrol', ARRAY['leather_seats', 'flower_decoration', 'ribbons', 'uniformed_driver']::text[], false, 'always'
),
(
  '1c969b89-f70d-50f7-8239-b7867c85df82', 'Peugeot 404 Cabriolet Pininfarina', 'Peugeot', '404 Cabriolet',
  'peugeot-404-cabriolet-47', 1968, 'Blanc', 'Voiture de collection',
  'Dessinée par Pininfarina, le chic méditerranéen pour vos photos de mariage.', 'Dessinée par Pininfarina, le chic méditerranéen pour vos photos de mariage.',
  750.00, 'Disponible 7j/7', true, false, 47, (SELECT id FROM auth.users WHERE email = 'partner10@far7tek.tn'), 'active',
  4, 'Bizerte', ARRAY['wedding', 'event'], 'manual', 'petrol', ARRAY['leather_seats', 'flower_decoration', 'convertible_roof', 'uniformed_driver']::text[], false, 'always'
),
(
  '682ae64e-136d-5cb8-b293-880fa20727b5', 'Volkswagen Coccinelle 1303 Cabriolet', 'Volkswagen', 'Coccinelle Cabriolet',
  'volkswagen-coccinelle-cabriolet-48', 1974, 'Blanc', 'Voiture de collection',
  'Une icône rétro pleine de joie et d''amour pour une fête inoubliable.', 'Une icône rétro pleine de joie et d''amour pour une fête inoubliable.',
  600.00, 'Disponible 7j/7', true, false, 48, (SELECT id FROM auth.users WHERE email = 'partner10@far7tek.tn'), 'active',
  4, 'Tunis', ARRAY['wedding', 'event'], 'manual', 'petrol', ARRAY['flower_decoration', 'convertible_roof', 'ribbons']::text[], false, 'always'
),
(
  '7d570a70-307d-59a1-8f0e-9c4d47c5ee94', 'Mercedes-Benz 280 SE W108', 'Mercedes-Benz', '280 SE',
  'mercedes-benz-280-se-49', 1970, 'Ivoire', 'Voiture de collection',
  'La grande dame de Stuttgart. Intérieur boisé et chrome étincelant.', 'La grande dame de Stuttgart. Intérieur boisé et chrome étincelant.',
  850.00, 'Disponible 7j/7', true, false, 49, (SELECT id FROM auth.users WHERE email = 'partner10@far7tek.tn'), 'active',
  4, 'Sousse', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], false, 'always'
),
(
  '9269647d-7b51-5c24-b071-81d4c157fbb1', 'Ford Mustang Fastback V8 1967', 'Ford', 'Mustang Fastback',
  'ford-mustang-fastback-50', 1967, 'Rouge', 'Voiture de collection',
  'Muscle car mythique des années 60 pour une entrée pleine de caractère et de passion.', 'Muscle car mythique des années 60 pour une entrée pleine de caractère et de passion.',
  900.00, 'Disponible 7j/7', true, false, 50, (SELECT id FROM auth.users WHERE email = 'partner10@far7tek.tn'), 'active',
  4, 'Ariana', ARRAY['wedding', 'event'], 'manual', 'petrol', ARRAY['leather_seats', 'flower_decoration', 'uniformed_driver']::text[], false, 'always'
),
(
  '735170da-b5a9-5ea6-a860-f91c170d2bac', 'Jaguar Mark II 3.8', 'Jaguar', 'Mark II',
  'jaguar-mark-ii-51', 1962, 'Ivoire', 'Voiture de collection',
  'Restaurée à l''état concours, boiseries en ronce de noyer et cuir anglais.', 'Restaurée à l''état concours, boiseries en ronce de noyer et cuir anglais.',
  900.00, 'Disponible 7j/7', true, false, 51, (SELECT id FROM auth.users WHERE email = 'partner11@far7tek.tn'), 'active',
  4, 'Ben Arous', ARRAY['wedding', 'event'], 'manual', 'petrol', ARRAY['leather_seats', 'flower_decoration', 'uniformed_driver']::text[], false, 'always'
),
(
  '3df0545c-c759-537b-b098-6c973f57c324', 'Aston Martin DB11 V8', 'Aston Martin', 'DB11',
  'aston-martin-db11-52', 2022, 'Argent', 'Berline de prestige',
  'Allure James Bond britannique, prestige et sonorité noble pour une arrivée de mariage grandiose.', 'Allure James Bond britannique, prestige et sonorité noble pour une arrivée de mariage grandiose.',
  1750.00, 'Disponible 7j/7', true, false, 52, (SELECT id FROM auth.users WHERE email = 'partner11@far7tek.tn'), 'active',
  4, 'La Marsa', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'uniformed_driver', 'bluetooth_audio']::text[], false, 'always'
),
(
  '4a443880-3c41-54ce-95af-351c967f86ee', 'Mercedes-Benz Classe V 250d Exclusive', 'Mercedes-Benz', 'Classe V 250d',
  'mercedes-benz-classe-v-250d-53', 2023, 'Noir', 'Van / minibus',
  'Salon VIP sur roues avec sièges en vis-à-vis, table pliante et climatisation tri-zone.', 'Salon VIP sur roues avec sièges en vis-à-vis, table pliante et climatisation tri-zone.',
  600.00, 'Disponible 7j/7', true, false, 53, (SELECT id FROM auth.users WHERE email = 'partner11@far7tek.tn'), 'active',
  7, 'Djerba', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'wifi', 'large_trunk', 'uniformed_driver', 'child_seats']::text[], true, 'always'
),
(
  '506f80d2-4c06-5501-9060-a29ccd19f7e8', 'Mercedes-Benz Classe V 300d AMG Line', 'Mercedes-Benz', 'Classe V 300d',
  'mercedes-benz-classe-v-300d-54', 2022, 'Gris', 'Van / minibus',
  'Idéal pour transporter la belle-famille et les invités d''honneur avec un maximum de confort.', 'Idéal pour transporter la belle-famille et les invités d''honneur avec un maximum de confort.',
  650.00, 'Disponible 7j/7', true, false, 54, (SELECT id FROM auth.users WHERE email = 'partner11@far7tek.tn'), 'active',
  8, 'Sfax', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'large_trunk', 'uniformed_driver', 'child_seats']::text[], false, 'always'
),
(
  'd233e91d-a359-5536-9a07-3291acb0178a', 'Mercedes-Benz Vito Tourer PRO', 'Mercedes-Benz', 'Vito Tourer',
  'mercedes-benz-vito-tourer-55', 2022, 'Blanc', 'Van / minibus',
  'Navette 9 places spacieuse pour les transferts vers la salle des fêtes ou l''aéroport.', 'Navette 9 places spacieuse pour les transferts vers la salle des fêtes ou l''aéroport.',
  450.00, 'Disponible 7j/7', true, false, 55, (SELECT id FROM auth.users WHERE email = 'partner11@far7tek.tn'), 'active',
  9, 'Mahdia', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'usb_charging', 'large_trunk', 'child_seats']::text[], false, 'always'
),
(
  '942fef47-843b-5b26-b83b-b1f141c18c14', 'Mercedes-Benz Vito Select Long', 'Mercedes-Benz', 'Vito Select',
  'mercedes-benz-vito-select-56', 2021, 'Noir', 'Van / minibus',
  'Confortable et économique pour toute la famille lors des soirées de mariage.', 'Confortable et économique pour toute la famille lors des soirées de mariage.',
  480.00, 'Disponible 7j/7', true, false, 56, (SELECT id FROM auth.users WHERE email = 'partner12@far7tek.tn'), 'active',
  9, 'Sousse', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
),
(
  '3cbd3d0d-b818-5622-9b0e-7fc7079d3e41', 'Mercedes-Benz Sprinter 519 VIP Lounge', 'Mercedes-Benz', 'Sprinter VIP',
  'mercedes-benz-sprinter-vip-57', 2023, 'Noir', 'Van / minibus',
  'Minibus grand luxe 16 places équipé d''écrans vidéo et sièges cuir inclinables.', 'Minibus grand luxe 16 places équipé d''écrans vidéo et sièges cuir inclinables.',
  950.00, 'Disponible 7j/7', true, false, 57, (SELECT id FROM auth.users WHERE email = 'partner12@far7tek.tn'), 'active',
  16, 'Kairouan', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'wifi', 'large_trunk', 'uniformed_driver']::text[], true, 'always'
),
(
  '769bfcd7-2efe-5cf5-b288-d8194d461518', 'Mercedes-Benz Sprinter Transfer', 'Mercedes-Benz', 'Sprinter Transfer',
  'mercedes-benz-sprinter-transfer-58', 2021, 'Blanc', 'Van / minibus',
  'Parfait pour acheminer les invités en toute sécurité entre les hôtels et le lieu de fête.', 'Parfait pour acheminer les invités en toute sécurité entre les hôtels et le lieu de fête.',
  750.00, 'Disponible 7j/7', true, false, 58, (SELECT id FROM auth.users WHERE email = 'partner12@far7tek.tn'), 'active',
  15, 'Monastir', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'usb_charging']::text[], false, 'always'
),
(
  'b7449611-7a3f-5cba-873d-6cc71fd7e43b', 'Volkswagen Caravelle T6.1 Highline', 'Volkswagen', 'Caravelle T6.1',
  'volkswagen-caravelle-t6-1-59', 2023, 'Noir', 'Van / minibus',
  'La référence du transport familial en Tunisie, grand confort et coffre très spacieux.', 'La référence du transport familial en Tunisie, grand confort et coffre très spacieux.',
  480.00, 'Disponible 7j/7', true, false, 59, (SELECT id FROM auth.users WHERE email = 'partner12@far7tek.tn'), 'active',
  9, 'Tunis', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'usb_charging', 'child_seats', 'uniformed_driver']::text[], true, 'always'
),
(
  '85f21ac4-4eba-5702-96e7-d050f879cae7', 'Volkswagen Caravelle T6 Trendline', 'Volkswagen', 'Caravelle T6',
  'volkswagen-caravelle-t6-60', 2020, 'Gris', 'Van / minibus',
  'Robuste et climatisé, idéal pour les navettes de mariage en Tunisie.', 'Robuste et climatisé, idéal pour les navettes de mariage en Tunisie.',
  420.00, 'Disponible 7j/7', true, false, 60, (SELECT id FROM auth.users WHERE email = 'partner12@far7tek.tn'), 'active',
  9, 'Gammarth', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
),
(
  '995b8593-bc2f-5cf2-860c-2d9962a5d662', 'Volkswagen Multivan T6.1 Comfortline', 'Volkswagen', 'Multivan T6.1',
  'volkswagen-multivan-t6-1-61', 2022, 'Blanc', 'Van / minibus',
  'Modulable et luxueux, fauteuils pivotants pour un trajet convivial en famille.', 'Modulable et luxueux, fauteuils pivotants pour un trajet convivial en famille.',
  550.00, 'Disponible 7j/7', true, false, 61, (SELECT id FROM auth.users WHERE email = 'partner13@far7tek.tn'), 'active',
  7, 'Tunis', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'child_seats', 'uniformed_driver']::text[], false, 'always'
),
(
  'f85c7d3b-15e7-5b8a-8009-21f0cdc56f56', 'Volkswagen Transporter Shuttle 9 Places', 'Volkswagen', 'Transporter Shuttle',
  'volkswagen-transporter-shuttle-62', 2021, 'Argent', 'Van / minibus',
  'Transport de groupe fiable et ponctuel pour votre cortège familial.', 'Transport de groupe fiable et ponctuel pour votre cortège familial.',
  400.00, 'Disponible 7j/7', true, false, 62, (SELECT id FROM auth.users WHERE email = 'partner13@far7tek.tn'), 'active',
  9, 'Sousse', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
),
(
  '9550be54-1b16-5de9-881c-7167bbbdc91f', 'Volkswagen Tiguan Allspace R-Line', 'Volkswagen', 'Tiguan Allspace',
  'volkswagen-tiguan-allspace-63', 2023, 'Blanc', 'SUV',
  'SUV 7 places élégant pour accompagner les mariés et transporter les proches.', 'SUV 7 places élégant pour accompagner les mariés et transporter les proches.',
  420.00, 'Disponible 7j/7', true, false, 63, (SELECT id FROM auth.users WHERE email = 'partner13@far7tek.tn'), 'active',
  7, 'Sfax', ARRAY['family', 'private'], 'automatic', 'petrol', ARRAY['air_conditioning', 'sunroof', 'child_seats', 'large_trunk']::text[], true, 'always'
),
(
  '368af0a0-cbda-55eb-ad4b-e0a0673eed58', 'Volkswagen Touran Family', 'Volkswagen', 'Touran',
  'volkswagen-touran-64', 2021, 'Gris', 'Van / minibus',
  'Monospace familial moderne et sécurisant avec fixations Isofix multiples.', 'Monospace familial moderne et sécurisant avec fixations Isofix multiples.',
  320.00, 'Disponible 7j/7', true, false, 64, (SELECT id FROM auth.users WHERE email = 'partner13@far7tek.tn'), 'active',
  7, 'Monastir', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'child_seats', 'large_trunk']::text[], false, 'always'
),
(
  '95c3c3e2-f451-5801-861a-920f4c003a40', 'Hyundai Staria Premium 9 Places', 'Hyundai', 'Staria Premium',
  'hyundai-staria-premium-65', 2023, 'Noir', 'Van / minibus',
  'Design futuriste spectaculaire et habitacle ultra moderne pour toute la famille.', 'Design futuriste spectaculaire et habitacle ultra moderne pour toute la famille.',
  550.00, 'Disponible 7j/7', true, false, 65, (SELECT id FROM auth.users WHERE email = 'partner13@far7tek.tn'), 'active',
  9, 'Nabeul', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'wifi', 'large_trunk', 'uniformed_driver']::text[], true, 'always'
),
(
  'e4bea56d-5ca2-5d7c-960c-c42d757e3be9', 'Hyundai Staria Lounge 7 Places VIP', 'Hyundai', 'Staria Lounge',
  'hyundai-staria-lounge-66', 2024, 'Blanc', 'Van / minibus',
  'Fauteuils relaxation digne d''une première classe aérienne.', 'Fauteuils relaxation digne d''une première classe aérienne.',
  620.00, 'Disponible 7j/7', true, false, 66, (SELECT id FROM auth.users WHERE email = 'partner14@far7tek.tn'), 'active',
  7, 'Hammamet', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'wifi', 'large_trunk', 'uniformed_driver']::text[], true, 'always'
),
(
  '65479bb3-c718-5d69-a087-e54378707423', 'Hyundai H-1 Travel Royale 9 Places', 'Hyundai', 'H-1 Travel',
  'hyundai-h-1-travel-67', 2022, 'Argent', 'Van / minibus',
  'Le véhicule de transport familial le plus populaire en Tunisie.', 'Le véhicule de transport familial le plus populaire en Tunisie.',
  380.00, 'Disponible 7j/7', true, false, 67, (SELECT id FROM auth.users WHERE email = 'partner14@far7tek.tn'), 'active',
  9, 'Bizerte', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'usb_charging', 'child_seats']::text[], false, 'always'
),
(
  '54ab4683-ee40-5bd7-ae58-742ff192c36b', 'Hyundai H-1 GLX 9 Places', 'Hyundai', 'H-1 GLX',
  'hyundai-h-1-glx-68', 2020, 'Noir', 'Van / minibus',
  'Conduite souple, grand coffre et excellente climatisation pour l''été tunisien.', 'Conduite souple, grand coffre et excellente climatisation pour l''été tunisien.',
  350.00, 'Disponible 7j/7', true, false, 68, (SELECT id FROM auth.users WHERE email = 'partner14@far7tek.tn'), 'active',
  9, 'Tunis', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
),
(
  'e64814c5-3e58-5e0b-a428-da58ddaa5050', 'Hyundai Santa Fe Calligraphy 7 Places', 'Hyundai', 'Santa Fe',
  'hyundai-santa-fe-69', 2023, 'Noir', 'SUV',
  'Grand SUV familial raffiné avec 3 rangées de sièges en cuir Nappa.', 'Grand SUV familial raffiné avec 3 rangées de sièges en cuir Nappa.',
  480.00, 'Disponible 7j/7', true, false, 69, (SELECT id FROM auth.users WHERE email = 'partner14@far7tek.tn'), 'active',
  7, 'Sousse', ARRAY['family', 'private'], 'automatic', 'hybrid', ARRAY['air_conditioning', 'leather_seats', 'sunroof', 'child_seats', 'large_trunk']::text[], true, 'always'
),
(
  '1a7f14f5-f272-5be0-851f-d5e7038fd344', 'Toyota HiAce Grand Cabin VIP 12 Places', 'Toyota', 'HiAce Grand Cabin',
  'toyota-hiace-grand-cabin-70', 2023, 'Blanc', 'Van / minibus',
  'Spacieux, toit surélevé, parfait pour transporter toute la grande famille réunie.', 'Spacieux, toit surélevé, parfait pour transporter toute la grande famille réunie.',
  650.00, 'Disponible 7j/7', true, false, 70, (SELECT id FROM auth.users WHERE email = 'partner14@far7tek.tn'), 'active',
  12, 'Ariana', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'usb_charging', 'large_trunk', 'uniformed_driver']::text[], true, 'always'
),
(
  'a749ae8f-ff55-5283-9bb4-bf5af8bc9b78', 'Toyota HiAce Commuter 14 Places', 'Toyota', 'HiAce Commuter',
  'toyota-hiace-commuter-71', 2021, 'Blanc', 'Van / minibus',
  'Idéal pour le transport groupé des invités entre la ville et la banlieue.', 'Idéal pour le transport groupé des invités entre la ville et la banlieue.',
  600.00, 'Disponible 7j/7', true, false, 71, (SELECT id FROM auth.users WHERE email = 'partner15@far7tek.tn'), 'active',
  14, 'Ben Arous', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'uniformed_driver']::text[], false, 'always'
),
(
  '5f052345-e8c5-5de0-bc6b-5a9d14170287', 'Toyota Proace Verso VIP 9 Places', 'Toyota', 'Proace Verso',
  'toyota-proace-verso-72', 2022, 'Gris', 'Van / minibus',
  'Très confortable, insonorisé et modulable pour vos trajets de fête.', 'Très confortable, insonorisé et modulable pour vos trajets de fête.',
  460.00, 'Disponible 7j/7', true, false, 72, (SELECT id FROM auth.users WHERE email = 'partner15@far7tek.tn'), 'active',
  9, 'La Marsa', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats', 'usb_charging']::text[], false, 'always'
),
(
  '79404adf-af64-50fd-a543-5d10a73de206', 'Toyota Land Cruiser Prado VX 7 Places', 'Toyota', 'Land Cruiser Prado',
  'toyota-land-cruiser-prado-73', 2022, 'Blanc', 'SUV',
  'Le baroudeur de luxe idéal pour les trajets familiaux partout en Tunisie.', 'Le baroudeur de luxe idéal pour les trajets familiaux partout en Tunisie.',
  650.00, 'Disponible 7j/7', true, false, 73, (SELECT id FROM auth.users WHERE email = 'partner15@far7tek.tn'), 'active',
  7, 'Djerba', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'sunroof', 'large_trunk', 'child_seats']::text[], false, 'always'
),
(
  'a5ea5490-fcde-5066-94e0-a6c689c4759c', 'Peugeot Traveller VIP Business 8 Places', 'Peugeot', 'Traveller VIP',
  'peugeot-traveller-vip-74', 2023, 'Noir', 'Van / minibus',
  'Finition Business VIP avec sièges individuels en cuir et toit vitré panoramique.', 'Finition Business VIP avec sièges individuels en cuir et toit vitré panoramique.',
  500.00, 'Disponible 7j/7', true, false, 74, (SELECT id FROM auth.users WHERE email = 'partner15@far7tek.tn'), 'active',
  8, 'Sfax', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'large_trunk', 'child_seats', 'uniformed_driver']::text[], true, 'always'
),
(
  '29ba7af7-7517-5090-ad3f-9a48d9f0d6d9', 'Peugeot Traveller Allure 9 Places', 'Peugeot', 'Traveller Allure',
  'peugeot-traveller-allure-75', 2022, 'Blanc', 'Van / minibus',
  'Espace généreux pour 9 passagers avec leurs bagages et tenues de fête.', 'Espace généreux pour 9 passagers avec leurs bagages et tenues de fête.',
  440.00, 'Disponible 7j/7', true, false, 75, (SELECT id FROM auth.users WHERE email = 'partner15@far7tek.tn'), 'active',
  9, 'Mahdia', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
),
(
  '397197f8-ce34-53a9-95e4-8fcaf2775e3b', 'Peugeot Expert Combi 9 Places', 'Peugeot', 'Expert Combi',
  'peugeot-expert-combi-76', 2021, 'Gris', 'Van / minibus',
  'Rapport qualité/prix imbattable pour transporter les proches sereinement.', 'Rapport qualité/prix imbattable pour transporter les proches sereinement.',
  380.00, 'Disponible 7j/7', true, false, 76, (SELECT id FROM auth.users WHERE email = 'partner16@far7tek.tn'), 'active',
  9, 'Sousse', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk']::text[], false, 'always'
),
(
  'b0b69ffd-6e22-563e-93e7-31ec0879012e', 'Peugeot 5008 GT Line 7 Places', 'Peugeot', '5008 GT Line',
  'peugeot-5008-gt-line-77', 2023, 'Bleu', 'SUV',
  'SUV 7 places élégant au design félin, idéal pour accompagner le cortège.', 'SUV 7 places élégant au design félin, idéal pour accompagner le cortège.',
  390.00, 'Disponible 7j/7', true, false, 77, (SELECT id FROM auth.users WHERE email = 'partner16@far7tek.tn'), 'active',
  7, 'Kairouan', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'sunroof', 'child_seats', 'large_trunk']::text[], true, 'always'
),
(
  'd66ae054-23bf-590b-932b-01fb747c7024', 'Citroën SpaceTourer Business Lounge', 'Citroën', 'SpaceTourer Lounge',
  'citro-n-spacetourer-lounge-78', 2022, 'Noir', 'Van / minibus',
  'Suspension ultra confortable propre à Citroën pour un trajet sans secousses.', 'Suspension ultra confortable propre à Citroën pour un trajet sans secousses.',
  480.00, 'Disponible 7j/7', true, false, 78, (SELECT id FROM auth.users WHERE email = 'partner16@far7tek.tn'), 'active',
  8, 'Monastir', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'child_seats', 'large_trunk']::text[], false, 'always'
),
(
  '0f76c607-a808-5c12-9a56-38e58471dfa2', 'Citroën SpaceTourer Feel 9 Places', 'Citroën', 'SpaceTourer Feel',
  'citro-n-spacetourer-feel-79', 2021, 'Blanc', 'Van / minibus',
  'Navette 9 places lumineuse et agréable pour les sorties en famille.', 'Navette 9 places lumineuse et agréable pour les sorties en famille.',
  420.00, 'Disponible 7j/7', true, false, 79, (SELECT id FROM auth.users WHERE email = 'partner16@far7tek.tn'), 'active',
  9, 'Tunis', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
),
(
  '9e2f8f4a-868f-573e-97a5-de3f5398fdcf', 'Citroën Grand C4 SpaceTourer 7 Places', 'Citroën', 'Grand C4 SpaceTourer',
  'citro-n-grand-c4-spacetourer-80', 2021, 'Gris', 'Van / minibus',
  'Pare-brise panoramique grandiose pour admirer le cortège sur la route.', 'Pare-brise panoramique grandiose pour admirer le cortège sur la route.',
  320.00, 'Disponible 7j/7', true, false, 80, (SELECT id FROM auth.users WHERE email = 'partner16@far7tek.tn'), 'active',
  7, 'Gammarth', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'child_seats', 'large_trunk']::text[], false, 'always'
),
(
  'a5c86916-f5a6-5b84-95f4-970e5ba01511', 'Renault Trafic Passenger SpaceClass', 'Renault', 'Trafic SpaceClass',
  'renault-trafic-spaceclass-81', 2023, 'Noir', 'Van / minibus',
  'La version haut de gamme du Trafic avec sellerie cuir et sièges pivotants.', 'La version haut de gamme du Trafic avec sellerie cuir et sièges pivotants.',
  490.00, 'Disponible 7j/7', true, false, 81, (SELECT id FROM auth.users WHERE email = 'partner17@far7tek.tn'), 'active',
  8, 'Tunis', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'large_trunk', 'uniformed_driver']::text[], true, 'always'
),
(
  'c4077253-7e23-5ac7-bab8-fff7acab89a0', 'Renault Trafic Grand Passenger 9 Places', 'Renault', 'Trafic Passenger',
  'renault-trafic-passenger-82', 2022, 'Blanc', 'Van / minibus',
  'Châssis long offrant un coffre géant même avec 9 passagers à bord.', 'Châssis long offrant un coffre géant même avec 9 passagers à bord.',
  410.00, 'Disponible 7j/7', true, false, 82, (SELECT id FROM auth.users WHERE email = 'partner17@far7tek.tn'), 'active',
  9, 'Sousse', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
),
(
  '11cff5bc-2923-5b86-9862-5189e603f165', 'Renault Espace V Initiale Paris 7 Places', 'Renault', 'Espace V',
  'renault-espace-v-83', 2022, 'Noir', 'Van / minibus',
  'Finition Initiale Paris avec cuir Nappa et système audio Bose.', 'Finition Initiale Paris avec cuir Nappa et système audio Bose.',
  460.00, 'Disponible 7j/7', true, false, 83, (SELECT id FROM auth.users WHERE email = 'partner17@far7tek.tn'), 'active',
  7, 'Sfax', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'sunroof', 'child_seats', 'large_trunk']::text[], false, 'always'
),
(
  'a8b09015-3d08-5823-a92a-0d4a20a237ac', 'Renault Grand Scénic Bose Edition 7 Places', 'Renault', 'Grand Scénic',
  'renault-grand-sc-nic-84', 2020, 'Bordeaux', 'Van / minibus',
  'Monospace compact moderne équipé de jantes 20 pouces et sonorisation Bose.', 'Monospace compact moderne équipé de jantes 20 pouces et sonorisation Bose.',
  300.00, 'Disponible 7j/7', true, false, 84, (SELECT id FROM auth.users WHERE email = 'partner17@far7tek.tn'), 'active',
  7, 'Monastir', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'child_seats', 'large_trunk']::text[], false, 'always'
),
(
  '9d600f9a-a47d-591a-8851-9a2585f10356', 'Ford Tourneo Custom Titanium X 8 Places', 'Ford', 'Tourneo Custom',
  'ford-tourneo-custom-85', 2023, 'Bleu', 'Van / minibus',
  'Intérieur grand confort avec configuration salon et insonorisation renforcée.', 'Intérieur grand confort avec configuration salon et insonorisation renforcée.',
  520.00, 'Disponible 7j/7', true, false, 85, (SELECT id FROM auth.users WHERE email = 'partner17@far7tek.tn'), 'active',
  8, 'Nabeul', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'large_trunk', 'child_seats', 'uniformed_driver']::text[], true, 'always'
),
(
  'ac235325-e191-54cf-a9e3-c606c5197088', 'Ford Tourneo Custom 9 Places', 'Ford', 'Tourneo Custom',
  'ford-tourneo-custom-86', 2021, 'Gris', 'Van / minibus',
  'Robuste et pratique pour tous les déplacements des familles et témoins.', 'Robuste et pratique pour tous les déplacements des familles et témoins.',
  430.00, 'Disponible 7j/7', true, false, 86, (SELECT id FROM auth.users WHERE email = 'partner18@far7tek.tn'), 'active',
  9, 'Hammamet', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
),
(
  '9f539f4f-d634-5c6e-86c9-24e374d82492', 'Ford Transit Minibus 14 Places', 'Ford', 'Transit Minibus',
  'ford-transit-minibus-87', 2022, 'Blanc', 'Van / minibus',
  'Idéal pour acheminer les grands groupes d''invités d''une ville à l''autre.', 'Idéal pour acheminer les grands groupes d''invités d''une ville à l''autre.',
  680.00, 'Disponible 7j/7', true, false, 87, (SELECT id FROM auth.users WHERE email = 'partner18@far7tek.tn'), 'active',
  14, 'Bizerte', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'uniformed_driver']::text[], false, 'always'
),
(
  '35ba26a0-4997-5eef-ac73-278e6d645a70', 'Kia Carnival Limousine 7 Places VIP', 'Kia', 'Carnival Limousine',
  'kia-carnival-limousine-88', 2023, 'Noir', 'Van / minibus',
  'Le luxe coréen ultime avec sièges lounge et portes latérales coulissantes électriques.', 'Le luxe coréen ultime avec sièges lounge et portes latérales coulissantes électriques.',
  580.00, 'Disponible 7j/7', true, false, 88, (SELECT id FROM auth.users WHERE email = 'partner18@far7tek.tn'), 'active',
  7, 'Tunis', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'wifi', 'large_trunk', 'uniformed_driver']::text[], true, 'always'
),
(
  '9afa50ec-47e2-5867-a7ab-dc4f70758b7c', 'Kia Carnival SX 8 Places', 'Kia', 'Carnival SX',
  'kia-carnival-sx-89', 2022, 'Blanc', 'Van / minibus',
  'Spacieux, moderne et idéal pour les familles nombreuses.', 'Spacieux, moderne et idéal pour les familles nombreuses.',
  510.00, 'Disponible 7j/7', true, false, 89, (SELECT id FROM auth.users WHERE email = 'partner18@far7tek.tn'), 'active',
  8, 'Sousse', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'child_seats', 'large_trunk']::text[], false, 'always'
),
(
  '48e26396-8fae-57e4-a54d-b16b701c3912', 'Kia Sorento GT-Line 7 Places', 'Kia', 'Sorento GT-Line',
  'kia-sorento-gt-line-90', 2023, 'Gris', 'SUV',
  'Grand SUV moderne très bien insonorisé avec 7 vraies places.', 'Grand SUV moderne très bien insonorisé avec 7 vraies places.',
  460.00, 'Disponible 7j/7', true, false, 90, (SELECT id FROM auth.users WHERE email = 'partner18@far7tek.tn'), 'active',
  7, 'Ariana', ARRAY['family', 'private'], 'automatic', 'hybrid', ARRAY['air_conditioning', 'leather_seats', 'sunroof', 'child_seats', 'large_trunk']::text[], true, 'always'
),
(
  'f7efc470-f299-5af9-b122-e230e77ffa61', 'Dacia Jogger Extreme 7 Places', 'Dacia', 'Jogger Extreme',
  'dacia-jogger-extreme-91', 2023, 'Gris', 'Van / minibus',
  'Solution économique et récente pour transporter jusqu''à 7 personnes.', 'Solution économique et récente pour transporter jusqu''à 7 personnes.',
  240.00, 'Disponible 7j/7', true, false, 91, (SELECT id FROM auth.users WHERE email = 'partner19@far7tek.tn'), 'active',
  7, 'Ben Arous', ARRAY['family', 'private'], 'manual', 'petrol', ARRAY['air_conditioning', 'child_seats', 'large_trunk']::text[], true, 'always'
),
(
  '904a4cff-1b79-5461-9a75-a3b382f59ebc', 'Dacia Lodgy Stepway 7 Places', 'Dacia', 'Lodgy Stepway',
  'dacia-lodgy-stepway-92', 2021, 'Bleu', 'Van / minibus',
  'Très économique et robuste pour les trajets vers la salle des fêtes.', 'Très économique et robuste pour les trajets vers la salle des fêtes.',
  220.00, 'Disponible 7j/7', true, false, 92, (SELECT id FROM auth.users WHERE email = 'partner19@far7tek.tn'), 'active',
  7, 'La Marsa', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'child_seats', 'large_trunk']::text[], false, 'always'
),
(
  '00a7ea9d-c7d9-5c52-b3aa-f6f33e60ddc8', 'Nissan NV300 Combi 9 Places', 'Nissan', 'NV300',
  'nissan-nv300-93', 2022, 'Blanc', 'Van / minibus',
  'Minibus pratique et fiable pour les groupes d''invités.', 'Minibus pratique et fiable pour les groupes d''invités.',
  390.00, 'Disponible 7j/7', true, false, 93, (SELECT id FROM auth.users WHERE email = 'partner19@far7tek.tn'), 'active',
  9, 'Djerba', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk']::text[], false, 'always'
),
(
  'a44aa441-d90e-58b2-8ef7-89df347c59e7', 'Opel Zafira Life Innovation 9 Places', 'Opel', 'Zafira Life',
  'opel-zafira-life-94', 2022, 'Gris', 'Van / minibus',
  'Navette moderne et confortable conçue pour les longs trajets en famille.', 'Navette moderne et confortable conçue pour les longs trajets en famille.',
  440.00, 'Disponible 7j/7', true, false, 94, (SELECT id FROM auth.users WHERE email = 'partner19@far7tek.tn'), 'active',
  9, 'Sfax', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
),
(
  '4d056b79-c1aa-587f-b3fe-b6df4bd39065', 'Fiat Ducato Panorama 15 Places', 'Fiat', 'Ducato Panorama',
  'fiat-ducato-panorama-95', 2022, 'Blanc', 'Van / minibus',
  'Minibus 15 places très spacieux pour les cortèges de mariage inter-villes.', 'Minibus 15 places très spacieux pour les cortèges de mariage inter-villes.',
  700.00, 'Disponible 7j/7', true, false, 95, (SELECT id FROM auth.users WHERE email = 'partner19@far7tek.tn'), 'active',
  15, 'Mahdia', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'uniformed_driver']::text[], false, 'always'
),
(
  '962ddf4b-eb74-5cea-a7d9-194e77e28c0f', 'Iveco Daily Minibus VIP 16 Places', 'Iveco', 'Daily VIP',
  'iveco-daily-vip-96', 2023, 'Noir', 'Van / minibus',
  'Prestation grand luxe pour déplacer l''ensemble de la délégation nuptiale.', 'Prestation grand luxe pour déplacer l''ensemble de la délégation nuptiale.',
  900.00, 'Disponible 7j/7', true, false, 96, (SELECT id FROM auth.users WHERE email = 'partner20@far7tek.tn'), 'active',
  16, 'Sousse', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'large_trunk', 'uniformed_driver', 'wifi']::text[], true, 'always'
),
(
  '9cb6bc29-db91-5154-a986-4caaca7acb0f', 'Mercedes-Benz Sprinter 519 VIP 19 Places', 'Mercedes-Benz', 'Sprinter 519 VIP',
  'mercedes-benz-sprinter-519-vip-97', 2023, 'Noir', 'Van / minibus',
  'Minibus VIP grand format pour les délégations familiales nombreuses et cortèges prestigieux.', 'Minibus VIP grand format pour les délégations familiales nombreuses et cortèges prestigieux.',
  1100.00, 'Disponible 7j/7', true, false, 97, (SELECT id FROM auth.users WHERE email = 'partner20@far7tek.tn'), 'active',
  19, 'Kairouan', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'large_trunk', 'uniformed_driver', 'wifi', 'usb_charging']::text[], true, 'always'
),
(
  'c76ffc28-c11c-5251-9775-4b36de8351c6', 'Peugeot Rifter Long 7 Places', 'Peugeot', 'Rifter Long',
  'peugeot-rifter-long-98', 2022, 'Gris', 'Van / minibus',
  'Ludospace 7 places économique et modulable pour le transport d''invités.', 'Ludospace 7 places économique et modulable pour le transport d''invités.',
  280.00, 'Disponible 7j/7', true, false, 98, (SELECT id FROM auth.users WHERE email = 'partner20@far7tek.tn'), 'active',
  7, 'Monastir', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'child_seats', 'large_trunk']::text[], false, 'always'
),
(
  '775ad15b-8017-5232-8e27-4afdce493b5e', 'Ford Galaxy Titanium 7 Places', 'Ford', 'Galaxy Titanium',
  'ford-galaxy-titanium-99', 2021, 'Noir', 'Van / minibus',
  'Grand monospace 7 places confortable avec toit vitré et climatisation arrière.', 'Grand monospace 7 places confortable avec toit vitré et climatisation arrière.',
  340.00, 'Disponible 7j/7', true, false, 99, (SELECT id FROM auth.users WHERE email = 'partner20@far7tek.tn'), 'active',
  7, 'Tunis', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'child_seats', 'large_trunk', 'sunroof']::text[], false, 'always'
),
(
  '44b9539e-f157-5735-bbca-288a9cbd73f0', 'Toyota Coaster VIP 22 Places', 'Toyota', 'Coaster VIP',
  'toyota-coaster-vip-100', 2022, 'Blanc', 'Van / minibus',
  'Autocar moyen format parfait pour les grands mariages réunissant deux familles de villes différentes.', 'Autocar moyen format parfait pour les grands mariages réunissant deux familles de villes différentes.',
  1000.00, 'Disponible 7j/7', true, false, 100, (SELECT id FROM auth.users WHERE email = 'partner20@far7tek.tn'), 'active',
  22, 'Gammarth', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'uniformed_driver']::text[], false, 'always'
);

-- 3. Insert images
INSERT INTO public.car_images (id, car_id, storage_path, alt_text, is_cover, sort_order)
VALUES
(
  '9990415f-2c52-5836-b224-8a4f64d14fff', '5f53f226-ef7b-570a-9142-81d634bef8c9', 'https://images.unsplash.com/photo-1631295868223-63265b40d9e4?auto=format&fit=crop&w=1200&q=80', 'Rolls-Royce Ghost', true, 1
),
(
  '036eb205-c917-5ca7-a7a4-0f19e257f869', '28feb2d6-5592-5557-8642-97bcb73aebcd', 'https://images.unsplash.com/photo-1563720223185-11003d516935?auto=format&fit=crop&w=1200&q=80', 'Rolls-Royce Phantom VIII', true, 1
),
(
  '65f32f7a-c155-5484-867d-1bcc9410727e', 'c5cf7fe2-3781-53bf-be42-af7f78add149', 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&w=1200&q=80', 'Rolls-Royce Dawn Cabriolet', true, 1
),
(
  '87fef1e6-2061-5d77-9025-1d0b5de66e31', 'f80690cd-365c-5ecc-a5b9-6516e364e464', 'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&w=1200&q=80', 'Rolls-Royce Cullinan', true, 1
),
(
  '8103461a-28c4-5581-b752-d20319820816', '2cd1d676-f101-5df7-b28f-fae219af4d29', 'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Maybach S680 V12', true, 1
),
(
  '0e85f466-ddf9-553d-9454-72c058d6650d', 'd0084c09-5eea-5e45-8bfd-e465f97d67f0', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Maybach S580', true, 1
),
(
  'c584946d-f788-5ae6-983e-c03114ecaa21', 'dedbbf0a-107e-55e5-b5f9-3150779d4ad1', 'https://images.unsplash.com/photo-1622353219448-656a4220b22a?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Classe S 500 W223', true, 1
),
(
  '8e18a722-5579-52cc-be0e-cea4f5ce19ee', '5b35ab6b-24af-5fb6-bfda-54436fd689ce', 'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Classe S 400d AMG', true, 1
),
(
  '6a8b157f-5c80-5b6a-a023-dbec12daed74', '48048715-5957-5824-9926-32021ad31cc7', 'https://images.unsplash.com/photo-1622353219448-656a4220b22a?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Classe S 350d W222', true, 1
),
(
  'ea52a76a-e56f-5fdf-a74f-f72b568bd9da', '7934420b-becc-58b0-8ee3-52dc84915889', 'https://images.unsplash.com/photo-1606016159991-dfe4f2746ad5?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Classe E 300 AMG Line W214', true, 1
),
(
  '89747e0f-a67c-5cab-a99a-b2ed117ba259', '72796b04-8e5f-5ccb-991e-408217c8e710', 'https://images.unsplash.com/photo-1606016159991-dfe4f2746ad5?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Classe E 220d Pack Nuit', true, 1
),
(
  'fedbfa39-c4fa-580a-99f3-903d66bc1d73', '2552a85d-0752-503a-9f83-ae473c045e40', 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz CLE Coupé 300 AMG', true, 1
),
(
  '8b1f6fc2-bebe-5a43-87bd-79bcabeb12c1', '795607ec-8278-53a7-9e9c-fb23cd0f5b34', 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz CLS 400d AMG', true, 1
),
(
  'f4357138-e009-52cd-9fed-b2c1a3dfd7f2', '2bb49ec3-40cd-5c2f-abb0-0ca5684c1c8d', 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz CLA 200 AMG Line', true, 1
),
(
  '35b1f569-b050-5cb4-898f-ae2230aa0566', '87a28830-bdfa-58f3-9abf-a18f0a446556', 'https://images.unsplash.com/photo-1520031441872-265e4ff70366?auto=format&fit=crop&w=1200&q=80', 'Mercedes-AMG G63 V8 Biturbo', true, 1
),
(
  'ef417091-5c35-5bde-a527-9d4751273d4c', 'cbd10172-427f-56e6-9c8e-73e83e5ca693', 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz GLE 350de Coupé AMG', true, 1
),
(
  '76879a3f-6a00-5fa8-bd88-3721f13a8763', 'fba28cae-19b7-584f-9028-22e1ccc54f49', 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=1200&q=80', 'Porsche Panamera 4S', true, 1
),
(
  '0bd3e00e-ec2a-5097-9c46-064c9b22b30e', '9693c638-dc16-5673-9ccb-2b620938030a', 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?auto=format&fit=crop&w=1200&q=80', 'Porsche Panamera GTS', true, 1
),
(
  'ff00da58-eabf-5893-9c61-8ee82c7f254a', 'a2bdc4e4-118c-55e2-8b1f-2f478937bd13', 'https://images.unsplash.com/photo-1614162692292-7ac56d7f7f1e?auto=format&fit=crop&w=1200&q=80', 'Porsche Macan GTS', true, 1
),
(
  'a335d4d0-6825-587e-a84e-7a9e41bd76bb', 'a48bbcf4-5574-5c31-9f34-7f2c65aaadb0', 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=1200&q=80', 'Porsche Cayenne Coupé Platinum', true, 1
),
(
  'e67fef77-1a5c-5076-aa15-5dda4595985a', '611eced2-9165-57b0-bf05-96e3206b541b', 'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&w=1200&q=80', 'Porsche Taycan 4S', true, 1
),
(
  '3bccfaba-6230-533b-93a4-304839174621', 'a7302eac-516a-557b-83a5-cc8156c87f5d', 'https://images.unsplash.com/photo-1555215695-3004980ad54e?auto=format&fit=crop&w=1200&q=80', 'BMW Série 7 740i G70', true, 1
),
(
  '85ab88b8-0653-5ccb-81d5-cb7076bcadb1', '74a14c23-90fb-5025-8dac-e7df4d180359', 'https://images.unsplash.com/photo-1555215695-3004980ad54e?auto=format&fit=crop&w=1200&q=80', 'BMW Série 7 730d M Sport G11', true, 1
),
(
  'ec94ef43-0a75-5125-9b5f-2553054ed069', '91816af6-ee3a-5683-ab81-58425e8fe506', 'https://images.unsplash.com/photo-1523983388277-336a66bf9bcd?auto=format&fit=crop&w=1200&q=80', 'BMW Série 5 530i M Sport G30', true, 1
),
(
  '4935187b-9714-567f-a17c-83467cb3873f', 'b2ab4d44-0095-556f-8057-965ef86616f9', 'https://images.unsplash.com/photo-1556189250-72ba954cfc2b?auto=format&fit=crop&w=1200&q=80', 'BMW Série 4 Gran Coupé 420i', true, 1
),
(
  'c0b83ec9-0a4c-556e-9021-156c40f8b50e', '2642af19-c3fc-5d27-a310-2e0f6af9d799', 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?auto=format&fit=crop&w=1200&q=80', 'BMW Série 8 Gran Coupé M850i', true, 1
),
(
  'de2cce76-41d8-5731-9915-8422ef619294', 'b9079c97-2440-5a56-ae09-30caf7bd51eb', 'https://images.unsplash.com/photo-1506015391300-4802dc74de2e?auto=format&fit=crop&w=1200&q=80', 'BMW X7 xDrive40i M Sport', true, 1
),
(
  '881b2413-4f97-585b-99ab-d0bafea9aed9', '58fdcece-afe6-5f0e-bc57-3ff82ddee46a', 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&w=1200&q=80', 'BMW X6 xDrive30d M Sport', true, 1
),
(
  '5da4f7da-d0b9-5f59-a1f5-9faa251c06a5', 'bf90e59e-5ace-561f-98e9-b49cfafdaee8', 'https://images.unsplash.com/photo-1606016159991-dfe4f2746ad5?auto=format&fit=crop&w=1200&q=80', 'Audi A8 L 55 TFSI Quattro', true, 1
),
(
  'a8c5a5f4-a36d-59a8-8b82-160b51847dad', '994e2694-53e6-5ff3-9d09-4047e0454d2c', 'https://images.unsplash.com/photo-1541348263662-e0c8de4259ba?auto=format&fit=crop&w=1200&q=80', 'Audi A7 Sportback 45 TFSI S-Line', true, 1
),
(
  'e757cbad-f8ae-5acb-bf0c-50f6a2d3394f', '787e0fcc-1766-5f4d-95ea-7a3d7c9aff71', 'https://images.unsplash.com/photo-1603584173870-7f23fdae1b7a?auto=format&fit=crop&w=1200&q=80', 'Audi A6 S-Line 40 TDI', true, 1
),
(
  'cc2f97dc-ca7f-5f8a-8dc4-a7a4a1198c1f', '9ce8456a-2c65-5305-92bd-743efaf3035b', 'https://images.unsplash.com/photo-1542282088-72c9c27ed0cd?auto=format&fit=crop&w=1200&q=80', 'Audi Q8 S-Line 50 TDI', true, 1
),
(
  'a7cd879c-b569-54b6-a569-a31b3a759848', '6ad31e35-86cb-5e61-a957-279419221674', 'https://images.unsplash.com/photo-1541348263662-e0c8de4259ba?auto=format&fit=crop&w=1200&q=80', 'Audi A5 Sportback S-Line', true, 1
),
(
  '47b6617e-5f99-575f-b0bf-fb7f3971f663', 'f22ff51b-1972-58d5-bd9d-d8abfbeaa626', 'https://images.unsplash.com/photo-1542282088-72c9c27ed0cd?auto=format&fit=crop&w=1200&q=80', 'Range Rover Vogue Autobiography', true, 1
),
(
  '80b9deee-69ec-5288-9c42-92e39f39f8cd', 'f32472a6-9e79-53d6-bd71-d196c0b6836b', 'https://images.unsplash.com/photo-1563720223185-11003d516935?auto=format&fit=crop&w=1200&q=80', 'Range Rover Sport HSE Dynamic', true, 1
),
(
  '955ce7e1-c521-58cc-8de2-0323cfd2c22e', '0364d319-25f0-58f0-ae61-ecffa01e3e3c', 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?auto=format&fit=crop&w=1200&q=80', 'Range Rover Velar R-Dynamic', true, 1
),
(
  '548a4396-0b4d-5d3a-8f1b-fb1b8f6fe061', 'bd65894b-e4c6-5231-a49e-4aacf86f2dfa', 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&w=1200&q=80', 'Range Rover Evoque HSE', true, 1
),
(
  '6a4a050b-086a-56b7-b851-8b7589b0b716', '1a3a2743-4469-504f-bf12-590651ffe6f2', 'https://images.unsplash.com/photo-1542282088-72c9c27ed0cd?auto=format&fit=crop&w=1200&q=80', 'Jaguar XF Portfolio', true, 1
),
(
  '3ef268df-338a-5d21-a276-c285381463ae', 'a45a9081-59d5-515b-b7ec-0071d46f146c', 'https://images.unsplash.com/photo-1563720223185-11003d516935?auto=format&fit=crop&w=1200&q=80', 'Jaguar XJ L Sovereign', true, 1
),
(
  '52114922-1727-53a9-aaf8-d6ce799b8f87', '8dadd781-393d-5d5e-8bb4-2b0c52f01f98', 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?auto=format&fit=crop&w=1200&q=80', 'Maserati Ghibli Modena', true, 1
),
(
  'c1edf8dc-b1f3-513a-ac5d-18f25729de41', '89e24515-8a0d-5935-b7ca-efe9fd3af153', 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=1200&q=80', 'Maserati Levante GranLusso', true, 1
),
(
  'c86c0bca-6ba9-5a47-a3e9-0158a0a7d632', 'a4404890-3107-5867-a467-ecbb2301cedf', 'https://images.unsplash.com/photo-1563720223185-11003d516935?auto=format&fit=crop&w=1200&q=80', 'Bentley Continental GT', true, 1
),
(
  '60edce2a-0c27-53dc-a6d1-db7eb225d1ba', '04ce00c8-010e-5554-9c26-c737c3ee6b9f', 'https://images.unsplash.com/photo-1631295868223-63265b40d9e4?auto=format&fit=crop&w=1200&q=80', 'Bentley Flying Spur V8', true, 1
),
(
  'bdf3ccef-a0df-529a-8354-135590d1cc08', '34b63051-28f5-5b91-ada7-b319b0ea914b', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Chrysler 300C Limousine Stretch 9m', true, 1
),
(
  '3bff2e48-5028-5248-beb1-b30f0f0a973b', '7898dcd3-3985-5049-a6fc-f5f06ba94c6f', 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&w=1200&q=80', 'Chrysler 300C Luxury Sedan', true, 1
),
(
  '2bd02914-32ba-54a6-a5f9-15010fa40783', '4fa912d4-7a47-5d39-8452-a1cc4d45889e', 'https://images.unsplash.com/photo-1508974239320-0a029497e820?auto=format&fit=crop&w=1200&q=80', 'Citroën Traction Avant 11B', true, 1
),
(
  '6782910a-cd41-5c05-b3c7-25f3c26e9ea9', '1c969b89-f70d-50f7-8239-b7867c85df82', 'https://images.unsplash.com/photo-1508974239320-0a029497e820?auto=format&fit=crop&w=1200&q=80', 'Peugeot 404 Cabriolet Pininfarina', true, 1
),
(
  'fbb92f82-8a02-5ac5-9c1f-ce1a284f2c27', '682ae64e-136d-5cb8-b293-880fa20727b5', 'https://images.unsplash.com/photo-1508974239320-0a029497e820?auto=format&fit=crop&w=1200&q=80', 'Volkswagen Coccinelle 1303 Cabriolet', true, 1
),
(
  'f95a97c2-a367-5eda-8cb0-4f1714202f74', '7d570a70-307d-59a1-8f0e-9c4d47c5ee94', 'https://images.unsplash.com/photo-1508974239320-0a029497e820?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz 280 SE W108', true, 1
),
(
  '8f912c7d-dd45-5370-9312-3981c524749e', '9269647d-7b51-5c24-b071-81d4c157fbb1', 'https://images.unsplash.com/photo-1584345604476-8ec5e12e42dd?auto=format&fit=crop&w=1200&q=80', 'Ford Mustang Fastback V8 1967', true, 1
),
(
  '96f2c9ba-898f-570f-93b2-cbd412c68d1d', '735170da-b5a9-5ea6-a860-f91c170d2bac', 'https://images.unsplash.com/photo-1508974239320-0a029497e820?auto=format&fit=crop&w=1200&q=80', 'Jaguar Mark II 3.8', true, 1
),
(
  'c2371e09-0e1e-5947-9ed6-6b98ffe99d66', '3df0545c-c759-537b-b098-6c973f57c324', 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&w=1200&q=80', 'Aston Martin DB11 V8', true, 1
),
(
  '83d4c696-34d2-5b01-8655-eb6f094cd41b', '4a443880-3c41-54ce-95af-351c967f86ee', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Classe V 250d Exclusive', true, 1
),
(
  '229a4236-e14d-5f82-9c7e-ee614dd59fd7', '506f80d2-4c06-5501-9060-a29ccd19f7e8', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Classe V 300d AMG Line', true, 1
),
(
  '9b2e8852-0c81-5378-9338-37e9ba92a546', 'd233e91d-a359-5536-9a07-3291acb0178a', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Vito Tourer PRO', true, 1
),
(
  '6a96849c-a762-50c8-818e-bfd1a6ee4033', '942fef47-843b-5b26-b83b-b1f141c18c14', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Vito Select Long', true, 1
),
(
  '9d878b19-26b6-56ea-806e-bff54b634a23', '3cbd3d0d-b818-5622-9b0e-7fc7079d3e41', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Sprinter 519 VIP Lounge', true, 1
),
(
  '74ac3b4f-bde0-557e-87b2-f79680a3790d', '769bfcd7-2efe-5cf5-b288-d8194d461518', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Sprinter Transfer', true, 1
),
(
  'b0f66975-e923-5613-89e8-344cc2d8e94b', 'b7449611-7a3f-5cba-873d-6cc71fd7e43b', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Volkswagen Caravelle T6.1 Highline', true, 1
),
(
  '4d82d553-9b02-5870-ba38-a4ae85671a1f', '85f21ac4-4eba-5702-96e7-d050f879cae7', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Volkswagen Caravelle T6 Trendline', true, 1
),
(
  '581e5b58-fb3d-5ca2-aefe-45f37e6392bd', '995b8593-bc2f-5cf2-860c-2d9962a5d662', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Volkswagen Multivan T6.1 Comfortline', true, 1
),
(
  '1aca57c0-05ee-5600-8e9a-0a82b0f0a73a', 'f85c7d3b-15e7-5b8a-8009-21f0cdc56f56', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Volkswagen Transporter Shuttle 9 Places', true, 1
),
(
  '9ec02de7-fb8e-52ce-9db5-6875af5f1216', '9550be54-1b16-5de9-881c-7167bbbdc91f', 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=1200&q=80', 'Volkswagen Tiguan Allspace R-Line', true, 1
),
(
  '2b7a6231-0def-5680-8146-c242f74a7f11', '368af0a0-cbda-55eb-ad4b-e0a0673eed58', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Volkswagen Touran Family', true, 1
),
(
  '50d8278e-8d3e-5406-8fab-f71f617a22f3', '95c3c3e2-f451-5801-861a-920f4c003a40', 'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&w=1200&q=80', 'Hyundai Staria Premium 9 Places', true, 1
),
(
  '7e301a64-4b9e-5967-b7b6-2b50b68c313a', 'e4bea56d-5ca2-5d7c-960c-c42d757e3be9', 'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&w=1200&q=80', 'Hyundai Staria Lounge 7 Places VIP', true, 1
),
(
  'd299b17e-0a8a-5955-87c3-a9ebb0474d28', '65479bb3-c718-5d69-a087-e54378707423', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Hyundai H-1 Travel Royale 9 Places', true, 1
),
(
  '286e28b4-09bd-5b42-86ce-1ebf54ce9ad1', '54ab4683-ee40-5bd7-ae58-742ff192c36b', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Hyundai H-1 GLX 9 Places', true, 1
),
(
  'adaac196-b18c-531c-97d4-dfef23855018', 'e64814c5-3e58-5e0b-a428-da58ddaa5050', 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=1200&q=80', 'Hyundai Santa Fe Calligraphy 7 Places', true, 1
),
(
  'dab1f580-a0e0-5a97-8a55-04d60156c8b4', '1a7f14f5-f272-5be0-851f-d5e7038fd344', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Toyota HiAce Grand Cabin VIP 12 Places', true, 1
),
(
  'dafc312e-924f-5e27-823c-eac5dc9415c6', 'a749ae8f-ff55-5283-9bb4-bf5af8bc9b78', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Toyota HiAce Commuter 14 Places', true, 1
),
(
  '1aca6d71-db30-5a3c-8379-2ac7f6f0c991', '5f052345-e8c5-5de0-bc6b-5a9d14170287', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Toyota Proace Verso VIP 9 Places', true, 1
),
(
  'fef2ac79-c242-51ee-b7d6-28d357ebf3d9', '79404adf-af64-50fd-a543-5d10a73de206', 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&w=1200&q=80', 'Toyota Land Cruiser Prado VX 7 Places', true, 1
),
(
  'c930654a-9380-5cd9-8097-42dddd82f5b9', 'a5ea5490-fcde-5066-94e0-a6c689c4759c', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Peugeot Traveller VIP Business 8 Places', true, 1
),
(
  'b0f6bbaf-a9bb-5100-bce6-7533dd95c4ab', '29ba7af7-7517-5090-ad3f-9a48d9f0d6d9', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Peugeot Traveller Allure 9 Places', true, 1
),
(
  'bc67263d-7a4f-5ba1-95d7-085f8cdd7dfa', '397197f8-ce34-53a9-95e4-8fcaf2775e3b', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Peugeot Expert Combi 9 Places', true, 1
),
(
  '278b0211-4f2f-589e-95be-882a465fa594', 'b0b69ffd-6e22-563e-93e7-31ec0879012e', 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=1200&q=80', 'Peugeot 5008 GT Line 7 Places', true, 1
),
(
  '99c94365-384a-5675-a845-102c6276fafb', 'd66ae054-23bf-590b-932b-01fb747c7024', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Citroën SpaceTourer Business Lounge', true, 1
),
(
  'c25a652f-3217-5036-ac69-293cf3547788', '0f76c607-a808-5c12-9a56-38e58471dfa2', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Citroën SpaceTourer Feel 9 Places', true, 1
),
(
  '4e7bc2c6-af72-5d67-8809-4791a8005d14', '9e2f8f4a-868f-573e-97a5-de3f5398fdcf', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Citroën Grand C4 SpaceTourer 7 Places', true, 1
),
(
  'f151c71c-d8bf-58a0-8f73-be0e9a91dc38', 'a5c86916-f5a6-5b84-95f4-970e5ba01511', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Renault Trafic Passenger SpaceClass', true, 1
),
(
  '757a8703-c8f6-5173-804e-dbf7d8e7d245', 'c4077253-7e23-5ac7-bab8-fff7acab89a0', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Renault Trafic Grand Passenger 9 Places', true, 1
),
(
  '60ec353f-86d6-586e-9eb0-416deb3c7a92', '11cff5bc-2923-5b86-9862-5189e603f165', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Renault Espace V Initiale Paris 7 Places', true, 1
),
(
  'b67defb1-dea8-587b-8d46-742b1804db2e', 'a8b09015-3d08-5823-a92a-0d4a20a237ac', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Renault Grand Scénic Bose Edition 7 Places', true, 1
),
(
  'cdca0bcd-3f83-57c2-9f88-73cd69bef62f', '9d600f9a-a47d-591a-8851-9a2585f10356', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Ford Tourneo Custom Titanium X 8 Places', true, 1
),
(
  '385df926-ce24-5151-ad62-0d115bc71b5b', 'ac235325-e191-54cf-a9e3-c606c5197088', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Ford Tourneo Custom 9 Places', true, 1
),
(
  '187b6ff2-4a44-5e3e-a0d7-cdd82395f1d2', '9f539f4f-d634-5c6e-86c9-24e374d82492', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Ford Transit Minibus 14 Places', true, 1
),
(
  '6fc27af5-b625-51d1-ac6f-7cd9b115f657', '35ba26a0-4997-5eef-ac73-278e6d645a70', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Kia Carnival Limousine 7 Places VIP', true, 1
),
(
  '19ecf06a-decb-51ca-95b1-18c3126c71fa', '9afa50ec-47e2-5867-a7ab-dc4f70758b7c', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Kia Carnival SX 8 Places', true, 1
),
(
  '9f7f3c35-5dd9-5c32-b108-3222495eaf35', '48e26396-8fae-57e4-a54d-b16b701c3912', 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=1200&q=80', 'Kia Sorento GT-Line 7 Places', true, 1
),
(
  'a3cdce27-448e-5897-8a40-b2a5a328b775', 'f7efc470-f299-5af9-b122-e230e77ffa61', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Dacia Jogger Extreme 7 Places', true, 1
),
(
  'ccb86e63-0595-5d15-bc36-e61774f29d1f', '904a4cff-1b79-5461-9a75-a3b382f59ebc', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Dacia Lodgy Stepway 7 Places', true, 1
),
(
  'a26afcf2-e0f8-5cb5-b7cf-09051a7c7b04', '00a7ea9d-c7d9-5c52-b3aa-f6f33e60ddc8', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Nissan NV300 Combi 9 Places', true, 1
),
(
  '9ec886dd-16d0-585f-ae27-e8054b2f6d36', 'a44aa441-d90e-58b2-8ef7-89df347c59e7', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Opel Zafira Life Innovation 9 Places', true, 1
),
(
  '6477866d-bb12-557e-bb1a-2d8d5422143d', '4d056b79-c1aa-587f-b3fe-b6df4bd39065', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Fiat Ducato Panorama 15 Places', true, 1
),
(
  '7010dcf5-5926-5805-87e2-342d1efbbd9e', '962ddf4b-eb74-5cea-a7d9-194e77e28c0f', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Iveco Daily Minibus VIP 16 Places', true, 1
),
(
  'b337ea25-7587-5469-a605-97b220405104', '9cb6bc29-db91-5154-a986-4caaca7acb0f', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Sprinter 519 VIP 19 Places', true, 1
),
(
  'b357cbfe-e125-5ff8-aa7b-362151f00a57', 'c76ffc28-c11c-5251-9775-4b36de8351c6', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Peugeot Rifter Long 7 Places', true, 1
),
(
  '9480414c-52cb-5c6a-ad73-33f57a3a6792', '775ad15b-8017-5232-8e27-4afdce493b5e', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Ford Galaxy Titanium 7 Places', true, 1
),
(
  '636d6318-e005-5281-83b2-757aef285800', '44b9539e-f157-5735-bbca-288a9cbd73f0', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Toyota Coaster VIP 22 Places', true, 1
);
