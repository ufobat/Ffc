ALTER TABLE "users" ADD COLUMN "inchat" tinyint(1) NOT NULL DEFAULT '0';
ALTER TABLE "users" ADD COLUMN "lastchatid" integer NOT NULL DEFAULT '0';
ALTER TABLE "users" ADD COLUMN "lastseenchat" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "users" ADD COLUMN "lastseenchatactive" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "users" ADD COLUMN "chatrefreshsecs" integer NOT NULL DEFAULT 60;

CREATE TABLE "chat" (
    "id" integer PRIMARY KEY AUTOINCREMENT,
    "userfromid" integer NOT NULL,
    "msg" varchar(1024) NOT NULL,
    "posted" timestamp NOT NULL CURRENT_TIMESTAMP
);

