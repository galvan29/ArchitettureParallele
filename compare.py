import sys

with open("solution.txt") as file:
    lines = [line.rstrip() for line in file]
errorE = False
for i in lines:
    idx = lines.index(i)
    for j in range(len(lines)):
        if idx != j and  lines[j] == i:
          errorE = True
          break
if errorE == False:
  print("Soluzioni diverse")
else:
  print("Soluzioni duplicate")