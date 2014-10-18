ALTER TABLE "users" ADD COLUMN "inchat" tinyint(1) NOT NULL DEFAULT '0';
ALTER TABLE "users" ADD COLUMN "lastchatid" integer NOT NULL DEFAULT '0';
ALTER TABLE "users" ADD COLUMN "lastseenchat" timestamp;
ALTER TABLE "users" ADD COLUMN "lastseenchatactive" timestamp;
ALTER TABLE "users" ADD COLUMN "chatrefreshsecs" integer NOT NULL DEFAULT 60;

UPDATE "users" SET "lastseenchat"=0;
UPDATE "users" SET "lastseenchatactive"=0;

CREATE TABLE "chat" (
    "id" integer PRIMARY KEY AUTOINCREMENT,
    "userfromid" integer NOT NULL,
    "msg" varchar(1024) NOT NULL
);

