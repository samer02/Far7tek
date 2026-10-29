# Plan : plateforme mariage + transport privé + partenaires

## Constat
- Les données sont en place (voitures, demandes de mariage, propositions de propriétaires, rôles admin), mais aucun écran n'est encore construit : il n'y a que la page vide.
- admin@gmail.com est administrateur.
- La nouvelle logique s'appuie sur ce qui existe, sans créer de tables en double.

## Étape 1 — Données et sécurité
- Élargir les demandes clients : rattachement au client connecté, type de service (mariage/événement, transport familial, aller-retour, autre), adresse de départ, destination, heure de retour, passagers, type de voiture, aller simple ou aller-retour, et les statuts pending, accepted, rejected, confirmed, in_progress, completed, cancelled.
- Élargir les dossiers partenaires : statuts pending, info_requested, approved, rejected, motif de refus, nombre de places, état, services proposés, adresse, photos classées (principale, extérieur, intérieur, documents).
- Rôle « partner » ; voitures liées à leur propriétaire, avec un statut de validation (en attente, active, désactivée).
- Nouveaux éléments : affectations demande → partenaire, historique des statuts, notifications internes, modifications de véhicule à valider.
- Règles d'accès : un client ne voit que ses demandes ; un partenaire ne voit que son véhicule et les demandes qui lui sont affectées ; seul l'admin valide. Les photos et documents privés restent dans un espace protégé.

## Étape 2 — Pages publiques (style des captures : noir chaud, or, titres éditoriaux)
- Accueil avec les trois services et les accès : Réserver, Devenir partenaire, Véhicules, Suivre ma demande, Connexion.
- Catalogue et fiche véhicule.
- Formulaire de réservation qui s'adapte au service choisi, puis confirmation.
- Page « Devenir partenaire » avec envoi et aperçu des photos, puis confirmation.
- Connexion / inscription (e-mail + Google).

## Étape 3 — Espace client
- « Mes demandes » avec le statut et le détail de chaque demande.

## Étape 4 — Administration
- Sections : Vue générale, Demandes clients, Partenaires, Véhicules, Attribution, Clients, Trajets, Notifications, Paramètres.
- Recherche, filtres et tri (date, ville, service, statut, partenaire).
- Dossier partenaire : accepter, refuser avec motif, demander des compléments, notes internes, contacter.
- À l'acceptation : le compte partenaire est créé et une invitation est envoyée pour que le propriétaire choisisse lui-même son mot de passe. Aucun mot de passe n'est affiché ni stocké.
- Attribution manuelle d'une demande à un partenaire, avec une liste de partenaires suggérés (ville, places, type de véhicule, service), prête pour une attribution automatique plus tard.

## Étape 5 — Espace partenaire
- Indicateurs, demandes affectées (accepter, refuser avec motif, suivre l'avancement), prochains trajets, historique.
- Véhicule : ajout de photos, disponibilités ; les changements importants partent en validation.
- Profil et sécurité (changement de mot de passe).

## Étape 6 — Notifications
- Centre de notifications dans le site pour chaque événement clé. Aucun envoi réel d'e-mail ou de SMS n'est simulé ; seule l'invitation partenaire utilise l'e-mail de connexion intégré.

## Étape 7 — Vérification
- Parcours complet testé : demande client → candidature → validation admin → connexion partenaire → traitement du trajet, sur ordinateur, tablette et mobile.

## Détails techniques
- Migrations additives (ALTER/ADD) sur booking_requests, car_proposals, cars ; nouvelles tables trip_assignments, trip_status_history, notifications, vehicle_change_requests, avec GRANT + RLS + has_role.
- Valeur « partner » ajoutée à l'enum app_role ; owner_id sur cars ; client_id sur booking_requests.
- Opérations sensibles (approbation, invitation via auth admin inviteUserByEmail, attribution) dans des createServerFn protégés, avec vérification du rôle admin avant tout accès privilégié.
- Routes protégées sous _authenticated (/compte, /partenaire, /admin/*) ; menus selon le rôle.
- Buckets privés + URLs signées pour les documents.
