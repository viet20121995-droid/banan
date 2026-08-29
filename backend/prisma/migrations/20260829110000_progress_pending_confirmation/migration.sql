-- Trainee self-marked completion now awaits ADMIN confirmation.
ALTER TYPE "TrainingProgressStatus" ADD VALUE IF NOT EXISTS 'PENDING_CONFIRMATION' BEFORE 'COMPLETED';
