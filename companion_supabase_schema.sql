-- ═══════════════════════════════════════════════════════════════
-- Velvet Sync · Companion Settings & Conversations Schema
-- Para guardar configuración y conversaciones del Companion AI
-- ═══════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════
-- Tabla: companion_settings
-- Guarda la configuración del Companion (nombre, personalidad, preferencias)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS companion_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL UNIQUE,
    name TEXT DEFAULT 'Velvet',
    gender TEXT DEFAULT 'female',
    personality TEXT DEFAULT 'neutral',
    save_conversations BOOLEAN DEFAULT true,
    sync_with_supabase BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_companion_user_id ON companion_settings(user_id);

-- ═══════════════════════════════════════════════════════════════
-- Tabla: conversations
-- Guarda el historial de conversaciones (solo si el usuario activa)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS conversations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL,
    message_text TEXT NOT NULL,
    is_user BOOLEAN NOT NULL,
    motor1 INT DEFAULT 0,
    motor2 INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para búsqueda rápida
CREATE INDEX IF NOT EXISTS idx_conversations_user_id ON conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_conversations_created_at ON conversations(created_at);
CREATE INDEX IF NOT EXISTS idx_conversations_user_time ON conversations(user_id, created_at DESC);

-- ═══════════════════════════════════════════════════════════════
-- Row Level Security (RLS)
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE companion_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;

-- Política: Cualquiera puede leer/crear su propia configuración
CREATE POLICY "Users can read own settings"
    ON companion_settings
    FOR SELECT
    USING (true);

CREATE POLICY "Users can insert own settings"
    ON companion_settings
    FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Users can update own settings"
    ON companion_settings
    FOR UPDATE
    USING (true);

-- Política: Cualquiera puede leer/crear sus propias conversaciones
CREATE POLICY "Users can read own conversations"
    ON conversations
    FOR SELECT
    USING (true);

CREATE POLICY "Users can insert own conversations"
    ON conversations
    FOR INSERT
    WITH CHECK (true);

-- ═══════════════════════════════════════════════════════════════
-- Trigger para actualizar updated_at automáticamente
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_companion_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_companion_settings_updated_at
    BEFORE UPDATE ON companion_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_companion_updated_at();

-- ═══════════════════════════════════════════════════════════════
-- Función para limpiar conversaciones antiguas (opcional)
-- Ejecutar cada 30 días para borrar conversaciones > 90 días
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION cleanup_old_conversations()
RETURNS void AS $$
BEGIN
    DELETE FROM conversations
    WHERE created_at < NOW() - INTERVAL '90 days';
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════
-- Ejemplo de uso:
-- ═══════════════════════════════════════════════════════════════
-- INSERT INTO companion_settings (user_id, name, personality, save_conversations, sync_with_supabase)
-- VALUES ('user123', 'Velvet', 'neutral', true, false);
--
-- INSERT INTO conversations (user_id, message_text, is_user, motor1, motor2)
-- VALUES ('user123', 'Hola Velvet', true, 0, 0);
-- ═══════════════════════════════════════════════════════════════
