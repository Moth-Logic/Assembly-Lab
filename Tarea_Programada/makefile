NASM = nasm
LD   = ld
TARGET = evaluator

all: $(TARGET)

$(TARGET): main.o
	$(LD) main.o -o $(TARGET)

main.o: main.asm
	$(NASM) -f elf64 main.asm -o main.o

run: $(TARGET)
	./$(TARGET)

test: $(TARGET)
	@echo "2+3" | ./$(TARGET)
	@echo "2x + 6y + 3x - x*z / 8 + 25, x=50, y=5, z=20" | ./$(TARGET)
	@echo "2*(3+4)" | ./$(TARGET)
	@echo "(1+2)*(3+(4*5))" | ./$(TARGET)
	@echo "10/0" | ./$(TARGET)

clean:
	rm -f *.o $(TARGET)

.PHONY: all run test clean