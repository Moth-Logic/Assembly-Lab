SRC = contar_palabrasAA32.s
OBJ = contar_palabrasAA32.o
BIN = contar_palabrasAA32

all: $(BIN)

$(OBJ): $(SRC)
	as -o $(OBJ) $(SRC)

$(BIN): $(OBJ)
	ld -o $(BIN) $(OBJ)

clean:
	rm -f $(OBJ) $(BIN)

.PHONY: all clean