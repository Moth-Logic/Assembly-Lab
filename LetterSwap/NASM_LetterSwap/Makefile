SRC = letter_swap.asm
OBJ = letter_swap.o
BIN = letter_swap

all: $(BIN)

$(OBJ): $(SRC)
	nasm -f elf64 $(SRC) -o $(OBJ)

$(BIN): $(OBJ)
	ld $(OBJ) -o $(BIN)

clean:
	rm -f $(OBJ) $(BIN)
