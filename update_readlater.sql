CREATE TABLE "readlater" (
    "userid" int(11) NOT NULL, 
    "postid" int(11) NOT NULL, 
    PRIMARY KEY ("userid", "postid")
);
CREATE INDEX "readlater_userid_ix" ON "readlater"("userid");
CREATE INDEX "readlater_postid_ix" ON "readlater"("postid");
