SRC = letter_swap.s
OBJ = letter_swap.o
BIN = letter_swap

all: $(BIN)

$(OBJ): $(SRC)
	as -o $(OBJ) $(SRC)

$(BIN): $(OBJ)
	ld -o $(BIN) $(OBJ)

clean:
	rm -f $(OBJ) $(BIN)

.PHONY: all clean
