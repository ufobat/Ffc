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

CREATE VIEW "active_users" (
        "users_id", "users_name", "users_color",
        "users_lastseen", "users_is_inchat"
    ) AS 
    SELECT 
        rowid, "name", "color",
        "lastseen", "is_inchat"
    FROM "users"
    WHERE "is_active" = 1
    ORDER BY "lastseen" DESC;

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

CREATE VIEW "users_all_config" (
        "users_id", "users_name", "users_color", "users_bgcolor",
        "users_is_admin", "users_password"
    ) AS
    SELECT
        u.rowid, u."name", u."color", c."bgcolor",
        c."is_admin", c."password"
    FROM "users"              AS u
    INNER JOIN "users_config" AS c ON c."users_id" = u.rowid
    WHERE u."is_active" = 1;
    
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

CREATE VIEW "users_2_users_data" (
        "users_to_id",   "users_to_name",   "users_to_color",
        "users_from_id", "users_from_name", "users_from_color",
        "posts_last_id"
    ) AS
    SELECT 
        ut.rowid, ut."name", ut."color", 
        uf.rowid, uf."name", uf."color", 
        u2u."posts_last_id"
    FROM "users_2_users" AS u2u
    INNER JOIN "users"   AS uf  ON u2u."users_id"      = uf.rowid
    INNER JOIN "users"   AS ut  ON u2u."users_from_id" = uf.rowid;

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

CREATE VIEW "get_users_2_topics" (
        "topics_id", "topics_title", 
        "users_id", "users_name", "users_color",
        "topics_pin", "topics_ignore", "topics_posts_last_id"
    ) AS
    SELECT 
        t.rowid, t."title", 
        u.rowid, u."name", u."color", 
        t."pin", t."ignore", t."posts_last_id"
    FROM "users_2_topics" AS u2t
    INNER JOIN "users"    AS u ON u2t."users_id"  = u.rowid
    INNER JOIN "topics"   AS t ON u2t."topics_id" = t.rowid;

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

CREATE VIEW "get_forum_posts" (
        "posts_id",
        "users_id", "users_name", "users_color", 
        "ref_id", "ref_description", "ref_marker",
        "create_time", "textdata"
    ) AS
    SELECT 
        p.rowid, 
        u.rowid, u."name", u."color", 
        t.rowid, t."title", NULL, 
        p."create_time", COAELSCE(p."cache", p."plain_text")
    FROM "posts"        AS p
    INNER JOIN "users"  AS u ON p."users_from_id" = u.rowid
    INNER JOIN "topics" AS t ON p."topics_id"     = t.rowid
    WHERE p."topics_id"       IS NOT NULL
      AND p."users_to_id"     IS NULL
      AND p."parent_posts_id" IS NULL
    ORDER BY p."create_time" DESC;

CREATE VIEW "get_private_posts" (
        "posts_id",
        "users_id", "users_name", "users_color", 
        "ref_id", "ref_description", "ref_marker",
        "create_time", "textdata"
    ) AS
    SELECT 
        p.rowid, 
        u.rowid, u."name", u."color", 
        t.rowid, t."name", t."color", 
        p."create_time", COAELSCE(p."cache", p."plain_text")
    FROM "posts"        AS p
    INNER JOIN "users"  AS u ON p."users_from_id" = u.rowid
    INNER JOIN "users"  AS t ON p."users_to_id"   = t.rowid
    WHERE p."users_to_id"     IS NOT NULL
      AND p."topics_id"       IS NULL
      AND p."parent_posts_id" IS NULL
    ORDER BY p."create_time" DESC;

CREATE VIEW "get_comment_posts" (
        "posts_id",
        "users_id", "users_name", "users_color", 
        "ref_id", "ref_description", "ref_marker",
        "create_time", "textdata"
    ) AS
    SELECT 
        p.rowid, 
        u.rowid, u."name", u."color", 
        t.rowid, t."name", t."color", 
        p."create_time", COAELSCE(p."cache", p."plain_text")
    FROM "posts"        AS p
    INNER JOIN "users"  AS u ON p."users_from_id"    = u.rowid
    INNER JOIN "posts"  AS t ON p."parents_posts_id" = t.rowid
    WHERE p."parten_posts_id" IS NOT NULL
      AND p."users_to_id"     IS NULL
      AND p."topics_id"       IS NULL
    ORDER BY p."create_time" DESC;

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

CREATE VIEW get_chat_messages (
        "posts_id",
        "users_id", "users_name", "users_color",
        "ref_id", "ref_description", "ref_marker",
        "create_time", "textdata"
    ) AS
    SELECT 
        p.rowid,
        u.rowid, u."name", u."color",
        NULL, NULL, NULL,
        p."create_time", COAELSCE(p."cache", p."plain_text")
    FROM "chat"        AS c
    INNER JOIN "users" AS u ON c."users_from_id" = u.rowid
    INNER JOIN "posts" AS p ON c."posts_id"      = p.rowid
    WHERE p."users_to_id"     IS NULL
      AND p."topics_id"       IS NULL
      AND p."parent_posts_id" IS NULL
    ORDER BY p."create_time" DESC;



