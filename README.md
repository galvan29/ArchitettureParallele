# ArchitettureParallele

## Risoluzione del problema del 2SAT in parallelo.

### Makefile
Per compilare il programma è necessario utilizzare il comando
```
make
```
Dopo la compilazione, verrà eseguita in automatico l'esecuzione di 5 esempi differenti.

Tramite dei file python è possibile creare nuovi file in formato DIMACS e fare altre operazioni.

### Creazione di file per i vincoli
```
python create.py v5.txt n m
```
n = numero di letterali

m = numero di vincoli

### Controllo delle soluzioni
```
python check.py v5.txt
```

### Controllo della unicità delle soluzioni
```
python compare.py v5.txt
```
