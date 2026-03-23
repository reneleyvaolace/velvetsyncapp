-- SQL para verificar estructura de tabla  
SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'device_catalog' ORDER BY ordinal_position;  
  
-- Verificar modelos existentes  SELECT id, factory_model, model_name, usage_type, target_anatomy, stimulation_type, motor_logic, image_url, qr_code_url, is_precise_new, broadcast_prefix FROM device_catalog WHERE id IN ('8154', '3778', '9303') ORDER BY id;  
