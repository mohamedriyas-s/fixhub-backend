ALTER TABLE "users" ALTER COLUMN "phone" DROP NOT NULL, ADD COLUMN "login_email" TEXT;
CREATE UNIQUE INDEX "users_login_email_key" ON "users"("login_email");
