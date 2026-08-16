-- Add pins.hunt_id: which hunt (track) a pin was dropped during.
--
-- A "hunt" is a recorded field walk, stored in public.tracks. Until now a pin
-- recorded where it was dropped (lat/lng) and which site it belonged to, but
-- not which walk it was dropped on. Without that link, pins from separate
-- outings over the same ground are indistinguishable after the fact.
--
-- Nullable by design. A pin dropped while no track is recording has no hunt,
-- and that is a normal state, not missing data — the same way site_id IS NULL
-- means "dropped before a site was designated".


-- ---------------------------------------------------------------------------
-- 1. The column and its foreign key.
--
-- ON DELETE SET NULL, deliberately NOT the CASCADE that pins.site_id uses.
-- Deleting a hunt discards the recorded walk, not the finds made during it —
-- the pins are the field data and must outlive the track. A deleted hunt
-- leaves its pins in place with hunt_id reset to NULL.
-- ---------------------------------------------------------------------------

ALTER TABLE "public"."pins" ADD COLUMN IF NOT EXISTS "hunt_id" "uuid";

ALTER TABLE ONLY "public"."pins"
    ADD CONSTRAINT "pins_hunt_id_fkey" FOREIGN KEY ("hunt_id")
    REFERENCES "public"."tracks"("id") ON DELETE SET NULL;

COMMENT ON COLUMN "public"."pins"."hunt_id" IS 'The track (hunt) this pin was dropped during; NULL when no hunt was recording';


-- ---------------------------------------------------------------------------
-- 2. Index.
--
-- "show me everything I found on this hunt" filters on hunt_id, and the
-- ON DELETE SET NULL action itself scans pins for referencing rows whenever a
-- track is deleted. Both are sequential scans without this.
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS "pins_hunt_id_idx" ON "public"."pins" USING "btree" ("hunt_id");
