ALTER TABLE "users" ADD COLUMN "hideemail" tinyint(1) NOT NULL DEFAULT 1;
ALTER TABLE "users" ADD COLUMN "phone" varchar(50);
ALTER TABLE "users" ADD COLUMN "birthdate" varchar(10);
ALTER TABLE "users" ADD COLUMN "infos" varchar(1024);
