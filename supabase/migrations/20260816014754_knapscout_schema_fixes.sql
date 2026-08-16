-- KnapScout schema fixes.
--
-- These correct defects found in the schema captured from knapscout-prod in
-- 20260816013143_remote_schema.sql. They are kept in a separate migration so
-- the captured file remains a faithful record of what hosted actually looked
-- like on 2026-08-16.
--
-- NOT YET APPLIED TO HOSTED. Applying these to knapscout-prod is a separate,
-- deliberate step.


-- ---------------------------------------------------------------------------
-- 1. Make updated_at actually advance on UPDATE.
--
-- Every entity table declares `updated_at timestamptz DEFAULT now()`, but a
-- column default only fires on INSERT. Nothing maintained it on UPDATE, so
-- updated_at permanently reported creation time. The Bite 4 local-first sync
-- design resolves conflicts by comparing timestamps, so a timestamp that never
-- advances would silently resolve every conflict wrong.
--
-- sync_log is deliberately excluded: it is an append-only audit trail with no
-- updated_at column.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;

ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";

DROP TRIGGER IF EXISTS "set_updated_at" ON "public"."profiles";
CREATE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."profiles"
  FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

DROP TRIGGER IF EXISTS "set_updated_at" ON "public"."sites";
CREATE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."sites"
  FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

DROP TRIGGER IF EXISTS "set_updated_at" ON "public"."pins";
CREATE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."pins"
  FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

DROP TRIGGER IF EXISTS "set_updated_at" ON "public"."tracks";
CREATE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."tracks"
  FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


-- ---------------------------------------------------------------------------
-- 2. Remove the gen_random_uuid() default on sites.user_id.
--
-- Copy-pasted from the id column. user_id is a foreign key to profiles(id), so
-- defaulting it to a fresh random UUID guarantees a foreign key violation on
-- any insert that omits it. pins, tracks and sync_log correctly have no such
-- default.
-- ---------------------------------------------------------------------------

ALTER TABLE "public"."sites" ALTER COLUMN "user_id" DROP DEFAULT;


-- ---------------------------------------------------------------------------
-- 3. Remove the 'Null'::text default on profiles.username.
--
-- The column is UNIQUE, so the literal string 'Null' can only ever be claimed
-- by one row; a second direct insert omitting username fails on the unique
-- constraint. handle_new_user() supplies a generated username, which masked
-- this for signups but not for direct inserts.
-- ---------------------------------------------------------------------------

ALTER TABLE "public"."profiles" ALTER COLUMN "username" DROP DEFAULT;


-- ---------------------------------------------------------------------------
-- 4. Indexes for the columns every RLS policy filters on.
--
-- Each policy is `auth.uid() = user_id`, so every query filters on user_id.
-- Without these, every read is a sequential scan; tracks.points holds
-- multi-thousand-point JSON blobs, which makes those scans expensive.
--
-- profiles is intentionally absent: it has no user_id column. Its identity
-- column is `id`, already indexed by profiles_pkey, and its policies filter on
-- `auth.uid() = id`. An extra index there would be pure duplication.
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS "sites_user_id_idx"    ON "public"."sites"    USING "btree" ("user_id");
CREATE INDEX IF NOT EXISTS "pins_user_id_idx"     ON "public"."pins"     USING "btree" ("user_id");
CREATE INDEX IF NOT EXISTS "tracks_user_id_idx"   ON "public"."tracks"   USING "btree" ("user_id");
CREATE INDEX IF NOT EXISTS "sync_log_user_id_idx" ON "public"."sync_log" USING "btree" ("user_id");

CREATE INDEX IF NOT EXISTS "pins_site_id_idx"   ON "public"."pins"   USING "btree" ("site_id");
CREATE INDEX IF NOT EXISTS "tracks_site_id_idx" ON "public"."tracks" USING "btree" ("site_id");


-- ---------------------------------------------------------------------------
-- 5. pins.site_id: ON DELETE SET NULL -> ON DELETE CASCADE.
--
-- Deliberate behaviour change. Deleting a site now deletes its pins, matching
-- the behaviour tracks.site_id already had. "Unsorted" (site_id IS NULL) means
-- "dropped before a site was designated", not "orphaned by a deletion" —
-- SET NULL silently conflated the two.
-- ---------------------------------------------------------------------------

ALTER TABLE ONLY "public"."pins" DROP CONSTRAINT "pins_site_id_fkey";

ALTER TABLE ONLY "public"."pins"
    ADD CONSTRAINT "pins_site_id_fkey" FOREIGN KEY ("site_id")
    REFERENCES "public"."sites"("id") ON DELETE CASCADE;
