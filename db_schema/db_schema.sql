/**************************************************************************************************/
/*** Konfiguration des Forums                                                                   ***/
/**************************************************************************************************/
CREATE TABLE "config" (
    "key"   TEXT,
    "value" TEXT
);

INSERT INTO "config" ("key", "value") VALUES ('title', 'Ffc-Forum');   
INSERT INTO "config" ("key", "value") VALUES ('language', 'de');   
INSERT INTO "config" ("key", "value") VALUES ('seed', 'Ffc-Forum-Dummy-Seed');

CREATE INDEX "config_key_ix" ON "config"("key");

/**************************************************************************************************/
/*** Benutzerdaten                                                                              ***/
/**************************************************************************************************/
CREATE TABLE "users" (
    "is_active" INTEGER, -- Boolean
    "name"      TEXT,
    "color"     INTEGER, -- sprintf('%x', $_) ~ NULL erlaubt
    "lastseen"  INTEGER, -- Unix-Timestamp
    "is_inchat" INTEGER  -- Boolean
);

CREATE INDEX "users_is_active_ix" ON "users"("is_active");
CREATE INDEX "users_is_inchat_ix" ON "users"("is_inchat");

/**************************************************************************************************/
/*** Erweiterte Benutzerkonfiguration                                                           ***/
/**************************************************************************************************/

CREATE TABLE "users_config" (
    "users_id" INTEGER, -- FK "users" rowid    ~ NOT NULL
    "is_admin" INTEGER, -- Boolean             ~ 0|1
    "password" TEXT,    -- Hash-Wert natürlich ~ NOT NULL
    "bgcolor"  INTEGER  -- sprintf('%x', $_)   ~ NULL erlaubt
);

CREATE INDEX "users_config_users_id_ix" ON "users_config"("users_id");
    
/**************************************************************************************************/
/*** Privatnachrichten-Management                                                               ***/
/**************************************************************************************************/
CREATE TABLE "users_2_users" (
    "users_id"      INTEGER, -- FK "users".rowid
    "users_from_id" INTEGER, -- FK "users".rowid
    "posts_last_id" INTEGER  -- FK "posts".rowid
);

CREATE INDEX "users_2_users_users_id_ix" ON "users_2_users"("users_id");
CREATE INDEX "users_2_users_users_from_id_ix" ON "users_2_users"("users_from_id");

/**************************************************************************************************/
/*** Themen                                                                                     ***/
/**************************************************************************************************/
CREATE TABLE "topics" (
    "title"         TEXT, -- NOT NULL
    "posts_last_id" INTEGER, -- FK "posts".rowid, NULL erlaubt
    "summary"       TEXT
);
/**************************************************************************************************/
/*** Benutzer-Themen-Management                                                                 ***/
/**************************************************************************************************/
CREATE TABLE "users_2_topics" (
    "users_id"      INTEGER, -- FK "users".rowid, NOT NULL
    "topics_id"     INTEGER, -- FK "topics".rowid, NOT NULL
    "posts_last_id" INTEGER, -- FK "posts".rowid, NULL erlaubt
    "pin"           INTEGER, -- Boolean
    "ignore"        INTEGER  -- Boolean
);

CREATE INDEX "users_2_topics_users_id_ix" ON "users_2_topics"("users_id");
CREATE INDEX "users_2_topics_pin_ix" ON "users_2_topics"("pin");
CREATE INDEX "users_2_topics_ignore_ix" ON "users_2_topics"("ignore");

/**************************************************************************************************/
/*** Beiträge                                                                                   ***/
/**************************************************************************************************/
CREATE TABLE "posts" (
    "users_from_id"   INTEGER, -- FK "users".rowid  ~ NOT NULL
    "users_to_id"     INTEGER, -- FK "users".rowid, ~ Privatnachricht,   sonst NULL
    "topics_id"       INTEGER, -- FK "topics".rowid ~ Forenbeitrag,      sonst NULL
    "parent_posts_id" INTEGER, -- FK "posts".rowid  ~ Beitragskommentar, sonst NULL
    "create_time"     INTEGER, -- Unix-Timestamp    ~ NOT NULL, Default current_timestamp
    "plain_text"      TEXT,    -- Eingegebener Text ohne Formatierungsumwandlungen, NOT NULL
    "cache"           TEXT     -- Formatierter Text, NOT NULL
);

CREATE INDEX "posts_users_from_id_ix" ON "posts"("users_from_id");
CREATE INDEX "posts_users_to_id_ix" ON "posts"("users_to_id");
CREATE INDEX "posts_topics_id_ix" ON "posts"("topics_id");
CREATE INDEX "posts_parent_posts_id_ix" ON "posts"("parents_posts_id");
CREATE INDEX "posts_create_time_ix" ON "posts"("create_time");

/**************************************************************************************************/
/*** Beitragsanhänge                                                                            ***/
/**************************************************************************************************/
CREATE TABLE "attachements" (
    "posts_id" INTEGER, -- FK "posts".rowid, NOT NULL
    "filename" TEXT     -- NOT NULL
);

CREATE INDEX "attachements_posts_id_ix" ON "attachements"("posts_id");

/**************************************************************************************************/
/*** Chatkomponente                                                                             ***/
/**************************************************************************************************/
CREATE TABLE "chat" (
    "user_from_id" INTEGER, -- FK "users".rowid
    "textdata_id"  INTEGER, -- FK "posts".rowid
);


