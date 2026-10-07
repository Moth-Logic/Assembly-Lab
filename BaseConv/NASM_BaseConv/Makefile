SRC   = suma_resta_bases.asm
OBJ   = suma_resta_bases.o
BIN   = suma_resta_bases

all: $(BIN)

$(BIN): $(OBJ)
	ld $(OBJ) -o $(BIN)

$(OBJ): $(SRC)
	nasm -f elf64 $(SRC) -o $(OBJ)

clean:
	rm -f $(OBJ) $(BIN)

.PHONY: all clean
