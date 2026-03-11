import requests
import concurrent.futures

def probe_id(id_val):
    url = f"https://image.zlmicro.com/images/product/qrcode/{id_val}.png"
    try:
        r = requests.head(url, timeout=5)
        if r.status_code == 200:
            return id_val
    except:
        pass
    return None

def scan_range(start, end):
    print(f"Buscando en rango {start}-{end}...")
    found = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=50) as executor:
        futures = {executor.submit(probe_id, str(i)): i for i in range(start, end + 1)}
        for future in concurrent.futures.as_completed(futures):
            res = future.result()
            if res:
                print(f"✨ ENCONTRADO: {res}")
                found.append(res)
    return found

if __name__ == "__main__":
    # Escaneando 9000-9500 y 7500-8000 (rangos adyacentes probables)
    scan_range(9005, 9500)
    scan_range(7500, 8000)
