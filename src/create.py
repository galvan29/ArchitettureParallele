from random import randint
import sys

file = open(sys.argv[1],"a")
file.truncate(0)
letterali = int(float(sys.argv[2]))
vincoli = int(float(sys.argv[3]))
first_row = "p cnf " + str(letterali) + " " + str(vincoli)
file.write(first_row)

# generate random integer values
for i in range(vincoli):
  value = randint(-letterali, letterali)
  value2 = randint(-letterali, letterali)
  while value==0:
    value = randint(-letterali, letterali)
  while value2==0 or value2==value or value2==-value:
    value2 = randint(-letterali, letterali)
  add =  "\n" + str(value) + " " + str(value2) + " " + str(0)
  file.write(add)
file.close()