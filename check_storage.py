import os  
repo = r\"c:\Proyectos\velvetsynccatalog\documentacion\docs\"  
img = len([f for r,d,fs in os.walk(repo) for f in fs if f.endswith('.jpg')])  
qr = len([f for r,d,fs in os.walk(repo) for f in fs if f.endswith('.png')])  
pdf = len([f for r,d,fs in os.walk(repo) for f in fs if f.endswith('.pdf')])  
print(\"IMAGENES:\", img)  
print(\"QR CODES:\", qr)  
print(\"PDFS:\", pdf)  
print(\"TOTAL:\", img+qr+pdf)  
print(\"MB ESTIMADOS:\", (img*150+qr*5+pdf*500)/1024)  
