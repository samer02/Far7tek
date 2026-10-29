ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'partner';
ALTER TYPE public.booking_status ADD VALUE IF NOT EXISTS 'accepted';
ALTER TYPE public.booking_status ADD VALUE IF NOT EXISTS 'rejected';
ALTER TYPE public.booking_status ADD VALUE IF NOT EXISTS 'in_progress';
ALTER TYPE public.booking_status ADD VALUE IF NOT EXISTS 'completed';
ALTER TYPE public.proposal_status ADD VALUE IF NOT EXISTS 'pending';
ALTER TYPE public.proposal_status ADD VALUE IF NOT EXISTS 'info_requested';
ALTER TYPE public.proposal_status ADD VALUE IF NOT EXISTS 'approved';