extension = main
run = ./
ifeq ($(OS),Windows_NT)
	extension = main.exe
	run = .\\
else
	extension = main
	run = ./
endif


all: compile run

compile:
	nvcc -rdc=true -lineinfo $(run)main.cu -o $(extension)
	
run: $(run)$(extension) $(run)v1.txt $(run)v2.txt $(run)v3.txt
	#$(run)$(extension) -K=4 -file=v1.txt
	#$(run)$(extension) -K=10 -file=v2.txt
	#$(run)$(extension) -K=100 -file=v3.txt
	#$(run)$(extension) -K=200 -file=v4.txt
	$(run)$(extension) -K=10 -file=v5.txt
	
clean:
	rm .f main *.o