-- AlterTable
ALTER TABLE "bookings" ADD COLUMN "start_otp" VARCHAR(6),
ADD COLUMN "start_otp_attempts" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN "work_started_at" TIMESTAMP(3);

