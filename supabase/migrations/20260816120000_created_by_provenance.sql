-- created_by: provenance, not authority.
--
-- Every KnapScout export since April 2026 has carried a created_by tag on
-- pins, sites and track points ("jason", "burke"), and until now the cloud
-- had nowhere to put it — the June migration and the Bite 4c-4e write path
-- simply dropped it. Bite 4f (import/export + legacy migration) needs it to
-- survive: when Jason imports Burke's export, the rows are OWNED by Jason
-- (user_id, enforced by RLS) but were AUTHORED by Burke, and that
-- distinction is field-data provenance worth keeping.
--
-- Deliberately:
--   * nullable  — rows written before this column, or by paths that don't
--                 know the author, are legal; NULL means "not recorded".
--   * text      — it holds the legacy free-text username tags as they exist
--                 in the exports, NOT a foreign key to profiles. The author
--                 may not have an account (Burke, pre-migration), and a
--                 deleted account must not take field provenance with it.
--   * no RLS change, no index — user_id remains the sole authority for
--                 ownership and access; created_by is never filtered on.
--
-- NOT YET APPLIED TO HOSTED. The 4f import/export write path sends this
-- column, so this migration must reach hosted before that code does.

ALTER TABLE "public"."pins"   ADD COLUMN IF NOT EXISTS "created_by" "text";
ALTER TABLE "public"."sites"  ADD COLUMN IF NOT EXISTS "created_by" "text";
ALTER TABLE "public"."tracks" ADD COLUMN IF NOT EXISTS "created_by" "text";

COMMENT ON COLUMN "public"."pins"."created_by"   IS 'Legacy/export username of the original author; provenance only, user_id is the authority';
COMMENT ON COLUMN "public"."sites"."created_by"  IS 'Legacy/export username of the original author; provenance only, user_id is the authority';
COMMENT ON COLUMN "public"."tracks"."created_by" IS 'Legacy/export username of the original author; provenance only, user_id is the authority';
