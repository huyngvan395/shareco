-- SQL Patch: Add has_blue_badge to shops table for platform admin verified tick checkmark.
-- Execute this script in your Supabase SQL Editor.

-- 1. Add column if it does not exist
ALTER TABLE public.shops 
ADD COLUMN IF NOT EXISTS has_blue_badge boolean NOT NULL DEFAULT false;

-- 2. Grant read/write access to authenticated users and service role (for safety)
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Shops are insertable by authenticated users" ON public.shops;
CREATE POLICY "Shops are insertable by authenticated users" 
ON public.shops 
FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Shops are updatable by owners or admins" ON public.shops;
CREATE POLICY "Shops are updatable by owners or admins" 
ON public.shops 
FOR UPDATE 
TO authenticated 
USING (auth.uid() = owner_id OR (select exists (select 1 from public.profiles where id = auth.uid() AND is_verified = true)));
