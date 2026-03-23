-- Velvet Sync · Script SQL para insertar modelos faltantes
-- Ejecutar en: https://supabase.com/dashboard/project/baeclricgedhxdtmirid/sql/new

-- ═══════════════════════════════════════════════════════════════
-- MODELO 8154 - Knight No. 3 (GS001)
-- ═══════════════════════════════════════════════════════════════
INSERT INTO device_catalog (
    id,
    factory_model,
    model_name,
    usage_type,
    target_anatomy,
    stimulation_type,
    motor_logic,
    image_url,
    qr_code_url,
    supported_funcs,
    is_precise_new,
    broadcast_prefix
) VALUES (
    '8154',
    'GS001',
    'Knight No. 3',
    'Universal',
    'Anal',
    'Vibracion',
    'Dual Channel',
    'https://raw.githubusercontent.com/reneleyvaolace/velvetsynccatalog/main/documentacion/docs/img/VS_8154.jpg',
    'https://raw.githubusercontent.com/reneleyvaolace/velvetsynccatalog/main/documentacion/docs/qr/QR_8154.png',
    'classic,music,shake,intera,finger,video,game,explore',
    true,
    '77 62 4d 53 45'
)
ON CONFLICT (id) DO UPDATE SET
    factory_model = EXCLUDED.factory_model,
    model_name = EXCLUDED.model_name,
    usage_type = EXCLUDED.usage_type,
    target_anatomy = EXCLUDED.target_anatomy,
    stimulation_type = EXCLUDED.stimulation_type,
    motor_logic = EXCLUDED.motor_logic,
    image_url = EXCLUDED.image_url,
    qr_code_url = EXCLUDED.qr_code_url,
    supported_funcs = EXCLUDED.supported_funcs,
    is_precise_new = EXCLUDED.is_precise_new,
    broadcast_prefix = EXCLUDED.broadcast_prefix;

-- ═══════════════════════════════════════════════════════════════
-- MODELO 3778 - AAGS118
-- ═══════════════════════════════════════════════════════════════
INSERT INTO device_catalog (
    id,
    factory_model,
    model_name,
    usage_type,
    target_anatomy,
    stimulation_type,
    motor_logic,
    image_url,
    qr_code_url,
    supported_funcs,
    is_precise_new,
    broadcast_prefix
) VALUES (
    '3778',
    'AAGS118',
    'AAGS118',
    'Universal',
    'Universal',
    'Vibracion',
    'Single Channel',
    'https://raw.githubusercontent.com/reneleyvaolace/velvetsynccatalog/main/documentacion/docs/img/VS_3778.jpg',
    'https://raw.githubusercontent.com/reneleyvaolace/velvetsynccatalog/main/documentacion/docs/qr/QR_3778.png',
    'classic,music,shake,intera,finger,video,game,explore',
    true,
    '77 62 4d 53 45'
)
ON CONFLICT (id) DO UPDATE SET
    factory_model = EXCLUDED.factory_model,
    model_name = EXCLUDED.model_name,
    usage_type = EXCLUDED.usage_type,
    target_anatomy = EXCLUDED.target_anatomy,
    stimulation_type = EXCLUDED.stimulation_type,
    motor_logic = EXCLUDED.motor_logic,
    image_url = EXCLUDED.image_url,
    qr_code_url = EXCLUDED.qr_code_url,
    supported_funcs = EXCLUDED.supported_funcs,
    is_precise_new = EXCLUDED.is_precise_new,
    broadcast_prefix = EXCLUDED.broadcast_prefix;

-- ═══════════════════════════════════════════════════════════════
-- MODELO 9303 - FJ001
-- ═══════════════════════════════════════════════════════════════
INSERT INTO device_catalog (
    id,
    factory_model,
    model_name,
    usage_type,
    target_anatomy,
    stimulation_type,
    motor_logic,
    image_url,
    qr_code_url,
    supported_funcs,
    is_precise_new,
    broadcast_prefix
) VALUES (
    '9303',
    'FJ001',
    'FJ001',
    'Universal',
    'Universal',
    'Vibracion',
    'Single Channel',
    'https://raw.githubusercontent.com/reneleyvaolace/velvetsynccatalog/main/documentacion/docs/img/VS_9303.jpg',
    'https://raw.githubusercontent.com/reneleyvaolace/velvetsynccatalog/main/documentacion/docs/qr/QR_9303.png',
    'classic,music,shake,intera,finger,video,game,explore',
    true,
    '77 62 4d 53 45'
)
ON CONFLICT (id) DO UPDATE SET
    factory_model = EXCLUDED.factory_model,
    model_name = EXCLUDED.model_name,
    usage_type = EXCLUDED.usage_type,
    target_anatomy = EXCLUDED.target_anatomy,
    stimulation_type = EXCLUDED.stimulation_type,
    motor_logic = EXCLUDED.motor_logic,
    image_url = EXCLUDED.image_url,
    qr_code_url = EXCLUDED.qr_code_url,
    supported_funcs = EXCLUDED.supported_funcs,
    is_precise_new = EXCLUDED.is_precise_new,
    broadcast_prefix = EXCLUDED.broadcast_prefix;

-- ═══════════════════════════════════════════════════════════════
-- VERIFICACION
-- ═══════════════════════════════════════════════════════════════
SELECT id, factory_model, model_name, usage_type, target_anatomy, stimulation_type, motor_logic, is_precise_new, broadcast_prefix
FROM device_catalog
WHERE id IN ('8154', '3778', '9303')
ORDER BY id;
