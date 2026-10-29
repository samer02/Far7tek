# 2027

IMPORTANT — CONSIGNE PRINCIPALE

Les screenshots fournis dans ce projet sont les références visuelles officielles du site.

Je veux que tu reproduises exactement les designs existants.

NE CHANGE PAS LE DESIGN

Ne fais aucune refonte graphique.

Ne propose pas un nouveau style.

Ne change pas :

les couleurs

la typographie

les tailles

les espacements

les proportions

les cards

les boutons

les bordures

les backgrounds

les sections

la disposition des éléments

la navbar

le sidebar

les tableaux

les formulaires

les icônes

les animations déjà présentes

la hiérarchie visuelle

Les screenshots sont la source de vérité pour le rendu visuel.

Si quelque chose n'est pas clairement visible dans les screenshots, utilise le style existant de l'interface au lieu d'inventer un nouveau design.

OBJECTIF

Transformer les designs fournis en une application web complète, fonctionnelle et responsive, tout en conservant exactement leur apparence.

Les interfaces concernées sont :

Accueil — Cortège & Cérémonie

Page détail voiture — Rolls-Royce Ghost Extended

Page Proposer ma voiture — Cortège & Cérémonie

Dashboard Admin — Cortège & Cérémonie

RESPONSIVE DESIGN

Le design fourni semble principalement basé sur une version desktop.

Il faut maintenant créer une adaptation responsive sans modifier l'identité visuelle originale.

Desktop

Reproduire le screenshot aussi fidèlement que possible.

Tablet

Adapter :

largeur des sections

grille

spacing

tableaux

formulaires

sans changer le style.

Mobile

Adapter intelligemment :

navbar → menu mobile

sidebar admin → drawer/menu mobile

cards → une colonne ou grille adaptée

tableaux → scroll horizontal ou présentation adaptée

formulaires → une colonne

images → largeur complète

boutons → adaptés au tactile

textes → ne doivent jamais déborder

sections → conserver le même ordre

IMPORTANT :

Le responsive doit être une adaptation du design existant, pas une nouvelle interface.

PAGE 1 — ACCUEIL

Reproduire exactement le design du screenshot :

Accueil — Cortège & Cérémonie

Conserver exactement :

Hero

navbar

typographie

couleurs

sections

cartes

CTA

galerie

footer

animations

La page doit être entièrement fonctionnelle.

Les données des voitures doivent venir de la base de données afin que l'Admin puisse les modifier.

PAGE 2 — DÉTAIL VOITURE

Reproduire exactement :

Rolls-Royce Ghost Extended — Cortège & Cérémonie

Conserver le layout existant.

La page doit être dynamique.

Lorsqu'un utilisateur clique sur une voiture depuis l'accueil :

/voitures/:id

La page affiche automatiquement :

nom

marque

modèle

description

caractéristiques

photos

vidéos

disponibilité

informations de prestation

bouton de demande

Le contenu doit venir de Supabase.

FORMULAIRE DE DEMANDE

Lorsque l'utilisateur clique sur :

Demander cette voiture

ouvrir le formulaire de réservation/demande.

Champs :

Prénom

Nom

Téléphone

Email

Date du mariage

Heure

Ville

Lieu du mariage

Voiture choisie

Type de prestation

Message

Après l'envoi :

Afficher une confirmation élégante en respectant exactement le design existant.

Message :

Votre demande a bien été envoyée.

"Notre équipe vous contactera dans un délai maximum de 24 heures pour confirmer votre demande."

Créer automatiquement la demande dans Supabase.

PAGE 3 — PROPOSER MA VOITURE

Reproduire exactement le screenshot :

Proposer ma voiture — Cortège & Cérémonie

Ne modifier absolument rien du design existant.

Le formulaire doit être fonctionnel.

Informations personnelles

Prénom

Nom

Téléphone

Email

Ville

Informations véhicule

Marque

Modèle

Année

Couleur

Type

Description

Photos

Permettre l'upload de plusieurs photos.

Les images doivent être stockées dans Supabase Storage.

Disponibilité

disponibilité

zone de déplacement

horaires

Tarif

Tarif souhaité

Message

Après soumission :

Afficher un message de confirmation dans le même style visuel.

Créer la proposition dans Supabase.

PAGE 4 — ADMIN DASHBOARD

Reproduire exactement le screenshot :

Dashboard de Direction & Espace Admin — Cortège & Cérémonie

Le dashboard doit conserver :

sidebar

navbar

cards statistiques

tableaux

boutons

filtres

graphiques

spacing

couleurs

style général

Aucune refonte.

ADMIN — GESTION DES DEMANDES

Créer une rubrique permettant à l'Admin de voir toutes les demandes.

Informations :

Client

Téléphone

Date mariage

Voiture

Ville

Date de demande

Statut

Statuts :

Nouvelle

Contacté

En attente

Confirmée

Annulée

L'Admin peut modifier le statut.

Ajouter également :

notes internes

détails complets

bouton appel

bouton WhatsApp

ADMIN — GESTION DES VOITURES

L'Admin peut :

ajouter une voiture

modifier

supprimer

activer/désactiver

ajouter photos

supprimer photos

ajouter vidéo

modifier description

modifier caractéristiques

définir disponibilité

définir voiture mise en avant

Toutes les modifications doivent apparaître automatiquement sur le site public.

ADMIN — GESTION GALERIE

L'Admin peut ajouter :

photos

vidéos

titre

description

date

prestation associée

Possibilité de supprimer/modifier les éléments.

ADMIN — PROPOSITIONS DE VOITURES

Afficher toutes les voitures proposées par les propriétaires.

Informations :

propriétaire

téléphone

ville

marque

modèle

année

photos

description

disponibilité

tarif

date de proposition

Statuts :

Nouvelle

En étude

Acceptée

Refusée

SUPABASE

Utiliser Supabase pour :

Authentication

Admin login sécurisé.

Database

Créer les tables nécessaires :

cars

car_images

car_videos

booking_requests

car_proposals

gallery

admin_notes

Storage

Buckets pour :

car-images

car-videos

gallery-media

proposal-images

Utiliser des URLs publiques ou sécurisées selon le besoin.

IMPORTANT — DESIGN SYSTEM

Avant de modifier ou créer une interface :

inspecter le design existant et réutiliser ses composants.

Créer des composants réutilisables uniquement lorsque cela ne change pas le rendu.

Exemples :

Button

Card

Input

Modal

Navbar

Sidebar

Table

Badge

Gallery

Mais les composants doivent respecter le design déjà présent.

RÈGLE ABSOLUE

DO NOT REDESIGN.

Le travail demandé est :

DESIGN EXISTANT → CODE PROPRE → RESPONSIVE → FONCTIONNEL → SUPABASE

et NON :

DESIGN EXISTANT → NOUVEAU DESIGN

Je veux retrouver visuellement les mêmes pages que dans les screenshots sur desktop, puis une adaptation responsive fidèle sur tablette et mobile.

Avant chaque modification visuelle, comparer avec les screenshots de référence.

Priorité absolue :

1. Fidélité au design
2. Responsive
3. Fonctionnalité
4. Architecture propre
5. Performance

## Base de données & Supabase
Ce projet est connecté à une instance Supabase externe via les variables d'environnement configurées dans `.env`.

## Development

Prefer working locally? You need Node.js and npm — [install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating).

```sh
git clone <this-repository-url>
cd <repository-name>
npm i
npm run dev
```
