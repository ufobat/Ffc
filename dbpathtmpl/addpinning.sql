ALTER TABLE "lastseenforum" ADD COLUMN "pin" tinyint(1) NOT NULL DEFAULT '0';
UPDATE "lastseenforum" SET "pin"=0;
