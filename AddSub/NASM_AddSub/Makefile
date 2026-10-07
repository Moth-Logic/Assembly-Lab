SRC   = sum_sub.asm
OBJ   = sum_sub.o
BIN   = sum_sub

all: $(BIN)

$(BIN): $(OBJ)
	ld $(OBJ) -o $(BIN)

$(OBJ): $(SRC)
	nasm -f elf64 $(SRC) -o $(OBJ)

clean:
	rm -f $(OBJ) $(BIN)

.PHONY: all clean
