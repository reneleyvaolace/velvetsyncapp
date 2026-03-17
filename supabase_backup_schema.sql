-- Velvet Sync Backup Schema  
CREATE TABLE IF NOT EXISTS device_backups (  
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,  
  backup_code VARCHAR(6) NOT NULL UNIQUE,  
  backup_data JSONB NOT NULL,  
  created_at TIMESTAMPTZ DEFAULT NOW()  
); 
