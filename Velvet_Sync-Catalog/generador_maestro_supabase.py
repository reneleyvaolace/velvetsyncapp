import json

def construir_comando_vibracion(prefijo, intensidad, amplitud=0):
    # Basado en lo que encontramos en JADX: aa 02 + int + 00 + amp
    # Convertimos a hexadecimal de 2 dígitos
    h_int = format(intensidad, '02x')
    h_amp = format(amplitud, '02x')
    
    if prefijo == "ZBTD": # Dual Motor detectado
        return f"aa02{h_int}00{h_amp}"
    else: # Vibrador simple
        return f"7701{h_int}0000"

def generar_sql_batch(datos_productos):
    sql_statements = []
    for p in datos_productos:
        # Inferencia técnica de CoreAura
        prefijo = p['title'][:4]
        v_cmd = construir_comando_vibracion(prefijo, 10, 5 if prefijo == "ZBTD" else 0)
        
        query = (
            f"INSERT INTO v_sync_catalog (barcode, model_name, vibration_cmd_hex, certified_by_coreaura) "
            f"VALUES ('{p['barcode']}', '{p['title']}', '{v_cmd}', true) "
            f"ON CONFLICT (barcode) DO UPDATE SET vibration_cmd_hex = EXCLUDED.vibration_cmd_hex;"
        )
        sql_statements.append(query)
    return "\n".join(sql_statements)

# Ejemplo con tus datos
test_data = [{'barcode': '2359', 'title': 'ZBTD014'}]
print(generar_sql_batch(test_data))