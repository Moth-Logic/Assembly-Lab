SRC   = divmul.asm
OBJ   = divmul.o
BIN   = divmul

all: $(BIN)

$(BIN): $(OBJ)
	ld $(OBJ) -o $(BIN)

$(OBJ): $(SRC)
	nasm -f elf64 $(SRC) -o $(OBJ)

clean:
	rm -f $(OBJ) $(BIN)

.PHONY: all clean