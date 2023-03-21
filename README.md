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

Per utilizzare il programma su uno specifico input generato si possono utilizzare 2 comandi da console (a seconda del OS utilizzato). Dopo la compilazione è sufficiente scrivere:
```
.\main.exe -K=5 -file="v1.txt"       //Windows
.\main -K=5 -file="v1.txt"            //Linux
```
K indica il numero di soluzioni massime da trovare.

file indica il nome del file dei vincoli da utilizzare.


### Controllo delle soluzioni
```
python check.py v5.txt
```

### Controllo della unicità delle soluzioni
```
python compare.py v5.txt
```
