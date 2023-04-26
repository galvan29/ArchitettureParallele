extension = main
run = ./
ifeq ($(OS),Windows_NT)
	extension = main.exe
	extension2 = maino.exe
	run = .\\
else
	extension = main
	extension2 = maino
	run = ./
endif

all: compile run

compile:
	nvcc -rdc=true -lineinfo $(run)main.cu -o $(extension)
	g++ $(run)maino.cpp -o $(extension2)

run: $(run)$(extension) $(run)vincoli/v1.txt $(run)vincoli/v2.txt $(run)vincoli/v3.txt $(run)vincoli/v4.txt $(run)vincoli/v5.txt
	$(run)$(extension) -k=10 -file=v1.txt
	$(run)$(extension) -k=10 -file=v2.txt
	$(run)$(extension) -k=50 -file=v3.txt
	$(run)$(extension) -k=50 -file=v4.txt
	$(run)$(extension) -k=50 -file=v5.txt -b=40 -t=1024
	
clean:
	rm .f main *.o