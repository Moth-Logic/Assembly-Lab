SRC = contar_palabrasx86.s
OBJ = contar_palabrasx86.o
BIN = contar_palabrasx86

all: $(BIN)

$(OBJ): $(SRC)
	as -o $(OBJ) $(SRC)

$(BIN): $(OBJ)
	ld -o $(BIN) $(OBJ)

clean:
	rm -f $(OBJ) $(BIN)

.PHONY: all clean