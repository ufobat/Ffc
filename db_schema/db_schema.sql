/**************************************************************************************************/
/*** Konfiguration des Forums                                                                   ***/
/**************************************************************************************************/
CREATE TABLE "config" (
    "key"   TEXT NOT NULL, -- Konfigurations-Schlüsselstring
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
    "is_active" INTEGER NOT NULL DEFAULT 1, -- Boolean
    "name"      TEXT    NOT NULL,
    "color"     INTEGER,                    -- sprintf('%x', $_)
    "lastseen"  INTEGER,                    -- Unix-Timestamp
    "is_inchat" INTEGER NOT NULL DEFAULT 0  -- Boolean
);

CREATE INDEX "users_is_active_ix" ON "users"("is_active");
CREATE INDEX "users_is_inchat_ix" ON "users"("is_inchat");

/**************************************************************************************************/
/*** Erweiterte Benutzerkonfiguration                                                           ***/
/**************************************************************************************************/

CREATE TABLE "users_config" (
    "users_id" INTEGER NOT NULL,
    "is_admin" INTEGER NOT NULL DEFAULT 0, -- Boolean
    "password" TEXT    NOT NULL,           -- Hash-Wert natürlich
    "bgcolor"  INTEGER,                    -- sprintf('%x', $_)
    FOREIGN KEY ("users_id") REFERENCES "users"(rowid)
);

CREATE INDEX "users_config_users_id_ix" ON "users_config"("users_id");
    
/**************************************************************************************************/
/*** Privatnachrichten-Management                                                               ***/
/**************************************************************************************************/
CREATE TABLE "users_2_users" (
    "users_id"      INTEGER NOT NULL,
    "users_from_id" INTEGER NOT NULL,
    "posts_last_id" INTEGER,
    FOREIGN KEY ("users_id")      REFERENCES "users"(rowid),
    FOREIGN KEY ("users_from_id") REFERENCES "users"(rowid),
    FOREIGN KEY ("posts_last_id") REFERENCES "posts"(rowid) ON DELETE SET NULL
);

CREATE INDEX "users_2_users_users_id_ix"      ON "users_2_users"("users_id");
CREATE INDEX "users_2_users_users_from_id_ix" ON "users_2_users"("users_from_id");

/**************************************************************************************************/
/*** Themen                                                                                     ***/
/**************************************************************************************************/
CREATE TABLE "topics" (
    "title"         TEXT NOT NULL,
    "posts_last_id" INTEGER,
    "summary"       TEXT,
    FOREIGN KEY ("posts_last_id") REFERENCES "posts"(rowid) ON DELETE SET NULL
);
/**************************************************************************************************/
/*** Benutzer-Themen-Management                                                                 ***/
/**************************************************************************************************/
CREATE TABLE "users_2_topics" (
    "users_id"      INTEGER NOT NULL,
    "topics_id"     INTEGER NOT NULL,
    "posts_last_id" INTEGER,
    "pin"           INTEGER NOT NULL DEFAULT 0, -- Boolean
    "ignore"        INTEGER NOT NULL DEFAULT 0, -- Boolean
    FOREIGN KEY ("users_id")      REFERENCES  "users"(rowid),
    FOREIGN KEY ("topics_id")     REFERENCES "topics"(rowid),
    FOREIGN KEY ("posts_last_id") REFERENCES  "posts"(rowid)  ON DELETE SET NULL
);

CREATE INDEX "users_2_topics_users_id_ix" ON "users_2_topics"("users_id");
CREATE INDEX "users_2_topics_pin_ix"      ON "users_2_topics"("pin");
CREATE INDEX "users_2_topics_ignore_ix"   ON "users_2_topics"("ignore");

/**************************************************************************************************/
/*** Beiträge                                                                                   ***/
/**************************************************************************************************/
CREATE TABLE "posts" (
    "users_from_id"   INTEGER NOT NULL,
    "users_to_id"     INTEGER,                                    -- Privatnachricht
    "topics_id"       INTEGER,                                    -- Forenbeitrag
    "parent_posts_id" INTEGER,                                    -- Beitragskommentar
    "create_time"     INTEGER NOT NULL DEFAULT current_timestamp, -- Unix-Timestamp
    "plain_text"      TEXT    NOT NULL,                           -- Plain-Text ohne Formatierung
    "cache"           TEXT    NOT NULL,                           -- Formatierter Text
    FOREIGN KEY ("users_from_id")   REFERENCES  "users"(rowid)
    FOREIGN KEY ("users_to_id")     REFERENCES  "users"(rowid) ON DELETE SET NULL,
    FOREIGN KEY ("topics_id")       REFERENCES "topics"(rowid) ON DELETE SET NULL,
    FOREIGN KEY ("parent_posts_id") REFERENCES  "posts"(rowid) ON DELETE SET NULL
);

CREATE INDEX "posts_users_from_id_ix"   ON "posts"("users_from_id");
CREATE INDEX "posts_users_to_id_ix"     ON "posts"("users_to_id");
CREATE INDEX "posts_topics_id_ix"       ON "posts"("topics_id");
CREATE INDEX "posts_parent_posts_id_ix" ON "posts"("parents_posts_id");
CREATE INDEX "posts_create_time_ix"     ON "posts"("create_time");

/**************************************************************************************************/
/*** Beitragsanhänge                                                                            ***/
/**************************************************************************************************/
CREATE TABLE "attachements" (
    "posts_id" INTEGER NOT NULL,
    "filename" TEXT    NOT NULL,
    FOREIGN KEY ("posts_id") REFERENCES "posts"(rowid) ON DELETE SET NULL
);

CREATE INDEX "attachements_posts_id_ix" ON "attachements"("posts_id");

/**************************************************************************************************/
/*** Chatkomponente                                                                             ***/
/**************************************************************************************************/
CREATE TABLE "chat" (
    "users_from_id" INTEGER NOT NULL,
    "posts_id"      INTEGER NOT NULL,
    FOREIGN KEY ("users_from_id") REFERENCES "users"(rowid),
    FOREIGN KEY ("posts_id")      REFERENCES "posts"(rowid)    
);


