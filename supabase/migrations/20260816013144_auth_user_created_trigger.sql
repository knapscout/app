-- Captured from knapscout-prod (rgyeyzlwdlqiwlfgbxle) on 2026-08-16.
--
-- This trigger lives on auth.users, so it is NOT included in a
-- `supabase db dump --schema public`. Without it, a new signup never gets a
-- public.profiles row, and every subsequent insert into sites/pins/tracks/
-- sync_log fails its user_id foreign key. It is therefore required for the
-- local stack to be a faithful mirror of hosted.
--
-- The function public.handle_new_user() itself is defined in the companion
-- migration 20260816013143_remote_schema.sql and must be applied first.

CREATE OR REPLACE TRIGGER "on_auth_user_created"
  AFTER INSERT ON "auth"."users"
  FOR EACH ROW EXECUTE FUNCTION "public"."handle_new_user"();
