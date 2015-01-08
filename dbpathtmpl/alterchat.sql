CREATE TABLE "chat_2" (
   "id" integer PRIMARY KEY AUTOINCREMENT,
   "userfromid" integer NOT NULL,
   "msg" text NOT NULL,
  "posted" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

insert into "chat_2" ("userfromid", "msg", "posted") 
    select "userfromid", "msg", "posted" from "chat";

drop table "chat";

alter table "chat_2" rename to "chat";


