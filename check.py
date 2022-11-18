import sys

file = open("vincoli.txt","r")
#print(str(bin(int(1.1258999e+15))))
stringaVera = "-1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 1 -1 -1 -1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 -1 1 1 1"
arrayVera = stringaVera.split()

stringaFalsa = "-1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1"
arrayFalsa = stringaFalsa.split()

def my_function(array):
  check = True
  valore1 = 0
  valore2 = 0
  i = 0
  Lines = file.readlines()
  for line in Lines:
    if i > 0 :
      array2 = line.split()
      if int(array2[0]) < 0:
        valore1 = abs(int(array2[0])) + (len(array)/2) -1
      if int(array2[1]) < 0:
        valore2 = abs(int(array2[1])) + (len(array)/2) -1
      if int(array2[0]) > 0:
        valore1 = abs(int(array2[0])) -1
      if int(array2[1]) > 0:
        valore2 = abs(int(array2[1])) -1
      valore1 = int(valore1)
      valore2 = int(valore2)
      valore1 = int(array[valore1])
      valore2 = int(array[valore2])
      if (valore1 == -1 and valore2 == -1):
        check = False
    else :
      i += 1
  if check :
    print("É una soluzione") 
  elif not(check):
    print("Non è una soluzione") 

my_function(arrayVera)
#my_function(arrayFalsa)

file.close()