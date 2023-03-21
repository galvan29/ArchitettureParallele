import sys

def my_function(array):
  check = True
  valore1 = 0
  valore2 = 0
  i = 0
  file = open(sys.argv[1],"r")
  Lines = file.readlines()
  file.close()
  for line in Lines:
    if i > 0 :
      array2 = line.split()
      a = int(array2[0])
      b = int(array2[1])
      l = len(array)/2
      if a < 0:
        valore1 = abs(a) + l -1
      else:
        valore1 = a -1
      if b < 0:
        valore2 = abs(b) + l -1
      else:
        valore2 = b -1
      valore1 = int(valore1)
      valore2 = int(valore2)
      val1 = int(array[valore1])
      val2 = int(array[valore2])
      if (val1 == -1 and val2 == -1):
        check = False
    else :
      i += 1
  if check:
    print("É una soluzione")
  elif check == False:
    print("Non è una soluzione per la verità dei vincoli") 

def split_list(a_list):
    half = len(a_list)//2
    return a_list[:half], a_list[half:]

with open("sol"+sys.argv[1]) as file:
    lines = [line.rstrip() for line in file]

for ad in lines:
  arrayVera = ad.split()
  print(arrayVera)
  my_function(arrayVera)
  B, C = split_list(arrayVera)
  errore = False
  for x, y in zip(B, C):
    if(int(x) == 1 and int(y) == 1) or (int(x) == -1 and int(y) == -1):
      errore = True

  if errore == True:
    print("Non è una soluzione per i vincoli entrambi -1 o 1") 
