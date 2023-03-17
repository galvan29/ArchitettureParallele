# ArchitettureParallele

Risoluzione del problema del 2SAT in parallelo tramite utilizzo delle libreria NVIDIA.

Esecuzione
python create.py n m  
n = numero di letterali; m = numero di vincoli 

nvcc -o b main.cu 
./b

python check.py       //controllo se le soluzioni trovate siano corrette
python compare.py     //controllo se le soluzioni trovate sono tutte differenti
